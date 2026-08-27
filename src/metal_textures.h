#ifndef PSTMETAL_TEXTURES_H
#define PSTMETAL_TEXTURES_H

#import <Metal/Metal.h>
#import <OpenGL/gl.h>

#ifdef __cplusplus
extern "C" {
#endif

// Initialize texture management subsystem
void metal_textures_init(id<MTLDevice> device);

// GL texture management calls
void metal_tex_gen_textures(GLsizei n, GLuint *textures);
void metal_tex_delete_textures(GLsizei n, const GLuint *textures);
void metal_tex_bind_texture(GLenum target, GLuint texture);
void metal_tex_image_2d(GLenum target, GLint level, GLint internalformat,
                        GLsizei width, GLsizei height, GLint border,
                        GLenum format, GLenum type, const void *pixels);
void metal_tex_sub_image_2d(GLenum target, GLint level,
                            GLint xoffset, GLint yoffset,
                            GLsizei width, GLsizei height,
                            GLenum format, GLenum type, const void *pixels);
void metal_tex_compressed_image_2d(GLenum target, GLint level,
                                   GLenum internalformat,
                                   GLsizei width, GLsizei height,
                                   GLint border, GLsizei imageSize,
                                   const void *data);
void metal_tex_parameteri(GLenum target, GLenum pname, GLint param);

// Retrieval
id<MTLTexture> metal_tex_get_current(uint32_t unit);
id<MTLTexture> metal_tex_get_by_id(GLuint texId);
id<MTLSamplerState> metal_tex_get_sampler_for_current(uint32_t unit);

#ifdef __cplusplus
}
#endif

#endif // PSTMETAL_TEXTURES_H
