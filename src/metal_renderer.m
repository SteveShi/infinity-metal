#import "metal_renderer.h"
#import "metal_textures.h"
#import "shader_map.h"
#import "gl_state.h"
#import <QuartzCore/CAMetalLayer.h>
#import <simd/simd.h>
#import <stdatomic.h>

#define IN_FLIGHT_FRAMES 3
#define MAX_VERTICES_PER_FRAME (64 * 1024)

#import "shaders_metal.h"

static id<MTLDevice> s_device = nil;
static id<MTLCommandQueue> s_commandQueue = nil;
static id<MTLLibrary> s_library = nil;
static CAMetalLayer *s_metalLayer = nil;

static id<MTLBuffer> s_vertexBuffers[IN_FLIGHT_FRAMES];
static id<MTLBuffer> s_uniformBuffers[IN_FLIGHT_FRAMES];
static dispatch_semaphore_t s_frameSemaphore;
static NSUInteger s_frameIndex = 0;
static NSUInteger s_currentVertexOffset = 0;

static id<MTLCommandBuffer> s_currentCommandBuffer = nil;
static id<MTLRenderCommandEncoder> s_currentEncoder = nil;
static id<CAMetalDrawable> s_currentDrawable = nil;
static MTLRenderPassDescriptor *s_renderPassDesc = nil;

static MTLClearColor s_clearColor = {0.0, 0.0, 0.0, 1.0};
static BOOL s_hasClearedThisFrame = NO;

bool metal_renderer_init(void) {
    s_device = MTLCreateSystemDefaultDevice();
    if (!s_device) {
        NSLog(@"[PSTMetal] ERROR: Metal is not supported on this device.");
        return false;
    }

    s_commandQueue = [s_device newCommandQueue];
    s_frameSemaphore = dispatch_semaphore_create(IN_FLIGHT_FRAMES);

    // 1. Load precompiled metallib from embedded binary data
    NSError *error = nil;
    if (shaders_metallib_len > 0) {
        dispatch_data_t data = dispatch_data_create(shaders_metallib, shaders_metallib_len, dispatch_get_main_queue(), DISPATCH_DATA_DESTRUCTOR_DEFAULT);
        s_library = [s_device newLibraryWithData:data error:&error];
    }

    if (!s_library) {
        // Fallback: compile MSL source at runtime if available
        NSString *shaderSourcePath = @"/Users/steve/Documents/GitHub/pstee-metal/src/metal_shaders.metal";
        NSString *shaderSource = [NSString stringWithContentsOfFile:shaderSourcePath encoding:NSUTF8StringEncoding error:nil];
        if (shaderSource) {
            MTLCompileOptions *options = [[MTLCompileOptions alloc] init];
            s_library = [s_device newLibraryWithSource:shaderSource options:options error:&error];
        }
    }

    if (!s_library) {
        NSLog(@"[PSTMetal] ERROR: Failed to load Metal shaders: %@", error);
        return false;
    }

    // 2. Initialize sub-modules
    metal_textures_init(s_device);
    shader_map_init(s_device, s_library);

    // 3. Create triple buffers for dynamic geometry and uniforms
    NSUInteger vertexBufferSize = MAX_VERTICES_PER_FRAME * sizeof(PSTVertex2D);
    NSUInteger uniformBufferSize = sizeof(PSTMetalUniforms) * 256;

    for (int i = 0; i < IN_FLIGHT_FRAMES; i++) {
        s_vertexBuffers[i] = [s_device newBufferWithLength:vertexBufferSize options:MTLResourceStorageModeShared];
        s_uniformBuffers[i] = [s_device newBufferWithLength:uniformBufferSize options:MTLResourceStorageModeShared];
    }

    s_renderPassDesc = [MTLRenderPassDescriptor renderPassDescriptor];
    s_renderPassDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
    s_renderPassDesc.colorAttachments[0].storeAction = MTLStoreActionStore;
    s_renderPassDesc.colorAttachments[0].clearColor = s_clearColor;

    NSLog(@"[PSTMetal] Core Metal renderer initialized successfully on %@", s_device.name);
    return true;
}

void metal_renderer_attach_to_view(NSView *view) {
    if (!view || !s_device) return;

    void (^block)(void) = ^{
        view.wantsLayer = YES;
        if (!s_metalLayer) {
            s_metalLayer = [CAMetalLayer layer];
            s_metalLayer.device = s_device;
            s_metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
            s_metalLayer.framebufferOnly = YES;
            s_metalLayer.contentsScale = view.window ? view.window.backingScaleFactor : [NSScreen mainScreen].backingScaleFactor;
            s_metalLayer.displaySyncEnabled = YES;
            s_metalLayer.allowsNextDrawableTimeout = YES;
            s_metalLayer.maximumDrawableCount = 3;
            s_metalLayer.presentsWithTransaction = NO;
            s_metalLayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
            s_metalLayer.zPosition = 1000.0f;
            s_metalLayer.actions = @{
                @"bounds": [NSNull null],
                @"position": [NSNull null],
                @"contents": [NSNull null],
                @"sublayers": [NSNull null]
            };
        }
        
        s_metalLayer.frame = view.bounds;
        CGFloat scale = s_metalLayer.contentsScale;
        CGSize boundsSize = view.bounds.size;
        s_metalLayer.drawableSize = CGSizeMake(boundsSize.width * scale, boundsSize.height * scale);
        
        if (s_metalLayer.superlayer != view.layer) {
            [view.layer addSublayer:s_metalLayer];
        }

        NSLog(@"[PSTMetal] CAMetalLayer attached to view (bounds: %.0fx%.0f, drawableSize: %.0fx%.0f, scale: %.1f)",
              boundsSize.width, boundsSize.height,
              s_metalLayer.drawableSize.width, s_metalLayer.drawableSize.height, scale);
    };

    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

id<MTLDevice> metal_renderer_get_device(void) {
    return s_device;
}

static uint32_t get_blend_mode_index(void) {
    if (!g_glState.blend.enabled) return 0; // Opaque
    if (g_glState.blend.srcFactor == 0x0302 /* GL_SRC_ALPHA */ &&
        g_glState.blend.dstFactor == 0x0303 /* GL_ONE_MINUS_SRC_ALPHA */) return 1; // Alpha Blend
    if (g_glState.blend.srcFactor == 0x0302 /* GL_SRC_ALPHA */ &&
        g_glState.blend.dstFactor == 1 /* GL_ONE */) return 2; // Additive
    if (g_glState.blend.srcFactor == 0 /* GL_ZERO */ &&
        g_glState.blend.dstFactor == 0x0300 /* GL_SRC_COLOR */) return 3; // Multiply
    return 1; // Default to alpha blend
}

static NSUInteger s_passCountThisFrame = 0;

static BOOL ensure_render_pass(void) {
    if (s_currentEncoder) return YES;
    if (!s_metalLayer) return NO;

    if (!s_currentCommandBuffer) {
        s_currentCommandBuffer = [s_commandQueue commandBuffer];
    }

    if (!s_currentDrawable) {
        s_currentDrawable = [s_metalLayer nextDrawable];
        if (!s_currentDrawable) return NO;
    }

    s_renderPassDesc.colorAttachments[0].texture = s_currentDrawable.texture;
    s_renderPassDesc.colorAttachments[0].loadAction = s_hasClearedThisFrame ? MTLLoadActionClear : MTLLoadActionLoad;
    s_renderPassDesc.colorAttachments[0].clearColor = s_clearColor;

    s_currentEncoder = [s_currentCommandBuffer renderCommandEncoderWithDescriptor:s_renderPassDesc];
    s_passCountThisFrame++;

    if (s_currentDrawable) {
        MTLViewport vp = { 0.0, 0.0, (double)s_currentDrawable.texture.width, (double)s_currentDrawable.texture.height, 0.0, 1.0 };
        [s_currentEncoder setViewport:vp];
    }
    return (s_currentEncoder != nil);
}

void metal_renderer_clear(GLbitfield mask) {
    (void)mask;
    s_clearColor = MTLClearColorMake(g_glState.clearColor[0],
                                      g_glState.clearColor[1],
                                      g_glState.clearColor[2],
                                      g_glState.clearColor[3]);
    s_hasClearedThisFrame = YES;
    
    if (s_currentEncoder) {
        [s_currentEncoder endEncoding];
        s_currentEncoder = nil;
    }
}

void metal_renderer_viewport(GLint x, GLint y, GLsizei width, GLsizei height) {
    g_glState.viewport.x = x;
    g_glState.viewport.y = y;
    g_glState.viewport.width = width;
    g_glState.viewport.height = height;

    if (s_metalLayer && width > 0 && height > 0) {
        if (s_metalLayer.drawableSize.width != (CGFloat)width || s_metalLayer.drawableSize.height != (CGFloat)height) {
            s_metalLayer.drawableSize = CGSizeMake(width, height);
        }
    }

    if (s_currentEncoder && width > 0 && height > 0) {
        CGFloat scale = s_metalLayer ? s_metalLayer.contentsScale : 1.0;
        MTLViewport vp = { (double)x * scale, (double)y * scale, (double)width * scale, (double)height * scale, 0.0, 1.0 };
        [s_currentEncoder setViewport:vp];
    }
}

void metal_renderer_scissor(GLint x, GLint y, GLsizei width, GLsizei height) {
    g_glState.scissor.x = x;
    g_glState.scissor.y = y;
    g_glState.scissor.width = width;
    g_glState.scissor.height = height;

    if (s_currentEncoder && g_glState.scissor.enabled && width > 0 && height > 0) {
        MTLScissorRect sc = { (NSUInteger)MAX(0, x), (NSUInteger)MAX(0, y), (NSUInteger)width, (NSUInteger)height };
        [s_currentEncoder setScissorRect:sc];
    }
}

void metal_renderer_draw_arrays(GLenum mode, GLint first, GLsizei count) {
    if (count <= 0 || !ensure_render_pass()) return;

    // Check vertex capacity
    if (s_currentVertexOffset + count > MAX_VERTICES_PER_FRAME) {
        s_currentVertexOffset = 0;
    }

    PSTVertex2D *dstVertices = (PSTVertex2D *)s_vertexBuffers[s_frameIndex].contents + s_currentVertexOffset;

    // 1. Pack vertex data from client pointers
    const uint8_t *vPtr = (const uint8_t *)g_glState.vertexPointer;
    const uint8_t *tPtr = (const uint8_t *)g_glState.texCoordPointer;
    const uint8_t *cPtr = (const uint8_t *)g_glState.colorPointer;

    size_t vStride = g_glState.vertexStride ? g_glState.vertexStride : (sizeof(float) * (g_glState.vertexSize ? g_glState.vertexSize : 2));
    size_t tStride = g_glState.texCoordStride ? g_glState.texCoordStride : (sizeof(float) * 2);
    size_t cStride = g_glState.colorStride ? g_glState.colorStride : 4;

    for (GLsizei i = 0; i < count; i++) {
        GLint idx = first + i;
        // Position
        if (vPtr) {
            if (g_glState.vertexType == 0x1402 /* GL_SHORT */) {
                const int16_t *pos = (const int16_t *)(vPtr + idx * vStride);
                dstVertices[i].position[0] = (float)pos[0];
                dstVertices[i].position[1] = (float)pos[1];
            } else {
                const float *pos = (const float *)(vPtr + idx * vStride);
                dstVertices[i].position[0] = pos[0];
                dstVertices[i].position[1] = pos[1];
            }
        } else {
            dstVertices[i].position[0] = 0.0f;
            dstVertices[i].position[1] = 0.0f;
        }

        // TexCoord
        if (tPtr) {
            if (g_glState.texCoordType == 0x1402 /* GL_SHORT */) {
                const int16_t *tc = (const int16_t *)(tPtr + idx * tStride);
                dstVertices[i].texCoord[0] = g_glState.texCoordNormalized ? (tc[0] / 32767.0f) : (float)tc[0];
                dstVertices[i].texCoord[1] = g_glState.texCoordNormalized ? (tc[1] / 32767.0f) : (float)tc[1];
            } else if (g_glState.texCoordType == 0x1403 /* GL_UNSIGNED_SHORT */) {
                const uint16_t *tc = (const uint16_t *)(tPtr + idx * tStride);
                dstVertices[i].texCoord[0] = g_glState.texCoordNormalized ? (tc[0] / 65535.0f) : (float)tc[0];
                dstVertices[i].texCoord[1] = g_glState.texCoordNormalized ? (tc[1] / 65535.0f) : (float)tc[1];
            } else {
                const float *tc = (const float *)(tPtr + idx * tStride);
                dstVertices[i].texCoord[0] = tc[0];
                dstVertices[i].texCoord[1] = tc[1];
            }
        } else {
            dstVertices[i].texCoord[0] = 0.0f;
            dstVertices[i].texCoord[1] = 0.0f;
        }

        // Color
        if (cPtr) {
            if (g_glState.colorType == 0x1401 /* GL_UNSIGNED_BYTE */) {
                const uint8_t *c = (const uint8_t *)(cPtr + idx * cStride);
                dstVertices[i].color[0] = c[0] / 255.0f;
                dstVertices[i].color[1] = c[1] / 255.0f;
                dstVertices[i].color[2] = c[2] / 255.0f;
                dstVertices[i].color[3] = c[3] / 255.0f;
            } else {
                const float *c = (const float *)(cPtr + idx * cStride);
                dstVertices[i].color[0] = c[0];
                dstVertices[i].color[1] = c[1];
                dstVertices[i].color[2] = c[2];
                dstVertices[i].color[3] = c[3];
            }
        } else {
            dstVertices[i].color[0] = 1.0f;
            dstVertices[i].color[1] = 1.0f;
            dstVertices[i].color[2] = 1.0f;
            dstVertices[i].color[3] = 1.0f;
        }
    }

    // 2. Select pipeline state
    PSTShaderType shaderType = shader_map_get_active_shader();
    uint32_t blendIdx = get_blend_mode_index();
    id<MTLRenderPipelineState> pipeline = shader_map_get_pipeline(shaderType, blendIdx);
    if (!pipeline) return;

    [s_currentEncoder setRenderPipelineState:pipeline];

    // 3. Set vertex buffer
    NSUInteger vertexByteOffset = s_currentVertexOffset * sizeof(PSTVertex2D);
    [s_currentEncoder setVertexBuffer:s_vertexBuffers[s_frameIndex] offset:vertexByteOffset atIndex:0];

    // 4. Set uniforms
    PSTMetalUniforms uniforms = shader_map_get_current_uniforms();
    [s_currentEncoder setVertexBytes:&uniforms length:sizeof(uniforms) atIndex:1];
    [s_currentEncoder setFragmentBytes:&uniforms length:sizeof(uniforms) atIndex:1];

    // 5. Set texture & sampler
    id<MTLTexture> mainTex = metal_tex_get_current(0);
    id<MTLSamplerState> sampler = metal_tex_get_sampler_for_current(0);
    [s_currentEncoder setFragmentTexture:mainTex atIndex:0];
    [s_currentEncoder setFragmentSamplerState:sampler atIndex:0];

    if (shaderType == PST_SHADER_YUV) {
        id<MTLTexture> texU = metal_tex_get_current(1);
        id<MTLTexture> texV = metal_tex_get_current(2);
        [s_currentEncoder setFragmentTexture:texU atIndex:1];
        [s_currentEncoder setFragmentTexture:texV atIndex:2];
    }

    // 6. Set viewport & scissor
    if (g_glState.viewport.width > 0 && g_glState.viewport.height > 0) {
        MTLViewport vp = { (double)g_glState.viewport.x, (double)g_glState.viewport.y,
                           (double)g_glState.viewport.width, (double)g_glState.viewport.height, 0.0, 1.0 };
        [s_currentEncoder setViewport:vp];
    }

    // Diagnostic logging on frame 150
    extern _Atomic uint64_t g_frameCount;
    uint64_t currFrame = atomic_load_explicit(&g_frameCount, memory_order_relaxed);
    if (currFrame == 150) {
        GLuint boundTex = g_glState.textureUnits[0].boundTexture2D;
        NSLog(@"[PSTMetal-F150] Draw #%lu: count=%d, mode=0x%x, shader=%d, tex=%u (%lux%lu), blend=%d(0x%x,0x%x), uST=(%.5f,%.5f,%.2f,%.2f), v0=(%.1f,%.1f), tc0=(%.3f,%.3f), col=(%.2f,%.2f,%.2f,%.2f), tone=(%.2f,%.2f,%.2f,%.2f)",
              (unsigned long)s_currentVertexOffset, count, mode, shaderType, boundTex,
              (unsigned long)mainTex.width, (unsigned long)mainTex.height,
              g_glState.blend.enabled, g_glState.blend.srcFactor, g_glState.blend.dstFactor,
              uniforms.uST.x, uniforms.uST.y, uniforms.uST.z, uniforms.uST.w,
              dstVertices[0].position[0], dstVertices[0].position[1],
              dstVertices[0].texCoord[0], dstVertices[0].texCoord[1],
              dstVertices[0].color[0], dstVertices[0].color[1], dstVertices[0].color[2], dstVertices[0].color[3],
              uniforms.uColorTone.x, uniforms.uColorTone.y, uniforms.uColorTone.z, uniforms.uColorTone.w);
    }

    // 7. Primitive type & draw
    MTLPrimitiveType primType = MTLPrimitiveTypeTriangle;
    if (mode == 0x0005 /* GL_TRIANGLE_STRIP */) primType = MTLPrimitiveTypeTriangleStrip;

    [s_currentEncoder drawPrimitives:primType vertexStart:0 vertexCount:count];

    s_currentVertexOffset += count;
}

void metal_renderer_frame_flush(void) {
    if (s_currentEncoder) {
        [s_currentEncoder endEncoding];
        s_currentEncoder = nil;
    }

    if (s_currentDrawable && s_currentCommandBuffer) {
        [s_currentCommandBuffer presentDrawable:s_currentDrawable];
        [s_currentCommandBuffer commit];
    }

    s_currentCommandBuffer = nil;
    s_currentDrawable = nil;
    s_hasClearedThisFrame = NO;
    s_passCountThisFrame = 0;
    s_currentVertexOffset = 0;
    s_frameIndex = (s_frameIndex + 1) % IN_FLIGHT_FRAMES;
}
