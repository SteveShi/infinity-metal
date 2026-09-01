#ifndef INFINITY_METAL_SHADER_MAP_H
#define INFINITY_METAL_SHADER_MAP_H

#import <Metal/Metal.h>
#import <OpenGL/gl.h>
#import <simd/simd.h>

#ifdef __cplusplus
extern "C" {
#endif

// Infinity Engine EE 9 Shader program types
typedef enum {
    IE_SHADER_DRAW = 0,    // fpDraw.glsl
    IE_SHADER_TONE = 1,    // fpTone.glsl
    IE_SHADER_CATROM = 2,  // fpCatRom.glsl
    IE_SHADER_YUV = 3,     // fpYUV.glsl
    IE_SHADER_YUV_GRAY = 4,// fpYUVGRY.glsl
    IE_SHADER_SPRITE = 5,  // fpSprite.glsl
    IE_SHADER_FONT = 6,    // fpFONT.glsl
    IE_SHADER_SELECT = 7,  // fpSELECT.glsl
    IE_SHADER_SEAM = 8,    // fpSEAM.glsl
    IE_SHADER_COUNT = 9
} IEShaderType;

// Backward-compat aliases
#define PST_SHADER_DRAW IE_SHADER_DRAW
#define PST_SHADER_TONE IE_SHADER_TONE
#define PST_SHADER_CATROM IE_SHADER_CATROM
#define PST_SHADER_YUV IE_SHADER_YUV
#define PST_SHADER_YUV_GRAY IE_SHADER_YUV_GRAY
#define PST_SHADER_SPRITE IE_SHADER_SPRITE
#define PST_SHADER_FONT IE_SHADER_FONT
#define PST_SHADER_SELECT IE_SHADER_SELECT
#define PST_SHADER_SEAM IE_SHADER_SEAM
#define PST_SHADER_COUNT IE_SHADER_COUNT
typedef IEShaderType PSTShaderType;

// Uniforms struct matching MSL layout
typedef struct {
    simd_float4 uST;
    simd_float2 uTcScale;
    simd_float4 uColorTone;
    float       uSpriteBlurAmount;
    float       uZoomStrength;
    float       uBrightness;
    float       uGamma;
} IEMetalUniforms;

typedef IEMetalUniforms PSTMetalUniforms;

void shader_map_init(id<MTLDevice> device, id<MTLLibrary> library);

// GL API wrappers for shader management
GLuint shader_map_create_shader(GLenum type);
void shader_map_shader_source(GLuint shader, GLsizei count, const GLchar *const*string, const GLint *length);
void shader_map_compile_shader(GLuint shader);
GLuint shader_map_create_program(void);
void shader_map_attach_shader(GLuint program, GLuint shader);
void shader_map_link_program(GLuint program);
void shader_map_use_program(GLuint program);
void shader_map_delete_shader(GLuint shader);
void shader_map_delete_program(GLuint program);

GLint shader_map_get_uniform_location(GLuint program, const GLchar *name);
void shader_map_uniform_1i(GLint location, GLint v0);
void shader_map_uniform_1f(GLint location, GLfloat v0);
void shader_map_uniform_2f(GLint location, GLfloat v0, GLfloat v1);
void shader_map_uniform_4f(GLint location, GLfloat v0, GLfloat v1, GLfloat v2, GLfloat v3);
void shader_map_uniform_2fv(GLint location, GLsizei count, const GLfloat *value);
void shader_map_uniform_4fv(GLint location, GLsizei count, const GLfloat *value);

// Query active shader & pipeline state
IEShaderType shader_map_get_active_shader(void);
id<MTLRenderPipelineState> shader_map_get_pipeline(IEShaderType shaderType, uint32_t blendMode);
IEMetalUniforms shader_map_get_current_uniforms(void);

#ifdef __cplusplus
}
#endif

#endif // INFINITY_METAL_SHADER_MAP_H
