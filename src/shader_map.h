#ifndef PSTMETAL_SHADER_MAP_H
#define PSTMETAL_SHADER_MAP_H

#import <Metal/Metal.h>
#import <OpenGL/gl.h>
#import <simd/simd.h>

#ifdef __cplusplus
extern "C" {
#endif

// PST:EE 9 Shader program types
typedef enum {
    PST_SHADER_DRAW = 0,    // fpDraw.glsl
    PST_SHADER_TONE = 1,    // fpTone.glsl
    PST_SHADER_CATROM = 2,  // fpCatRom.glsl
    PST_SHADER_YUV = 3,     // fpYUV.glsl
    PST_SHADER_YUV_GRAY = 4,// fpYUVGRY.glsl
    PST_SHADER_SPRITE = 5,  // fpSprite.glsl
    PST_SHADER_FONT = 6,    // fpFONT.glsl
    PST_SHADER_SELECT = 7,  // fpSELECT.glsl
    PST_SHADER_SEAM = 8,    // fpSEAM.glsl
    PST_SHADER_COUNT = 9
} PSTShaderType;

// Uniforms struct matching MSL layout
typedef struct {
    simd_float4 uST;
    simd_float2 uTcScale;
    simd_float4 uColorTone;
    float       uSpriteBlurAmount;
    float       uZoomStrength;
    float       uBrightness;
    float       uGamma;
} PSTMetalUniforms;

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
PSTShaderType shader_map_get_active_shader(void);
id<MTLRenderPipelineState> shader_map_get_pipeline(PSTShaderType shaderType, uint32_t blendMode);
PSTMetalUniforms shader_map_get_current_uniforms(void);

#ifdef __cplusplus
}
#endif

#endif // PSTMETAL_SHADER_MAP_H
