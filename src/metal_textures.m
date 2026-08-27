#import "metal_textures.h"
#import "gl_state.h"
#import <Foundation/Foundation.h>

#define GL_COMPRESSED_RGB_S3TC_DXT1_EXT  0x83F0
#define GL_COMPRESSED_RGBA_S3TC_DXT1_EXT 0x83F1
#define GL_COMPRESSED_RGBA_S3TC_DXT3_EXT 0x83F2
#define GL_COMPRESSED_RGBA_S3TC_DXT5_EXT 0x83F3

#define GL_CLAMP_TO_EDGE 0x812F
#define GL_REPEAT        0x2901
#define GL_NEAREST       0x2600
#define GL_LINEAR        0x2601

@interface PSTTextureInfo : NSObject
@property (nonatomic, strong) id<MTLTexture> texture;
@property (nonatomic, assign) NSUInteger width;
@property (nonatomic, assign) NSUInteger height;
@property (nonatomic, assign) MTLPixelFormat pixelFormat;
@property (nonatomic, assign) GLint minFilter;
@property (nonatomic, assign) GLint magFilter;
@property (nonatomic, assign) GLint wrapS;
@property (nonatomic, assign) GLint wrapT;
@property (nonatomic, strong) id<MTLSamplerState> samplerState;
@end

@implementation PSTTextureInfo
@end

static id<MTLDevice> s_device = nil;
static NSMutableDictionary<NSNumber *, PSTTextureInfo *> *s_textureMap = nil;
static NSMutableDictionary<NSString *, id<MTLSamplerState>> *s_samplerCache = nil;
static id<MTLTexture> s_defaultWhiteTexture = nil;
static id<MTLSamplerState> s_defaultSampler = nil;
static GLuint s_nextTexId = 1000;
static GLuint s_currentBoundTexture[MAX_TEXTURE_UNITS] = {0};

static id<MTLSamplerState> get_or_create_sampler(GLint minFilter, GLint magFilter, GLint wrapS, GLint wrapT) {
    if (!s_device) return nil;
    
    NSString *key = [NSString stringWithFormat:@"%d_%d_%d_%d", minFilter, magFilter, wrapS, wrapT];
    id<MTLSamplerState> cached = s_samplerCache[key];
    if (cached) return cached;

    MTLSamplerDescriptor *desc = [[MTLSamplerDescriptor alloc] init];
    desc.minFilter = (minFilter == GL_LINEAR) ? MTLSamplerMinMagFilterLinear : MTLSamplerMinMagFilterNearest;
    desc.magFilter = (magFilter == GL_LINEAR) ? MTLSamplerMinMagFilterLinear : MTLSamplerMinMagFilterNearest;
    desc.sAddressMode = (wrapS == GL_REPEAT) ? MTLSamplerAddressModeRepeat : MTLSamplerAddressModeClampToEdge;
    desc.tAddressMode = (wrapT == GL_REPEAT) ? MTLSamplerAddressModeRepeat : MTLSamplerAddressModeClampToEdge;

    id<MTLSamplerState> sampler = [s_device newSamplerStateWithDescriptor:desc];
    if (sampler) {
        s_samplerCache[key] = sampler;
    }
    return sampler;
}

void metal_textures_init(id<MTLDevice> device) {
    s_device = device;
    s_textureMap = [[NSMutableDictionary alloc] init];
    s_samplerCache = [[NSMutableDictionary alloc] init];

    // Create 1x1 solid white texture as default
    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                    width:1
                                                                                   height:1
                                                                                mipmapped:NO];
    desc.usage = MTLTextureUsageShaderRead;
    s_defaultWhiteTexture = [s_device newTextureWithDescriptor:desc];
    uint32_t whitePixel = 0xFFFFFFFF;
    [s_defaultWhiteTexture replaceRegion:MTLRegionMake2D(0, 0, 1, 1)
                             mipmapLevel:0
                               withBytes:&whitePixel
                             bytesPerRow:4];

    s_defaultSampler = get_or_create_sampler(GL_LINEAR, GL_LINEAR, GL_CLAMP_TO_EDGE, GL_CLAMP_TO_EDGE);
    NSLog(@"[PSTMetal] Texture subsystem initialized with default fallback texture.");
}

void metal_tex_gen_textures(GLsizei n, GLuint *textures) {
    for (GLsizei i = 0; i < n; i++) {
        GLuint newId = s_nextTexId++;
        textures[i] = newId;
        PSTTextureInfo *info = [[PSTTextureInfo alloc] init];
        info.minFilter = GL_LINEAR;
        info.magFilter = GL_LINEAR;
        info.wrapS = GL_CLAMP_TO_EDGE;
        info.wrapT = GL_CLAMP_TO_EDGE;
        s_textureMap[@(newId)] = info;
    }
}

void metal_tex_delete_textures(GLsizei n, const GLuint *textures) {
    for (GLsizei i = 0; i < n; i++) {
        GLuint texId = textures[i];
        [s_textureMap removeObjectForKey:@(texId)];
        for (int u = 0; u < MAX_TEXTURE_UNITS; u++) {
            if (s_currentBoundTexture[u] == texId) {
                s_currentBoundTexture[u] = 0;
            }
        }
    }
}

void metal_tex_bind_texture(GLenum target, GLuint texture) {
    (void)target;
    uint32_t unit = g_glState.activeTextureUnit;
    if (unit < MAX_TEXTURE_UNITS) {
        s_currentBoundTexture[unit] = texture;
        g_glState.textureUnits[unit].boundTexture2D = texture;
    }
    
    // Auto-create texture info if not existing (GL allows glBindTexture on un-generated ID)
    if (texture != 0 && !s_textureMap[@(texture)]) {
        PSTTextureInfo *info = [[PSTTextureInfo alloc] init];
        info.minFilter = GL_LINEAR;
        info.magFilter = GL_LINEAR;
        info.wrapS = GL_CLAMP_TO_EDGE;
        info.wrapT = GL_CLAMP_TO_EDGE;
        s_textureMap[@(texture)] = info;
    }
}

void metal_tex_image_2d(GLenum target, GLint level, GLint internalformat,
                        GLsizei width, GLsizei height, GLint border,
                        GLenum format, GLenum type, const void *pixels) {
    (void)target; (void)level; (void)internalformat; (void)border; (void)type;
    
    if (width <= 0 || height <= 0 || !s_device) return;
    
    uint32_t unit = g_glState.activeTextureUnit;
    GLuint texId = (unit < MAX_TEXTURE_UNITS) ? s_currentBoundTexture[unit] : 0;
    if (texId == 0) return;

    PSTTextureInfo *info = s_textureMap[@(texId)];
    if (!info) {
        info = [[PSTTextureInfo alloc] init];
        s_textureMap[@(texId)] = info;
    }

    MTLPixelFormat mtlFormat = MTLPixelFormatRGBA8Unorm;
    size_t bytesPerPixel = 4;
    const void *uploadPixels = pixels;
    NSMutableData *convertedData = nil;

    switch (format) {
        case GL_BGRA:
            mtlFormat = MTLPixelFormatBGRA8Unorm;
            bytesPerPixel = 4;
            break;
        case GL_RGBA:
            mtlFormat = MTLPixelFormatRGBA8Unorm;
            bytesPerPixel = 4;
            break;
        case GL_RGB: {
            mtlFormat = MTLPixelFormatRGBA8Unorm;
            bytesPerPixel = 4;
            if (pixels) {
                // Convert RGB (24-bit) to RGBA (32-bit)
                size_t numPixels = (size_t)width * height;
                convertedData = [NSMutableData dataWithLength:numPixels * 4];
                uint8_t *dst = (uint8_t *)convertedData.mutableBytes;
                const uint8_t *src = (const uint8_t *)pixels;
                for (size_t i = 0; i < numPixels; i++) {
                    dst[i * 4 + 0] = src[i * 3 + 0];
                    dst[i * 4 + 1] = src[i * 3 + 1];
                    dst[i * 4 + 2] = src[i * 3 + 2];
                    dst[i * 4 + 3] = 255;
                }
                uploadPixels = dst;
            }
            break;
        }
        case GL_ALPHA:
        case GL_LUMINANCE:
        case 0x1903: /* GL_RED */
            mtlFormat = MTLPixelFormatR8Unorm;
            bytesPerPixel = 1;
            break;
        case GL_LUMINANCE_ALPHA: {
            mtlFormat = MTLPixelFormatRGBA8Unorm;
            bytesPerPixel = 4;
            if (pixels) {
                size_t numPixels = (size_t)width * height;
                convertedData = [NSMutableData dataWithLength:numPixels * 4];
                uint8_t *dst = (uint8_t *)convertedData.mutableBytes;
                const uint8_t *src = (const uint8_t *)pixels;
                for (size_t i = 0; i < numPixels; i++) {
                    uint8_t lum = src[i * 2 + 0];
                    uint8_t a = src[i * 2 + 1];
                    dst[i * 4 + 0] = lum;
                    dst[i * 4 + 1] = lum;
                    dst[i * 4 + 2] = lum;
                    dst[i * 4 + 3] = a;
                }
                uploadPixels = dst;
            }
            break;
        }
        default:
            mtlFormat = MTLPixelFormatRGBA8Unorm;
            bytesPerPixel = 4;
            break;
    }

    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:mtlFormat
                                                                                    width:width
                                                                                   height:height
                                                                                mipmapped:NO];
    desc.usage = MTLTextureUsageShaderRead;
    id<MTLTexture> mtlTex = [s_device newTextureWithDescriptor:desc];

    if (uploadPixels && mtlTex) {
        NSUInteger bytesPerRow = width * bytesPerPixel;
        [mtlTex replaceRegion:MTLRegionMake2D(0, 0, width, height)
                  mipmapLevel:0
                    withBytes:uploadPixels
                  bytesPerRow:bytesPerRow];
    }

    info.texture = mtlTex;
    info.width = width;
    info.height = height;
    info.pixelFormat = mtlFormat;
    info.samplerState = get_or_create_sampler(info.minFilter, info.magFilter, info.wrapS, info.wrapT);
}

void metal_tex_sub_image_2d(GLenum target, GLint level,
                            GLint xoffset, GLint yoffset,
                            GLsizei width, GLsizei height,
                            GLenum format, GLenum type, const void *pixels) {
    (void)target; (void)level; (void)type;
    if (!pixels || width <= 0 || height <= 0) return;

    uint32_t unit = g_glState.activeTextureUnit;
    GLuint texId = (unit < MAX_TEXTURE_UNITS) ? s_currentBoundTexture[unit] : 0;
    PSTTextureInfo *info = s_textureMap[@(texId)];
    if (!info || !info.texture) return;

    size_t bpp = (info.pixelFormat == MTLPixelFormatR8Unorm || info.pixelFormat == MTLPixelFormatA8Unorm) ? 1 : 4;
    const void *uploadBytes = pixels;
    NSMutableData *converted = nil;

    if (format == GL_RGB && bpp == 4) {
        size_t numPixels = (size_t)width * height;
        converted = [NSMutableData dataWithLength:numPixels * 4];
        uint8_t *dst = (uint8_t *)converted.mutableBytes;
        const uint8_t *src = (const uint8_t *)pixels;
        for (size_t i = 0; i < numPixels; i++) {
            dst[i * 4 + 0] = src[i * 3 + 0];
            dst[i * 4 + 1] = src[i * 3 + 1];
            dst[i * 4 + 2] = src[i * 3 + 2];
            dst[i * 4 + 3] = 255;
        }
        uploadBytes = dst;
    }

    [info.texture replaceRegion:MTLRegionMake2D(xoffset, yoffset, width, height)
                    mipmapLevel:0
                      withBytes:uploadBytes
                    bytesPerRow:width * bpp];
}

void metal_tex_compressed_image_2d(GLenum target, GLint level,
                                   GLenum internalformat,
                                   GLsizei width, GLsizei height,
                                   GLint border, GLsizei imageSize,
                                   const void *data) {
    (void)target; (void)level; (void)border;
    if (!data || width <= 0 || height <= 0 || !s_device) return;

    uint32_t unit = g_glState.activeTextureUnit;
    GLuint texId = (unit < MAX_TEXTURE_UNITS) ? s_currentBoundTexture[unit] : 0;
    PSTTextureInfo *info = s_textureMap[@(texId)];
    if (!info) {
        info = [[PSTTextureInfo alloc] init];
        s_textureMap[@(texId)] = info;
    }

    MTLPixelFormat mtlFormat = MTLPixelFormatBC1_RGBA;
    NSUInteger bytesPerRow = ((width + 3) / 4) * 8; // 8 bytes per 4x4 block for BC1/DXT1

    if (internalformat == GL_COMPRESSED_RGBA_S3TC_DXT5_EXT || internalformat == GL_COMPRESSED_RGBA_S3TC_DXT3_EXT) {
        mtlFormat = MTLPixelFormatBC3_RGBA;
        bytesPerRow = ((width + 3) / 4) * 16; // 16 bytes per 4x4 block for BC3/DXT5
    }

    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:mtlFormat
                                                                                    width:width
                                                                                   height:height
                                                                                mipmapped:NO];
    desc.usage = MTLTextureUsageShaderRead;
    id<MTLTexture> mtlTex = [s_device newTextureWithDescriptor:desc];

    if (mtlTex) {
        [mtlTex replaceRegion:MTLRegionMake2D(0, 0, width, height)
                  mipmapLevel:0
                    withBytes:data
                  bytesPerRow:bytesPerRow];
    }

    info.texture = mtlTex;
    info.width = width;
    info.height = height;
    info.pixelFormat = mtlFormat;
    info.samplerState = get_or_create_sampler(info.minFilter, info.magFilter, info.wrapS, info.wrapT);
}

void metal_tex_parameteri(GLenum target, GLenum pname, GLint param) {
    (void)target;
    uint32_t unit = g_glState.activeTextureUnit;
    GLuint texId = (unit < MAX_TEXTURE_UNITS) ? s_currentBoundTexture[unit] : 0;
    PSTTextureInfo *info = s_textureMap[@(texId)];
    if (!info) return;

    switch (pname) {
        case 0x2800: // GL_TEXTURE_MAG_FILTER
            info.magFilter = param;
            break;
        case 0x2801: // GL_TEXTURE_MIN_FILTER
            info.minFilter = param;
            break;
        case 0x2802: // GL_TEXTURE_WRAP_S
            info.wrapS = param;
            break;
        case 0x2803: // GL_TEXTURE_WRAP_T
            info.wrapT = param;
            break;
        default:
            break;
    }
    info.samplerState = get_or_create_sampler(info.minFilter, info.magFilter, info.wrapS, info.wrapT);
}

id<MTLTexture> metal_tex_get_current(uint32_t unit) {
    if (unit >= MAX_TEXTURE_UNITS) return s_defaultWhiteTexture;
    GLuint texId = s_currentBoundTexture[unit];
    if (texId == 0) return s_defaultWhiteTexture;
    PSTTextureInfo *info = s_textureMap[@(texId)];
    return (info && info.texture) ? info.texture : s_defaultWhiteTexture;
}

id<MTLTexture> metal_tex_get_by_id(GLuint texId) {
    if (texId == 0) return s_defaultWhiteTexture;
    PSTTextureInfo *info = s_textureMap[@(texId)];
    return (info && info.texture) ? info.texture : s_defaultWhiteTexture;
}

id<MTLSamplerState> metal_tex_get_sampler_for_current(uint32_t unit) {
    if (unit >= MAX_TEXTURE_UNITS) return s_defaultSampler;
    GLuint texId = s_currentBoundTexture[unit];
    PSTTextureInfo *info = s_textureMap[@(texId)];
    return (info && info.samplerState) ? info.samplerState : s_defaultSampler;
}
