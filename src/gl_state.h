#ifndef PSTMETAL_GL_STATE_H
#define PSTMETAL_GL_STATE_H

#include <stdint.h>
#include <stdbool.h>
#include <OpenGL/gl.h>

// Maximum matrix stack depth (OpenGL spec minimum is 32 for modelview, 2 for projection)
#define MAX_MATRIX_STACK_DEPTH 32
#define MAX_TEXTURE_UNITS 4
#define MAX_IMMEDIATE_VERTICES 65536

// 2D vertex format for immediate mode collection
typedef struct {
    float position[2];   // x, y
    float texCoord[2];   // s, t
    float color[4];      // r, g, b, a
} PSTVertex2D;

// Matrix stack
typedef struct {
    float matrices[MAX_MATRIX_STACK_DEPTH][16]; // column-major 4x4
    int top; // index of current top
} MatrixStack;

// Blend state
typedef struct {
    bool enabled;
    uint32_t srcFactor;  // GLenum
    uint32_t dstFactor;  // GLenum
    uint32_t srcAlpha;   // for separate
    uint32_t dstAlpha;   // for separate
    bool separateAlpha;
} BlendState;

// Scissor state
typedef struct {
    bool enabled;
    int x, y, width, height;
} ScissorState;

// Viewport state
typedef struct {
    int x, y, width, height;
} ViewportState;

// Texture unit state
typedef struct {
    uint32_t boundTexture2D;  // GL texture ID
    uint32_t minFilter;
    uint32_t magFilter;
    uint32_t wrapS;
    uint32_t wrapT;
} TextureUnitState;

// Immediate mode state (glBegin/glEnd)
typedef struct {
    bool active;              // between glBegin and glEnd
    uint32_t mode;            // GL_TRIANGLES, GL_TRIANGLE_STRIP, GL_QUADS, etc.
    PSTVertex2D vertices[MAX_IMMEDIATE_VERTICES];
    int vertexCount;
    float currentColor[4];    // set by glColor4f
    float currentTexCoord[2]; // set by glTexCoord2f
} ImmediateState;

// Shader program state  
typedef struct {
    uint32_t currentProgram;  // GL program ID, 0 = fixed pipeline
} ShaderState;

// Complete GL state
typedef struct {
    // Matrix stacks
    uint32_t matrixMode;      // GL_MODELVIEW or GL_PROJECTION
    MatrixStack modelview;
    MatrixStack projection;
    
    // Computed MVP (modelview * projection), dirty flag
    float mvp[16];
    bool mvpDirty;
    
    // Viewport & scissor
    ViewportState viewport;
    ScissorState scissor;
    
    // Blend
    BlendState blend;
    
    // Clear color
    float clearColor[4];
    
    // Texture units
    uint32_t activeTextureUnit; // 0-based index
    TextureUnitState textureUnits[MAX_TEXTURE_UNITS];
    bool texture2DEnabled;
    
    // Immediate mode
    ImmediateState immediate;
    
    // Shader
    ShaderState shader;
    
    // Client array pointers (for glVertexPointer, etc.)
    const void *vertexPointer;
    GLint vertexSize;
    GLenum vertexType;
    GLsizei vertexStride;
    GLboolean vertexNormalized;
    bool vertexArrayEnabled;

    const void *texCoordPointer;
    GLint texCoordSize;
    GLenum texCoordType;
    GLsizei texCoordStride;
    GLboolean texCoordNormalized;
    bool texCoordArrayEnabled;

    const void *colorPointer;
    GLint colorSize;
    GLenum colorType;
    GLsizei colorStride;
    bool colorArrayEnabled;

    // Misc
    bool depthMask;
    uint32_t pixelStoreUnpackAlignment;
    uint32_t pixelStoreUnpackRowLength;
} GLState;

// Global state instance
extern GLState g_glState;

// Initialize state to OpenGL defaults
void glstate_init(void);

// Matrix operations
void glstate_load_identity(void);
void glstate_load_matrix(const float *m);
void glstate_ortho(double left, double right, double bottom, double top, double nearVal, double farVal);
void glstate_push_matrix(void);
void glstate_pop_matrix(void);
float* glstate_current_matrix(void); // returns pointer to top of active stack
void glstate_invalidate_mvp(void);
const float* glstate_get_mvp(void); // recomputes if dirty

// Immediate mode
void glstate_begin(uint32_t mode);
void glstate_end(void); // returns collected vertices for Metal submission
void glstate_vertex2f(float x, float y);
void glstate_vertex3f(float x, float y, float z);
void glstate_texcoord2f(float s, float t);
void glstate_color4f(float r, float g, float b, float a);
void glstate_color4ub(uint8_t r, uint8_t g, uint8_t b, uint8_t a);

#endif // PSTMETAL_GL_STATE_H
