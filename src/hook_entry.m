#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <OpenGL/gl.h>
#import <OpenGL/glext.h>
#import <dlfcn.h>
#import <stdatomic.h>
#import <objc/runtime.h>
#import "fishhook.h"
#import "gl_state.h"
#import "metal_renderer.h"
#import "metal_textures.h"
#import "shader_map.h"

#define DEBUG_LOG_GL 0

#if DEBUG_LOG_GL
#define LOG_GL(...) NSLog(@"[InfinityMetal] " __VA_ARGS__)
#else
#define LOG_GL(...)
#endif

// Global frame counter
_Atomic uint64_t g_frameCount = 0;
static _Atomic uint64_t stat_glDrawArrays = 0;
static _Atomic uint64_t stat_glTexImage2D = 0;
static _Atomic uint64_t stat_glClear = 0;

// ============================================================================
// Original function pointers
// ============================================================================

static void (*orig_glEnable)(GLenum cap);
static void (*orig_glDisable)(GLenum cap);
static void (*orig_glBlendFunc)(GLenum sfactor, GLenum dfactor);
static void (*orig_glViewport)(GLint x, GLint y, GLsizei width, GLsizei height);
static void (*orig_glScissor)(GLint x, GLint y, GLsizei width, GLsizei height);
static void (*orig_glClear)(GLbitfield mask);
static void (*orig_glClearColor)(GLclampf red, GLclampf green, GLclampf blue, GLclampf alpha);

static void (*orig_glMatrixMode)(GLenum mode);
static void (*orig_glLoadIdentity)(void);
static void (*orig_glLoadMatrixf)(const GLfloat *m);
static void (*orig_glOrtho)(GLdouble left, GLdouble right, GLdouble bottom, GLdouble top, GLdouble zNear, GLdouble zFar);
static void (*orig_glPushMatrix)(void);
static void (*orig_glPopMatrix)(void);
static void (*orig_glColor4f)(GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha);
static void (*orig_glColor4ub)(GLubyte red, GLubyte green, GLubyte blue, GLubyte alpha);
static void (*orig_glScalef)(GLfloat x, GLfloat y, GLfloat z);
static void (*orig_glTexEnvi)(GLenum target, GLenum pname, GLint param);
static void (*orig_glTexEnvf)(GLenum target, GLenum pname, GLfloat param);

static void (*orig_glVertexPointer)(GLint size, GLenum type, GLsizei stride, const void *pointer);
static void (*orig_glTexCoordPointer)(GLint size, GLenum type, GLsizei stride, const void *pointer);
static void (*orig_glColorPointer)(GLint size, GLenum type, GLsizei stride, const void *pointer);
static void (*orig_glEnableClientState)(GLenum array);
static void (*orig_glDisableClientState)(GLenum array);
static void (*orig_glClientActiveTexture)(GLenum texture);
static void (*orig_glVertexAttribPointer)(GLuint index, GLint size, GLenum type, GLboolean normalized, GLsizei stride, const void *pointer);
static void (*orig_glEnableVertexAttribArray)(GLuint index);
static void (*orig_glDisableVertexAttribArray)(GLuint index);
static void (*orig_glBindAttribLocation)(GLuint program, GLuint index, const GLchar *name);

static void (*orig_glGenTextures)(GLsizei n, GLuint *textures);
static void (*orig_glDeleteTextures)(GLsizei n, const GLuint *textures);
static void (*orig_glBindTexture)(GLenum target, GLuint texture);
static void (*orig_glTexImage2D)(GLenum target, GLint level, GLint internalformat, GLsizei width, GLsizei height, GLint border, GLenum format, GLenum type, const void *pixels);
static void (*orig_glTexSubImage2D)(GLenum target, GLint level, GLint xoffset, GLint yoffset, GLsizei width, GLsizei height, GLenum format, GLenum type, const void *pixels);
static void (*orig_glCompressedTexImage2D)(GLenum target, GLint level, GLenum internalformat, GLsizei width, GLsizei height, GLint border, GLsizei imageSize, const void *data);
static void (*orig_glTexParameteri)(GLenum target, GLenum pname, GLint param);
static void (*orig_glPixelStorei)(GLenum pname, GLint param);
static void (*orig_glActiveTexture)(GLenum texture);

static GLuint (*orig_glCreateShader)(GLenum type);
static void (*orig_glShaderSource)(GLuint shader, GLsizei count, const GLchar *const*string, const GLint *length);
static void (*orig_glCompileShader)(GLuint shader);
static GLuint (*orig_glCreateProgram)(void);
static void (*orig_glAttachShader)(GLuint program, GLuint shader);
static void (*orig_glLinkProgram)(GLuint program);
static void (*orig_glUseProgram)(GLuint program);
static void (*orig_glDeleteShader)(GLuint shader);
static void (*orig_glDeleteProgram)(GLuint program);
static GLint (*orig_glGetUniformLocation)(GLuint program, const GLchar *name);
static void (*orig_glUniform1i)(GLint location, GLint v0);
static void (*orig_glUniform1f)(GLint location, GLfloat v0);
static void (*orig_glUniform2fv)(GLint location, GLsizei count, const GLfloat *value);
static void (*orig_glUniform4fv)(GLint location, GLsizei count, const GLfloat *value);
static void (*orig_glGetShaderiv)(GLuint shader, GLenum pname, GLint *params);
static void (*orig_glGetShaderInfoLog)(GLuint shader, GLsizei bufSize, GLsizei *length, GLchar *infoLog);
static void (*orig_glGetProgramiv)(GLuint program, GLenum pname, GLint *params);
static void (*orig_glGetProgramInfoLog)(GLuint program, GLsizei bufSize, GLsizei *length, GLchar *infoLog);

static void (*orig_glBindFramebuffer)(GLenum target, GLuint framebuffer);
static void (*orig_glGenFramebuffers)(GLsizei n, GLuint *framebuffers);
static void (*orig_glFramebufferTexture2D)(GLenum target, GLenum attachment, GLenum textarget, GLuint texture, GLint level);

static void (*orig_glDrawArrays)(GLenum mode, GLint first, GLsizei count);

static void (*orig_glCullFace)(GLenum mode);
static void (*orig_glDepthFunc)(GLenum func);
static void (*orig_glDepthMask)(GLboolean flag);
static void (*orig_glColorMask)(GLboolean r, GLboolean g, GLboolean b, GLboolean a);
static void (*orig_glStencilMask)(GLuint mask);
static void (*orig_glClearDepth)(GLclampd depth);
static void (*orig_glFinish)(void);
static void (*orig_glReadPixels)(GLint x, GLint y, GLsizei width, GLsizei height, GLenum format, GLenum type, void *pixels);

static const GLubyte * (*orig_glGetString)(GLenum name);
static void (*orig_glGetIntegerv)(GLenum pname, GLint *data);
static GLenum (*orig_glGetError)(void);

// ============================================================================
// Hook Implementations
// ============================================================================

static void my_glEnable(GLenum cap) {
    if (cap == 0x0BE2 /* GL_BLEND */) g_glState.blend.enabled = true;
    else if (cap == 0x0C11 /* GL_SCISSOR_TEST */) g_glState.scissor.enabled = true;
    else if (cap == 0x0DE1 /* GL_TEXTURE_2D */) g_glState.texture2DEnabled = true;
    if (orig_glEnable) orig_glEnable(cap);
}

static void my_glDisable(GLenum cap) {
    if (cap == 0x0BE2 /* GL_BLEND */) g_glState.blend.enabled = false;
    else if (cap == 0x0C11 /* GL_SCISSOR_TEST */) g_glState.scissor.enabled = false;
    else if (cap == 0x0DE1 /* GL_TEXTURE_2D */) g_glState.texture2DEnabled = false;
    if (orig_glDisable) orig_glDisable(cap);
}

static void my_glBlendFunc(GLenum sfactor, GLenum dfactor) {
    g_glState.blend.srcFactor = sfactor;
    g_glState.blend.dstFactor = dfactor;
    if (orig_glBlendFunc) orig_glBlendFunc(sfactor, dfactor);
}

static void my_glViewport(GLint x, GLint y, GLsizei width, GLsizei height) {
    metal_renderer_viewport(x, y, width, height);
    if (orig_glViewport) orig_glViewport(x, y, width, height);
}

static void my_glScissor(GLint x, GLint y, GLsizei width, GLsizei height) {
    metal_renderer_scissor(x, y, width, height);
    if (orig_glScissor) orig_glScissor(x, y, width, height);
}

static void my_glClear(GLbitfield mask) {
    atomic_fetch_add_explicit(&stat_glClear, 1, memory_order_relaxed);
    metal_renderer_clear(mask);
    if (orig_glClear) orig_glClear(mask);
}

static void my_glClearColor(GLclampf red, GLclampf green, GLclampf blue, GLclampf alpha) {
    g_glState.clearColor[0] = red;
    g_glState.clearColor[1] = green;
    g_glState.clearColor[2] = blue;
    g_glState.clearColor[3] = alpha;
    if (orig_glClearColor) orig_glClearColor(red, green, blue, alpha);
}

// Fixed pipeline / Matrices
static void my_glMatrixMode(GLenum mode) {
    g_glState.matrixMode = mode;
    if (orig_glMatrixMode) orig_glMatrixMode(mode);
}

static void my_glLoadIdentity(void) {
    glstate_load_identity();
    if (orig_glLoadIdentity) orig_glLoadIdentity();
}

static void my_glLoadMatrixf(const GLfloat *m) {
    glstate_load_matrix(m);
    if (orig_glLoadMatrixf) orig_glLoadMatrixf(m);
}

static void my_glOrtho(GLdouble left, GLdouble right, GLdouble bottom, GLdouble top, GLdouble zNear, GLdouble zFar) {
    glstate_ortho(left, right, bottom, top, zNear, zFar);
    if (orig_glOrtho) orig_glOrtho(left, right, bottom, top, zNear, zFar);
}

static void my_glPushMatrix(void) {
    glstate_push_matrix();
    if (orig_glPushMatrix) orig_glPushMatrix();
}

static void my_glPopMatrix(void) {
    glstate_pop_matrix();
    if (orig_glPopMatrix) orig_glPopMatrix();
}

static void my_glColor4f(GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha) {
    glstate_color4f(red, green, blue, alpha);
    if (orig_glColor4f) orig_glColor4f(red, green, blue, alpha);
}

static void my_glColor4ub(GLubyte red, GLubyte green, GLubyte blue, GLubyte alpha) {
    glstate_color4ub(red, green, blue, alpha);
    if (orig_glColor4ub) orig_glColor4ub(red, green, blue, alpha);
}

static void my_glScalef(GLfloat x, GLfloat y, GLfloat z) {
    (void)x; (void)y; (void)z;
    if (orig_glScalef) orig_glScalef(x, y, z);
}

static void my_glTexEnvi(GLenum target, GLenum pname, GLint param) {
    (void)target; (void)pname; (void)param;
    if (orig_glTexEnvi) orig_glTexEnvi(target, pname, param);
}

static void my_glTexEnvf(GLenum target, GLenum pname, GLfloat param) {
    (void)target; (void)pname; (void)param;
    if (orig_glTexEnvf) orig_glTexEnvf(target, pname, param);
}

// Vertex Arrays
static void my_glVertexPointer(GLint size, GLenum type, GLsizei stride, const void *pointer) {
    g_glState.vertexSize = size;
    g_glState.vertexType = type;
    g_glState.vertexStride = stride;
    g_glState.vertexPointer = pointer;
    NSLog(@"[InfinityMetal-Ptr] glVertexPointer: size=%d, type=0x%x, stride=%d, ptr=%p", size, type, stride, pointer);
    if (orig_glVertexPointer) orig_glVertexPointer(size, type, stride, pointer);
}

static void my_glTexCoordPointer(GLint size, GLenum type, GLsizei stride, const void *pointer) {
    g_glState.texCoordSize = size;
    g_glState.texCoordType = type;
    g_glState.texCoordStride = stride;
    g_glState.texCoordPointer = pointer;
    NSLog(@"[InfinityMetal-Ptr] glTexCoordPointer: size=%d, type=0x%x, stride=%d, ptr=%p", size, type, stride, pointer);
    if (orig_glTexCoordPointer) orig_glTexCoordPointer(size, type, stride, pointer);
}

static void my_glColorPointer(GLint size, GLenum type, GLsizei stride, const void *pointer) {
    g_glState.colorSize = size;
    g_glState.colorType = type;
    g_glState.colorStride = stride;
    g_glState.colorPointer = pointer;
    NSLog(@"[InfinityMetal-Ptr] glColorPointer: size=%d, type=0x%x, stride=%d, ptr=%p", size, type, stride, pointer);
    if (orig_glColorPointer) orig_glColorPointer(size, type, stride, pointer);
}

static void my_glEnableClientState(GLenum array) {
    NSLog(@"[InfinityMetal-ClientState] glEnableClientState: 0x%x", array);
    if (array == 0x8074 /* GL_VERTEX_ARRAY */) g_glState.vertexArrayEnabled = true;
    else if (array == 0x8078 /* GL_TEXTURE_COORD_ARRAY */) g_glState.texCoordArrayEnabled = true;
    else if (array == 0x8076 /* GL_COLOR_ARRAY */) g_glState.colorArrayEnabled = true;
    if (orig_glEnableClientState) orig_glEnableClientState(array);
}

static void my_glDisableClientState(GLenum array) {
    NSLog(@"[InfinityMetal-ClientState] glDisableClientState: 0x%x", array);
    if (array == 0x8074 /* GL_VERTEX_ARRAY */) g_glState.vertexArrayEnabled = false;
    else if (array == 0x8078 /* GL_TEXTURE_COORD_ARRAY */) g_glState.texCoordArrayEnabled = false;
    else if (array == 0x8076 /* GL_COLOR_ARRAY */) g_glState.colorArrayEnabled = false;
    if (orig_glDisableClientState) orig_glDisableClientState(array);
}

static void my_glClientActiveTexture(GLenum texture) {
    (void)texture;
    if (orig_glClientActiveTexture) orig_glClientActiveTexture(texture);
}

static void my_glVertexAttribPointer(GLuint index, GLint size, GLenum type, GLboolean normalized, GLsizei stride, const void *pointer) {
    if (index == 0) {
        g_glState.vertexSize = size;
        g_glState.vertexType = type;
        g_glState.vertexStride = stride;
        g_glState.vertexPointer = pointer;
        g_glState.vertexNormalized = normalized;
    } else if (index == 1 || index == 8) {
        g_glState.texCoordSize = size;
        g_glState.texCoordType = type;
        g_glState.texCoordStride = stride;
        g_glState.texCoordPointer = pointer;
        g_glState.texCoordNormalized = normalized;
    } else if (index == 2) {
        g_glState.colorSize = size;
        g_glState.colorType = type;
        g_glState.colorStride = stride;
        g_glState.colorPointer = pointer;
    }
    if (orig_glVertexAttribPointer) orig_glVertexAttribPointer(index, size, type, normalized, stride, pointer);
}

static void my_glEnableVertexAttribArray(GLuint index) {
    if (index == 0) g_glState.vertexArrayEnabled = true;
    else if (index == 1 || index == 8) g_glState.texCoordArrayEnabled = true;
    else if (index == 2) g_glState.colorArrayEnabled = true;
    if (orig_glEnableVertexAttribArray) orig_glEnableVertexAttribArray(index);
}

static void my_glDisableVertexAttribArray(GLuint index) {
    if (index == 0) g_glState.vertexArrayEnabled = false;
    else if (index == 1 || index == 8) g_glState.texCoordArrayEnabled = false;
    else if (index == 2) g_glState.colorArrayEnabled = false;
    if (orig_glDisableVertexAttribArray) orig_glDisableVertexAttribArray(index);
}

static void my_glBindAttribLocation(GLuint program, GLuint index, const GLchar *name) {
    (void)program; (void)index; (void)name;
    if (orig_glBindAttribLocation) orig_glBindAttribLocation(program, index, name);
}

// Textures
static void my_glGenTextures(GLsizei n, GLuint *textures) {
    metal_tex_gen_textures(n, textures);
    if (orig_glGenTextures) orig_glGenTextures(n, textures);
}

static void my_glDeleteTextures(GLsizei n, const GLuint *textures) {
    metal_tex_delete_textures(n, textures);
    if (orig_glDeleteTextures) orig_glDeleteTextures(n, textures);
}

static void my_glBindTexture(GLenum target, GLuint texture) {
    metal_tex_bind_texture(target, texture);
    if (orig_glBindTexture) orig_glBindTexture(target, texture);
}

static void my_glTexImage2D(GLenum target, GLint level, GLint internalformat, GLsizei width, GLsizei height, GLint border, GLenum format, GLenum type, const void *pixels) {
    atomic_fetch_add_explicit(&stat_glTexImage2D, 1, memory_order_relaxed);
    metal_tex_image_2d(target, level, internalformat, width, height, border, format, type, pixels);
    if (orig_glTexImage2D) orig_glTexImage2D(target, level, internalformat, width, height, border, format, type, pixels);
}

static void my_glTexSubImage2D(GLenum target, GLint level, GLint xoffset, GLint yoffset, GLsizei width, GLsizei height, GLenum format, GLenum type, const void *pixels) {
    metal_tex_sub_image_2d(target, level, xoffset, yoffset, width, height, format, type, pixels);
    if (orig_glTexSubImage2D) orig_glTexSubImage2D(target, level, xoffset, yoffset, width, height, format, type, pixels);
}

static void my_glCompressedTexImage2D(GLenum target, GLint level, GLenum internalformat, GLsizei width, GLsizei height, GLint border, GLsizei imageSize, const void *data) {
    metal_tex_compressed_image_2d(target, level, internalformat, width, height, border, imageSize, data);
    if (orig_glCompressedTexImage2D) orig_glCompressedTexImage2D(target, level, internalformat, width, height, border, imageSize, data);
}

static void my_glTexParameteri(GLenum target, GLenum pname, GLint param) {
    metal_tex_parameteri(target, pname, param);
    if (orig_glTexParameteri) orig_glTexParameteri(target, pname, param);
}

static void my_glPixelStorei(GLenum pname, GLint param) {
    if (pname == 0x0CF5 /* GL_UNPACK_ALIGNMENT */) g_glState.pixelStoreUnpackAlignment = param;
    if (orig_glPixelStorei) orig_glPixelStorei(pname, param);
}

static void my_glActiveTexture(GLenum texture) {
    if (texture >= 0x84C0 /* GL_TEXTURE0 */) {
        g_glState.activeTextureUnit = texture - 0x84C0;
    }
    if (orig_glActiveTexture) orig_glActiveTexture(texture);
}

// Shaders
static GLuint my_glCreateShader(GLenum type) {
    GLuint s = shader_map_create_shader(type);
    if (orig_glCreateShader) orig_glCreateShader(type);
    return s;
}

static void my_glShaderSource(GLuint shader, GLsizei count, const GLchar *const*string, const GLint *length) {
    shader_map_shader_source(shader, count, string, length);
    if (orig_glShaderSource) orig_glShaderSource(shader, count, string, length);
}

static void my_glCompileShader(GLuint shader) {
    shader_map_compile_shader(shader);
    if (orig_glCompileShader) orig_glCompileShader(shader);
}

static GLuint my_glCreateProgram(void) {
    GLuint p = shader_map_create_program();
    if (orig_glCreateProgram) orig_glCreateProgram();
    return p;
}

static void my_glAttachShader(GLuint program, GLuint shader) {
    shader_map_attach_shader(program, shader);
    if (orig_glAttachShader) orig_glAttachShader(program, shader);
}

static void my_glLinkProgram(GLuint program) {
    shader_map_link_program(program);
    if (orig_glLinkProgram) orig_glLinkProgram(program);
}

static void my_glUseProgram(GLuint program) {
    shader_map_use_program(program);
    if (orig_glUseProgram) orig_glUseProgram(program);
}

static void my_glDeleteShader(GLuint shader) {
    shader_map_delete_shader(shader);
    if (orig_glDeleteShader) orig_glDeleteShader(shader);
}

static void my_glDeleteProgram(GLuint program) {
    shader_map_delete_program(program);
    if (orig_glDeleteProgram) orig_glDeleteProgram(program);
}

static GLint my_glGetUniformLocation(GLuint program, const GLchar *name) {
    GLint loc = shader_map_get_uniform_location(program, name);
    if (orig_glGetUniformLocation) orig_glGetUniformLocation(program, name);
    return loc;
}

static void (*orig_glUniform1i)(GLint location, GLint v0);
static void my_glUniform1i(GLint location, GLint v0) {
    shader_map_uniform_1i(location, v0);
    if (orig_glUniform1i) orig_glUniform1i(location, v0);
}

static void (*orig_glUniform1f)(GLint location, GLfloat v0);
static void my_glUniform1f(GLint location, GLfloat v0) {
    shader_map_uniform_1f(location, v0);
    if (orig_glUniform1f) orig_glUniform1f(location, v0);
}

static void (*orig_glUniform2f)(GLint location, GLfloat v0, GLfloat v1);
static void my_glUniform2f(GLint location, GLfloat v0, GLfloat v1) {
    shader_map_uniform_2f(location, v0, v1);
    if (orig_glUniform2f) orig_glUniform2f(location, v0, v1);
}

static void (*orig_glUniform4f)(GLint location, GLfloat v0, GLfloat v1, GLfloat v2, GLfloat v3);
static void my_glUniform4f(GLint location, GLfloat v0, GLfloat v1, GLfloat v2, GLfloat v3) {
    shader_map_uniform_4f(location, v0, v1, v2, v3);
    if (orig_glUniform4f) orig_glUniform4f(location, v0, v1, v2, v3);
}

static void my_glUniform2fv(GLint location, GLsizei count, const GLfloat *value) {
    shader_map_uniform_2fv(location, count, value);
    if (orig_glUniform2fv) orig_glUniform2fv(location, count, value);
}

static void my_glUniform4fv(GLint location, GLsizei count, const GLfloat *value) {
    shader_map_uniform_4fv(location, count, value);
    if (orig_glUniform4fv) orig_glUniform4fv(location, count, value);
}

static void my_glGetShaderiv(GLuint shader, GLenum pname, GLint *params) {
    if (pname == 0x8B81 /* GL_COMPILE_STATUS */ && params) {
        *params = 1; // Always claim compiled
        return;
    }
    if (orig_glGetShaderiv) orig_glGetShaderiv(shader, pname, params);
}

static void my_glGetShaderInfoLog(GLuint shader, GLsizei bufSize, GLsizei *length, GLchar *infoLog) {
    if (length) *length = 0;
    if (infoLog && bufSize > 0) infoLog[0] = '\0';
    if (orig_glGetShaderInfoLog) orig_glGetShaderInfoLog(shader, bufSize, length, infoLog);
}

static void my_glGetProgramiv(GLuint program, GLenum pname, GLint *params) {
    if (pname == 0x8B82 /* GL_LINK_STATUS */ && params) {
        *params = 1; // Always claim linked
        return;
    }
    if (orig_glGetProgramiv) orig_glGetProgramiv(program, pname, params);
}

static void my_glGetProgramInfoLog(GLuint program, GLsizei bufSize, GLsizei *length, GLchar *infoLog) {
    if (length) *length = 0;
    if (infoLog && bufSize > 0) infoLog[0] = '\0';
    if (orig_glGetProgramInfoLog) orig_glGetProgramInfoLog(program, bufSize, length, infoLog);
}

// Framebuffer
static void my_glBindFramebuffer(GLenum target, GLuint framebuffer) {
    (void)target; (void)framebuffer;
    if (orig_glBindFramebuffer) orig_glBindFramebuffer(target, framebuffer);
}

static void my_glGenFramebuffers(GLsizei n, GLuint *framebuffers) {
    for (GLsizei i = 0; i < n; i++) framebuffers[i] = 100 + i;
    if (orig_glGenFramebuffers) orig_glGenFramebuffers(n, framebuffers);
}

static void my_glFramebufferTexture2D(GLenum target, GLenum attachment, GLenum textarget, GLuint texture, GLint level) {
    (void)target; (void)attachment; (void)textarget; (void)texture; (void)level;
    if (orig_glFramebufferTexture2D) orig_glFramebufferTexture2D(target, attachment, textarget, texture, level);
}

// Draw Call Execution via Metal
static void my_glDrawArrays(GLenum mode, GLint first, GLsizei count) {
    atomic_fetch_add_explicit(&stat_glDrawArrays, 1, memory_order_relaxed);
    metal_renderer_draw_arrays(mode, first, count);
    if (orig_glDrawArrays) orig_glDrawArrays(mode, first, count);
}

// Additional state
static void my_glCullFace(GLenum mode) { (void)mode; if (orig_glCullFace) orig_glCullFace(mode); }
static void my_glDepthFunc(GLenum func) { (void)func; if (orig_glDepthFunc) orig_glDepthFunc(func); }
static void my_glDepthMask(GLboolean flag) { g_glState.depthMask = flag; if (orig_glDepthMask) orig_glDepthMask(flag); }
static void my_glColorMask(GLboolean r, GLboolean g, GLboolean b, GLboolean a) { (void)r; (void)g; (void)b; (void)a; if (orig_glColorMask) orig_glColorMask(r, g, b, a); }
static void my_glStencilMask(GLuint mask) { (void)mask; if (orig_glStencilMask) orig_glStencilMask(mask); }
static void my_glClearDepth(GLclampd depth) { (void)depth; if (orig_glClearDepth) orig_glClearDepth(depth); }
static void my_glFinish(void) { if (orig_glFinish) orig_glFinish(); }
static void my_glReadPixels(GLint x, GLint y, GLsizei width, GLsizei height, GLenum format, GLenum type, void *pixels) {
    if (orig_glReadPixels) orig_glReadPixels(x, y, width, height, format, type, pixels);
}

// Query
static const GLubyte * my_glGetString(GLenum name) {
    if (name == 0x1F00 /* GL_VENDOR */) return (const GLubyte *)"Apple";
    if (name == 0x1F01 /* GL_RENDERER */) return (const GLubyte *)"Apple Metal Renderer (InfinityMetal)";
    if (name == 0x1F02 /* GL_VERSION */) return (const GLubyte *)"2.1 Metal - Infinity Engine EE Enhanced";
    if (name == 0x8B8C /* GL_SHADING_LANGUAGE_VERSION */) return (const GLubyte *)"1.20 Metal";
    return orig_glGetString ? orig_glGetString(name) : (const GLubyte *)"";
}

static void my_glGetIntegerv(GLenum pname, GLint *data) {
    if (!data) return;
    if (pname == 0x0BA2 /* GL_VIEWPORT */) {
        data[0] = g_glState.viewport.x;
        data[1] = g_glState.viewport.y;
        data[2] = g_glState.viewport.width;
        data[3] = g_glState.viewport.height;
        return;
    }
    if (orig_glGetIntegerv) orig_glGetIntegerv(pname, data);
}

static GLenum my_glGetError(void) {
    return 0; // GL_NO_ERROR
}

// ============================================================================
// Objective-C Swizzles (NSOpenGLContext)
// ============================================================================

static IMP orig_setView_imp = NULL;
static IMP orig_flushBuffer_imp = NULL;

static void swizzled_setView(id self, SEL _cmd, NSView *view) {
    // 1. Call original setView
    ((void (*)(id, SEL, NSView *))orig_setView_imp)(self, _cmd, view);
    
    // 2. Attach Metal layer to the view
    if (view) {
        metal_renderer_attach_to_view(view);
    }
}

static void swizzled_flushBuffer(id self, SEL _cmd) {
    (void)self; (void)_cmd;
    uint64_t frame = atomic_fetch_add_explicit(&g_frameCount, 1, memory_order_relaxed);

    if (frame % 60 == 0) {
        uint64_t draws = atomic_exchange_explicit(&stat_glDrawArrays, 0, memory_order_relaxed);
        uint64_t texs = atomic_exchange_explicit(&stat_glTexImage2D, 0, memory_order_relaxed);
        uint64_t clears = atomic_exchange_explicit(&stat_glClear, 0, memory_order_relaxed);

        NSLog(@"[InfinityMetal] Frame %llu (Metal Native) | 60f draws: %llu, tex: %llu, clear: %llu",
              frame, draws, texs, clears);
    }

    // Metal frame presentation
    metal_renderer_frame_flush();
    // Do NOT call orig_flushBuffer_imp as it flushes OpenGL's unrendered black surface over our CAMetalLayer
}

static void swizzle_nsopengl_context(void) {
    Class cls = objc_getClass("NSOpenGLContext");
    if (!cls) return;

    Method setViewMethod = class_getInstanceMethod(cls, @selector(setView:));
    if (setViewMethod) {
        orig_setView_imp = method_setImplementation(setViewMethod, (IMP)swizzled_setView);
        NSLog(@"[InfinityMetal] Swizzled -[NSOpenGLContext setView:] for CAMetalLayer attachment.");
    }

    Method flushMethod = class_getInstanceMethod(cls, @selector(flushBuffer));
    if (flushMethod) {
        orig_flushBuffer_imp = method_setImplementation(flushMethod, (IMP)swizzled_flushBuffer);
        NSLog(@"[InfinityMetal] Swizzled -[NSOpenGLContext flushBuffer] for Metal frame presentation.");
    }
}

// ============================================================================
// Dynamic Symbol Interception (dlsym)
// ============================================================================

static void* lookup_hooked_gl_symbol(const char *name) {
#define HOOK_CMP(sym) if (strcmp(name, #sym) == 0) return (void*)my_##sym
    HOOK_CMP(glEnable);
    HOOK_CMP(glDisable);
    HOOK_CMP(glBlendFunc);
    HOOK_CMP(glViewport);
    HOOK_CMP(glScissor);
    HOOK_CMP(glClear);
    HOOK_CMP(glClearColor);

    HOOK_CMP(glMatrixMode);
    HOOK_CMP(glLoadIdentity);
    HOOK_CMP(glLoadMatrixf);
    HOOK_CMP(glOrtho);
    HOOK_CMP(glPushMatrix);
    HOOK_CMP(glPopMatrix);
    HOOK_CMP(glColor4f);
    HOOK_CMP(glColor4ub);
    HOOK_CMP(glScalef);
    HOOK_CMP(glTexEnvi);
    HOOK_CMP(glTexEnvf);

    HOOK_CMP(glVertexPointer);
    HOOK_CMP(glTexCoordPointer);
    HOOK_CMP(glColorPointer);
    HOOK_CMP(glEnableClientState);
    HOOK_CMP(glClientActiveTexture);
    HOOK_CMP(glVertexAttribPointer);
    HOOK_CMP(glEnableVertexAttribArray);
    HOOK_CMP(glBindAttribLocation);

    HOOK_CMP(glGenTextures);
    HOOK_CMP(glDeleteTextures);
    HOOK_CMP(glBindTexture);
    HOOK_CMP(glTexImage2D);
    HOOK_CMP(glTexSubImage2D);
    HOOK_CMP(glCompressedTexImage2D);
    HOOK_CMP(glTexParameteri);
    HOOK_CMP(glPixelStorei);
    HOOK_CMP(glActiveTexture);

    HOOK_CMP(glCreateShader);
    HOOK_CMP(glShaderSource);
    HOOK_CMP(glCompileShader);
    HOOK_CMP(glCreateProgram);
    HOOK_CMP(glAttachShader);
    HOOK_CMP(glLinkProgram);
    HOOK_CMP(glUseProgram);
    HOOK_CMP(glDeleteShader);
    HOOK_CMP(glDeleteProgram);
    HOOK_CMP(glGetUniformLocation);
    HOOK_CMP(glUniform1i);
    HOOK_CMP(glUniform1f);
    HOOK_CMP(glUniform2f);
    HOOK_CMP(glUniform4f);
    HOOK_CMP(glUniform2fv);
    HOOK_CMP(glUniform4fv);
    HOOK_CMP(glGetShaderiv);
    HOOK_CMP(glGetShaderInfoLog);
    HOOK_CMP(glGetProgramiv);
    HOOK_CMP(glGetProgramInfoLog);

    HOOK_CMP(glBindFramebuffer);
    HOOK_CMP(glGenFramebuffers);
    HOOK_CMP(glFramebufferTexture2D);

    HOOK_CMP(glDrawArrays);

    HOOK_CMP(glCullFace);
    HOOK_CMP(glDepthFunc);
    HOOK_CMP(glDepthMask);
    HOOK_CMP(glColorMask);
    HOOK_CMP(glStencilMask);
    HOOK_CMP(glClearDepth);
    HOOK_CMP(glFinish);
    HOOK_CMP(glReadPixels);

    HOOK_CMP(glGetString);
    HOOK_CMP(glGetIntegerv);
    HOOK_CMP(glGetError);
#undef HOOK_CMP
    return NULL;
}

static void* (*orig_dlsym)(void *handle, const char *symbol);
static void* my_dlsym(void *handle, const char *symbol) {
    if (symbol && strncmp(symbol, "gl", 2) == 0) {
        void *override = lookup_hooked_gl_symbol(symbol);
        if (override) return override;
    }
    return orig_dlsym(handle, symbol);
}

// ============================================================================
// Constructor
// ============================================================================

__attribute__((constructor))
static void infinitymetal_init(void) {
    NSLog(@"[InfinityMetal] ========================================");
    NSLog(@"[InfinityMetal] Metal Rendering Backend v1.1.0 (Native Metal)");
    NSLog(@"[InfinityMetal] Infinity Engine: Enhanced Edition");
    NSLog(@"[InfinityMetal] ========================================");

    glstate_init();
    metal_renderer_init();
    swizzle_nsopengl_context();

    struct rebinding rebinds[] = {
        {"glEnable", (void*)my_glEnable, (void**)&orig_glEnable},
        {"glDisable", (void*)my_glDisable, (void**)&orig_glDisable},
        {"glBlendFunc", (void*)my_glBlendFunc, (void**)&orig_glBlendFunc},
        {"glViewport", (void*)my_glViewport, (void**)&orig_glViewport},
        {"glScissor", (void*)my_glScissor, (void**)&orig_glScissor},
        {"glClear", (void*)my_glClear, (void**)&orig_glClear},
        {"glClearColor", (void*)my_glClearColor, (void**)&orig_glClearColor},

        {"glMatrixMode", (void*)my_glMatrixMode, (void**)&orig_glMatrixMode},
        {"glLoadIdentity", (void*)my_glLoadIdentity, (void**)&orig_glLoadIdentity},
        {"glLoadMatrixf", (void*)my_glLoadMatrixf, (void**)&orig_glLoadMatrixf},
        {"glOrtho", (void*)my_glOrtho, (void**)&orig_glOrtho},
        {"glPushMatrix", (void*)my_glPushMatrix, (void**)&orig_glPushMatrix},
        {"glPopMatrix", (void*)my_glPopMatrix, (void**)&orig_glPopMatrix},
        {"glColor4f", (void*)my_glColor4f, (void**)&orig_glColor4f},
        {"glColor4ub", (void*)my_glColor4ub, (void**)&orig_glColor4ub},
        {"glScalef", (void*)my_glScalef, (void**)&orig_glScalef},
        {"glTexEnvi", (void*)my_glTexEnvi, (void**)&orig_glTexEnvi},
        {"glTexEnvf", (void*)my_glTexEnvf, (void**)&orig_glTexEnvf},

        {"glVertexPointer", (void*)my_glVertexPointer, (void**)&orig_glVertexPointer},
        {"glTexCoordPointer", (void*)my_glTexCoordPointer, (void**)&orig_glTexCoordPointer},
        {"glColorPointer", (void*)my_glColorPointer, (void**)&orig_glColorPointer},
        {"glEnableClientState", (void*)my_glEnableClientState, (void**)&orig_glEnableClientState},
        {"glDisableClientState", (void*)my_glDisableClientState, (void**)&orig_glDisableClientState},
        {"glClientActiveTexture", (void*)my_glClientActiveTexture, (void**)&orig_glClientActiveTexture},
        {"glVertexAttribPointer", (void*)my_glVertexAttribPointer, (void**)&orig_glVertexAttribPointer},
        {"glEnableVertexAttribArray", (void*)my_glEnableVertexAttribArray, (void**)&orig_glEnableVertexAttribArray},
        {"glDisableVertexAttribArray", (void*)my_glDisableVertexAttribArray, (void**)&orig_glDisableVertexAttribArray},
        {"glBindAttribLocation", (void*)my_glBindAttribLocation, (void**)&orig_glBindAttribLocation},

        {"glGenTextures", (void*)my_glGenTextures, (void**)&orig_glGenTextures},
        {"glDeleteTextures", (void*)my_glDeleteTextures, (void**)&orig_glDeleteTextures},
        {"glBindTexture", (void*)my_glBindTexture, (void**)&orig_glBindTexture},
        {"glTexImage2D", (void*)my_glTexImage2D, (void**)&orig_glTexImage2D},
        {"glTexSubImage2D", (void*)my_glTexSubImage2D, (void**)&orig_glTexSubImage2D},
        {"glCompressedTexImage2D", (void*)my_glCompressedTexImage2D, (void**)&orig_glCompressedTexImage2D},
        {"glTexParameteri", (void*)my_glTexParameteri, (void**)&orig_glTexParameteri},
        {"glPixelStorei", (void*)my_glPixelStorei, (void**)&orig_glPixelStorei},
        {"glActiveTexture", (void*)my_glActiveTexture, (void**)&orig_glActiveTexture},

        {"glCreateShader", (void*)my_glCreateShader, (void**)&orig_glCreateShader},
        {"glShaderSource", (void*)my_glShaderSource, (void**)&orig_glShaderSource},
        {"glCompileShader", (void*)my_glCompileShader, (void**)&orig_glCompileShader},
        {"glCreateProgram", (void*)my_glCreateProgram, (void**)&orig_glCreateProgram},
        {"glAttachShader", (void*)my_glAttachShader, (void**)&orig_glAttachShader},
        {"glLinkProgram", (void*)my_glLinkProgram, (void**)&orig_glLinkProgram},
        {"glUseProgram", (void*)my_glUseProgram, (void**)&orig_glUseProgram},
        {"glDeleteShader", (void*)my_glDeleteShader, (void**)&orig_glDeleteShader},
        {"glDeleteProgram", (void*)my_glDeleteProgram, (void**)&orig_glDeleteProgram},
        {"glGetUniformLocation", (void*)my_glGetUniformLocation, (void**)&orig_glGetUniformLocation},
        {"glUniform1i", (void*)my_glUniform1i, (void**)&orig_glUniform1i},
        {"glUniform1f", (void*)my_glUniform1f, (void**)&orig_glUniform1f},
        {"glUniform2f", (void*)my_glUniform2f, (void**)&orig_glUniform2f},
        {"glUniform4f", (void*)my_glUniform4f, (void**)&orig_glUniform4f},
        {"glUniform2fv", (void*)my_glUniform2fv, (void**)&orig_glUniform2fv},
        {"glUniform4fv", (void*)my_glUniform4fv, (void**)&orig_glUniform4fv},
        {"glGetShaderiv", (void*)my_glGetShaderiv, (void**)&orig_glGetShaderiv},
        {"glGetShaderInfoLog", (void*)my_glGetShaderInfoLog, (void**)&orig_glGetShaderInfoLog},
        {"glGetProgramiv", (void*)my_glGetProgramiv, (void**)&orig_glGetProgramiv},
        {"glGetProgramInfoLog", (void*)my_glGetProgramInfoLog, (void**)&orig_glGetProgramInfoLog},

        {"glBindFramebuffer", (void*)my_glBindFramebuffer, (void**)&orig_glBindFramebuffer},
        {"glGenFramebuffers", (void*)my_glGenFramebuffers, (void**)&orig_glGenFramebuffers},
        {"glFramebufferTexture2D", (void*)my_glFramebufferTexture2D, (void**)&orig_glFramebufferTexture2D},

        {"glDrawArrays", (void*)my_glDrawArrays, (void**)&orig_glDrawArrays},

        {"glCullFace", (void*)my_glCullFace, (void**)&orig_glCullFace},
        {"glDepthFunc", (void*)my_glDepthFunc, (void**)&orig_glDepthFunc},
        {"glDepthMask", (void*)my_glDepthMask, (void**)&orig_glDepthMask},
        {"glColorMask", (void*)my_glColorMask, (void**)&orig_glColorMask},
        {"glStencilMask", (void*)my_glStencilMask, (void**)&orig_glStencilMask},
        {"glClearDepth", (void*)my_glClearDepth, (void**)&orig_glClearDepth},
        {"glFinish", (void*)my_glFinish, (void**)&orig_glFinish},
        {"glReadPixels", (void*)my_glReadPixels, (void**)&orig_glReadPixels},

        {"glGetString", (void*)my_glGetString, (void**)&orig_glGetString},
        {"glGetIntegerv", (void*)my_glGetIntegerv, (void**)&orig_glGetIntegerv},
        {"glGetError", (void*)my_glGetError, (void**)&orig_glGetError},

        {"dlsym", (void*)my_dlsym, (void**)&orig_dlsym},
    };

    int num_hooks = sizeof(rebinds) / sizeof(struct rebinding);
    NSLog(@"[InfinityMetal] Hooking %d GL symbols via fishhook + 2 ObjC swizzles...", num_hooks);

    int result = rebind_symbols(rebinds, num_hooks);
    if (result == 0) {
        NSLog(@"[InfinityMetal] All symbols hooked successfully. Native Metal pipeline ready.");
    } else {
        NSLog(@"[InfinityMetal] Symbol hooking failed with code %d", result);
    }
}
