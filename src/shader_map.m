#import "shader_map.h"
#import "gl_state.h"
#import <Foundation/Foundation.h>

#define UNIFORM_LOC_TCSCALE     1
#define UNIFORM_LOC_COLORTONE   2
#define UNIFORM_LOC_SPRITEBLUR  3
#define UNIFORM_LOC_ZOOM        4
#define UNIFORM_LOC_TEX         5
#define UNIFORM_LOC_BRIGHTNESS  6
#define UNIFORM_LOC_GAMMA       7
#define UNIFORM_LOC_TEX2        8
#define UNIFORM_LOC_ST          10

@interface PSTProgramInfo : NSObject
@property (nonatomic, assign) GLuint programId;
@property (nonatomic, assign) PSTShaderType shaderType;
@property (nonatomic, assign) simd_float4 uST;
@property (nonatomic, assign) simd_float2 uTcScale;
@property (nonatomic, assign) simd_float4 uColorTone;
@property (nonatomic, assign) float uSpriteBlur;
@property (nonatomic, assign) float uZoomStrength;
@property (nonatomic, assign) float uBrightness;
@property (nonatomic, assign) float uGamma;
@property (nonatomic, assign) GLuint attachedVertexShader;
@property (nonatomic, assign) GLuint attachedFragmentShader;
@end

@implementation PSTProgramInfo
- (instancetype)init {
    self = [super init];
    if (self) {
        _uST = simd_make_float4(2.0f / 1920.0f, -2.0f / 1080.0f, -1.0f, 1.0f);
        _uTcScale = simd_make_float2(1.0f, 1.0f);
        _uColorTone = simd_make_float4(1.0f, 1.0f, 1.0f, 1.0f);
        _uSpriteBlur = 0.0f;
        _uZoomStrength = 1.0f;
        _uBrightness = 0.0f;
        _uGamma = 1.0f;
    }
    return self;
}
@end

@interface PSTShaderSourceInfo : NSObject
@property (nonatomic, assign) GLuint shaderId;
@property (nonatomic, assign) GLenum shaderType;
@property (nonatomic, copy) NSString *source;
@property (nonatomic, assign) PSTShaderType identifiedType;
@end

@implementation PSTShaderSourceInfo
@end

static id<MTLDevice> s_device = nil;
static id<MTLLibrary> s_library = nil;
static NSMutableDictionary<NSNumber *, PSTProgramInfo *> *s_programMap = nil;
static NSMutableDictionary<NSNumber *, PSTShaderSourceInfo *> *s_shaderMap = nil;
static GLuint s_nextShaderId = 2000;
static GLuint s_nextProgramId = 3000;
static GLuint s_activeProgramId = 0;

#define BLEND_OPAQUE        0
#define BLEND_ALPHA         1
#define BLEND_ADDITIVE      2
#define BLEND_PREMULTIPLIED 3
#define BLEND_MODE_COUNT    4

static id<MTLRenderPipelineState> s_pipelineCache[PST_SHADER_COUNT][BLEND_MODE_COUNT];

static MTLVertexDescriptor* create_vertex_descriptor(void) {
    MTLVertexDescriptor *desc = [[MTLVertexDescriptor alloc] init];
    desc.attributes[0].format = MTLVertexFormatFloat2;
    desc.attributes[0].offset = 0;
    desc.attributes[0].bufferIndex = 0;

    desc.attributes[1].format = MTLVertexFormatFloat2;
    desc.attributes[1].offset = sizeof(float) * 2;
    desc.attributes[1].bufferIndex = 0;

    desc.attributes[2].format = MTLVertexFormatFloat4;
    desc.attributes[2].offset = sizeof(float) * 4;
    desc.attributes[2].bufferIndex = 0;

    desc.layouts[0].stride = sizeof(PSTVertex2D);
    desc.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    return desc;
}

static void build_pipeline_states(void) {
    if (!s_library || !s_device) return;

    NSString *fragmentFuncNames[PST_SHADER_COUNT] = {
        @"fragment_draw",       // 0: fpDraw
        @"fragment_tone",       // 1: fpTone
        @"fragment_catrom",     // 2: fpCatRom
        @"fragment_yuv",        // 3: fpYUV
        @"fragment_yuv_gray",   // 4: fpYUVGRY
        @"fragment_sprite",     // 5: fpSprite
        @"fragment_font",       // 6: fpFONT
        @"fragment_select",     // 7: fpSELECT
        @"fragment_seam"        // 8: fpSEAM
    };

    id<MTLFunction> vertFunc = [s_library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> vertYuvFunc = [s_library newFunctionWithName:@"vertex_yuv"];
    MTLVertexDescriptor *vDesc = create_vertex_descriptor();

    for (int s = 0; s < PST_SHADER_COUNT; s++) {
        id<MTLFunction> fragFunc = [s_library newFunctionWithName:fragmentFuncNames[s]];
        if (!fragFunc) {
            NSLog(@"[PSTMetal] WARNING: Missing MSL fragment function: %@", fragmentFuncNames[s]);
            continue;
        }

        for (int b = 0; b < BLEND_MODE_COUNT; b++) {
            MTLRenderPipelineDescriptor *pDesc = [[MTLRenderPipelineDescriptor alloc] init];
            pDesc.vertexFunction = (s == PST_SHADER_YUV || s == PST_SHADER_YUV_GRAY) ? vertYuvFunc : vertFunc;
            pDesc.fragmentFunction = fragFunc;
            pDesc.vertexDescriptor = vDesc;
            pDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

            switch (b) {
                case BLEND_OPAQUE:
                    pDesc.colorAttachments[0].blendingEnabled = NO;
                    break;
                case BLEND_ALPHA:
                    pDesc.colorAttachments[0].blendingEnabled = YES;
                    pDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
                    pDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
                    pDesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
                    pDesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
                    break;
                case BLEND_ADDITIVE:
                    pDesc.colorAttachments[0].blendingEnabled = YES;
                    pDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
                    pDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOne;
                    pDesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
                    pDesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOne;
                    break;
                case BLEND_PREMULTIPLIED:
                    pDesc.colorAttachments[0].blendingEnabled = YES;
                    pDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
                    pDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
                    pDesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
                    pDesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
                    break;
            }

            NSError *err = nil;
            s_pipelineCache[s][b] = [s_device newRenderPipelineStateWithDescriptor:pDesc error:&err];
            if (err) {
                NSLog(@"[PSTMetal] Error creating pipeline state (%d, %d): %@", s, b, err);
            }
        }
    }
    NSLog(@"[PSTMetal] Precompiled %d Metal render pipeline states.", PST_SHADER_COUNT * BLEND_MODE_COUNT);
}

void shader_map_init(id<MTLDevice> device, id<MTLLibrary> library) {
    s_device = device;
    s_library = library;
    s_programMap = [[NSMutableDictionary alloc] init];
    s_shaderMap = [[NSMutableDictionary alloc] init];
    build_pipeline_states();
}

GLuint shader_map_create_shader(GLenum type) {
    GLuint sId = s_nextShaderId++;
    PSTShaderSourceInfo *info = [[PSTShaderSourceInfo alloc] init];
    info.shaderId = sId;
    info.shaderType = type;
    info.identifiedType = PST_SHADER_DRAW;
    s_shaderMap[@(sId)] = info;
    return sId;
}

void shader_map_shader_source(GLuint shader, GLsizei count, const GLchar *const*string, const GLint *length) {
    (void)length;
    PSTShaderSourceInfo *info = s_shaderMap[@(shader)];
    if (!info) return;

    NSMutableString *fullSource = [NSMutableString string];
    for (GLsizei i = 0; i < count; i++) {
        if (string[i]) {
            [fullSource appendString:[NSString stringWithUTF8String:string[i]]];
        }
    }
    info.source = fullSource;

    if ([fullSource containsString:@"fpTone"] || [fullSource containsString:@"uColorTone.a"]) {
        info.identifiedType = PST_SHADER_TONE;
    } else if ([fullSource containsString:@"fpCatRom"]) {
        info.identifiedType = PST_SHADER_CATROM;
    } else if ([fullSource containsString:@"fpYUVGRY"]) {
        info.identifiedType = PST_SHADER_YUV_GRAY;
    } else if ([fullSource containsString:@"fpYUV"]) {
        info.identifiedType = PST_SHADER_YUV;
    } else if ([fullSource containsString:@"fpSprite"] || [fullSource containsString:@"uSpriteBlurAmount"]) {
        info.identifiedType = PST_SHADER_SPRITE;
    } else if ([fullSource containsString:@"fpFONT"]) {
        info.identifiedType = PST_SHADER_FONT;
    } else if ([fullSource containsString:@"fpSELECT"]) {
        info.identifiedType = PST_SHADER_SELECT;
    } else if ([fullSource containsString:@"fpSEAM"]) {
        info.identifiedType = PST_SHADER_SEAM;
    } else {
        info.identifiedType = PST_SHADER_DRAW;
    }
}

void shader_map_compile_shader(GLuint shader) {
    (void)shader;
}

GLuint shader_map_create_program(void) {
    GLuint pId = s_nextProgramId++;
    PSTProgramInfo *info = [[PSTProgramInfo alloc] init];
    info.programId = pId;
    info.shaderType = PST_SHADER_DRAW;
    s_programMap[@(pId)] = info;
    return pId;
}

void shader_map_attach_shader(GLuint program, GLuint shader) {
    PSTProgramInfo *pInfo = s_programMap[@(program)];
    PSTShaderSourceInfo *sInfo = s_shaderMap[@(shader)];
    if (!pInfo || !sInfo) return;

    if (sInfo.shaderType == 0x8B31 /* GL_VERTEX_SHADER */) {
        pInfo.attachedVertexShader = shader;
    } else {
        pInfo.attachedFragmentShader = shader;
        pInfo.shaderType = sInfo.identifiedType;
    }
}

void shader_map_link_program(GLuint program) {
    PSTProgramInfo *pInfo = s_programMap[@(program)];
    if (!pInfo) return;
    PSTShaderSourceInfo *fInfo = s_shaderMap[@(pInfo.attachedFragmentShader)];
    if (fInfo) {
        pInfo.shaderType = fInfo.identifiedType;
    }
}

void shader_map_use_program(GLuint program) {
    s_activeProgramId = program;
    g_glState.shader.currentProgram = program;
}

void shader_map_delete_shader(GLuint shader) {
    [s_shaderMap removeObjectForKey:@(shader)];
}

void shader_map_delete_program(GLuint program) {
    [s_programMap removeObjectForKey:@(program)];
    if (s_activeProgramId == program) {
        s_activeProgramId = 0;
        g_glState.shader.currentProgram = 0;
    }
}

GLint shader_map_get_uniform_location(GLuint program, const GLchar *name) {
    (void)program;
    if (!name) return -1;
    if (strcmp(name, "uST") == 0) return UNIFORM_LOC_ST;
    if (strcmp(name, "uTcScale") == 0) return UNIFORM_LOC_TCSCALE;
    if (strcmp(name, "uColorTone") == 0) return UNIFORM_LOC_COLORTONE;
    if (strcmp(name, "uSpriteBlurAmount") == 0) return UNIFORM_LOC_SPRITEBLUR;
    if (strcmp(name, "uZoomStrength") == 0) return UNIFORM_LOC_ZOOM;
    if (strcmp(name, "uBrightness") == 0) return UNIFORM_LOC_BRIGHTNESS;
    if (strcmp(name, "uGamma") == 0) return UNIFORM_LOC_GAMMA;
    if (strcmp(name, "uTex") == 0 || strcmp(name, "tex0") == 0) return UNIFORM_LOC_TEX;
    if (strcmp(name, "uTex2") == 0 || strcmp(name, "tex1") == 0) return UNIFORM_LOC_TEX2;
    return 100;
}

void shader_map_uniform_1i(GLint location, GLint v0) {
    (void)location; (void)v0;
}

void shader_map_uniform_1f(GLint location, GLfloat v0) {
    PSTProgramInfo *info = s_programMap[@(s_activeProgramId)];
    if (!info) return;
    if (location == UNIFORM_LOC_SPRITEBLUR) info.uSpriteBlur = v0;
    else if (location == UNIFORM_LOC_ZOOM) info.uZoomStrength = v0;
    else if (location == UNIFORM_LOC_BRIGHTNESS) info.uBrightness = v0;
    else if (location == UNIFORM_LOC_GAMMA) info.uGamma = v0;
}

void shader_map_uniform_2f(GLint location, GLfloat v0, GLfloat v1) {
    GLfloat val[2] = {v0, v1};
    shader_map_uniform_2fv(location, 1, val);
}

void shader_map_uniform_4f(GLint location, GLfloat v0, GLfloat v1, GLfloat v2, GLfloat v3) {
    GLfloat val[4] = {v0, v1, v2, v3};
    shader_map_uniform_4fv(location, 1, val);
}

void shader_map_uniform_2fv(GLint location, GLsizei count, const GLfloat *value) {
    (void)count;
    if (!value) return;
    PSTProgramInfo *info = s_programMap[@(s_activeProgramId)];
    if (!info) return;
    if (location == UNIFORM_LOC_TCSCALE) {
        info.uTcScale = simd_make_float2(value[0], value[1]);
    }
}

void shader_map_uniform_4fv(GLint location, GLsizei count, const GLfloat *value) {
    (void)count;
    if (!value) return;
    PSTProgramInfo *info = s_programMap[@(s_activeProgramId)];
    if (!info) return;
    if (location == UNIFORM_LOC_ST) {
        info.uST = simd_make_float4(value[0], value[1], value[2], value[3]);
    } else if (location == UNIFORM_LOC_COLORTONE) {
        info.uColorTone = simd_make_float4(value[0], value[1], value[2], value[3]);
    }
}

PSTShaderType shader_map_get_active_shader(void) {
    PSTProgramInfo *info = s_programMap[@(s_activeProgramId)];
    return info ? info.shaderType : PST_SHADER_DRAW;
}

id<MTLRenderPipelineState> shader_map_get_pipeline(PSTShaderType shaderType, uint32_t blendMode) {
    if (shaderType >= PST_SHADER_COUNT) shaderType = PST_SHADER_DRAW;
    if (blendMode >= BLEND_MODE_COUNT) blendMode = BLEND_ALPHA;
    return s_pipelineCache[shaderType][blendMode];
}

PSTMetalUniforms shader_map_get_current_uniforms(void) {
    PSTMetalUniforms u;
    PSTProgramInfo *info = s_programMap[@(s_activeProgramId)];
    if (info) {
        u.uST = info.uST;
        u.uTcScale = info.uTcScale;
        u.uColorTone = info.uColorTone;
        u.uSpriteBlurAmount = info.uSpriteBlur;
        u.uZoomStrength = info.uZoomStrength;
        u.uBrightness = info.uBrightness;
        u.uGamma = info.uGamma;
    } else {
        u.uST = simd_make_float4(2.0f / 1920.0f, -2.0f / 1080.0f, -1.0f, 1.0f);
        u.uTcScale = simd_make_float2(1.0f, 1.0f);
        u.uColorTone = simd_make_float4(1.0f, 1.0f, 1.0f, 1.0f);
        u.uSpriteBlurAmount = 0.0f;
        u.uZoomStrength = 1.0f;
        u.uBrightness = 0.0f;
        u.uGamma = 1.0f;
    }
    return u;
}
