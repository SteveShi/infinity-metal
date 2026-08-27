#include "gl_state.h"
#include <string.h>
#include <math.h>

// Global state instance
GLState g_glState;

// Common OpenGL constants
#define GL_TRIANGLES 0x0004
#define GL_QUADS     0x0007
#define GL_MODELVIEW 0x1700
#define GL_PROJECTION 0x1701

// Helper function: multiply two 4x4 column-major matrices
// out = a * b
static void multiply_matrix(float* out, const float* a, const float* b) {
    float temp[16];
    for (int c = 0; c < 4; ++c) { // column of b
        for (int r = 0; r < 4; ++r) { // row of a
            temp[c * 4 + r] = a[0 * 4 + r] * b[c * 4 + 0] +
                              a[1 * 4 + r] * b[c * 4 + 1] +
                              a[2 * 4 + r] * b[c * 4 + 2] +
                              a[3 * 4 + r] * b[c * 4 + 3];
        }
    }
    memcpy(out, temp, sizeof(temp));
}

void glstate_init(void) {
    memset(&g_glState, 0, sizeof(GLState));
    
    // Default matrix mode is modelview
    g_glState.matrixMode = GL_MODELVIEW;
    
    // Initialize matrices to identity
    for (int i = 0; i < MAX_MATRIX_STACK_DEPTH; i++) {
        for (int j = 0; j < 16; j++) {
            g_glState.modelview.matrices[i][j] = (j % 5 == 0) ? 1.0f : 0.0f;
            if (i < 2) { // Projection stack is usually smaller but array is same size
                g_glState.projection.matrices[i][j] = (j % 5 == 0) ? 1.0f : 0.0f;
            }
        }
    }
    g_glState.modelview.top = 0;
    g_glState.projection.top = 0;
    
    // Default clear color (black)
    g_glState.clearColor[0] = 0.0f;
    g_glState.clearColor[1] = 0.0f;
    g_glState.clearColor[2] = 0.0f;
    g_glState.clearColor[3] = 0.0f;
    
    // Disable blend by default
    g_glState.blend.enabled = false;
    
    // Default viewport (usually updated by app)
    g_glState.viewport.x = 0;
    g_glState.viewport.y = 0;
    g_glState.viewport.width = 0;
    g_glState.viewport.height = 0;
    
    // Default immediate mode state
    g_glState.immediate.currentColor[0] = 1.0f;
    g_glState.immediate.currentColor[1] = 1.0f;
    g_glState.immediate.currentColor[2] = 1.0f;
    g_glState.immediate.currentColor[3] = 1.0f;
    
    g_glState.immediate.currentTexCoord[0] = 0.0f;
    g_glState.immediate.currentTexCoord[1] = 0.0f;
    
    // Default unpack alignment
    g_glState.pixelStoreUnpackAlignment = 4;
    
    // Depth buffer writes enabled by default
    g_glState.depthMask = true;
    
    // Invalidate MVP
    glstate_invalidate_mvp();
}

float* glstate_current_matrix(void) {
    if (g_glState.matrixMode == GL_PROJECTION) {
        return g_glState.projection.matrices[g_glState.projection.top];
    } else {
        return g_glState.modelview.matrices[g_glState.modelview.top];
    }
}

void glstate_load_identity(void) {
    float* m = glstate_current_matrix();
    for (int i = 0; i < 16; i++) {
        m[i] = (i % 5 == 0) ? 1.0f : 0.0f;
    }
    glstate_invalidate_mvp();
}

void glstate_load_matrix(const float *m) {
    float* current = glstate_current_matrix();
    memcpy(current, m, 16 * sizeof(float));
    glstate_invalidate_mvp();
}

void glstate_ortho(double left, double right, double bottom, double top, double nearVal, double farVal) {
    float ortho[16] = {0};
    
    ortho[0] = (float)(2.0 / (right - left));
    ortho[5] = (float)(2.0 / (top - bottom));
    ortho[10] = (float)(-2.0 / (farVal - nearVal));
    ortho[12] = (float)(-(right + left) / (right - left));
    ortho[13] = (float)(-(top + bottom) / (top - bottom));
    ortho[14] = (float)(-(farVal + nearVal) / (farVal - nearVal));
    ortho[15] = 1.0f;
    
    float* current = glstate_current_matrix();
    multiply_matrix(current, current, ortho);
    glstate_invalidate_mvp();
}

void glstate_push_matrix(void) {
    if (g_glState.matrixMode == GL_PROJECTION) {
        if (g_glState.projection.top < MAX_MATRIX_STACK_DEPTH - 1) {
            memcpy(g_glState.projection.matrices[g_glState.projection.top + 1],
                   g_glState.projection.matrices[g_glState.projection.top],
                   16 * sizeof(float));
            g_glState.projection.top++;
        }
    } else {
        if (g_glState.modelview.top < MAX_MATRIX_STACK_DEPTH - 1) {
            memcpy(g_glState.modelview.matrices[g_glState.modelview.top + 1],
                   g_glState.modelview.matrices[g_glState.modelview.top],
                   16 * sizeof(float));
            g_glState.modelview.top++;
        }
    }
}

void glstate_pop_matrix(void) {
    if (g_glState.matrixMode == GL_PROJECTION) {
        if (g_glState.projection.top > 0) {
            g_glState.projection.top--;
            glstate_invalidate_mvp();
        }
    } else {
        if (g_glState.modelview.top > 0) {
            g_glState.modelview.top--;
            glstate_invalidate_mvp();
        }
    }
}

void glstate_invalidate_mvp(void) {
    g_glState.mvpDirty = true;
}

const float* glstate_get_mvp(void) {
    if (g_glState.mvpDirty) {
        // MVP = Projection * ModelView
        multiply_matrix(g_glState.mvp,
                        g_glState.projection.matrices[g_glState.projection.top],
                        g_glState.modelview.matrices[g_glState.modelview.top]);
        g_glState.mvpDirty = false;
    }
    return g_glState.mvp;
}

void glstate_begin(uint32_t mode) {
    g_glState.immediate.active = true;
    g_glState.immediate.mode = mode;
    g_glState.immediate.vertexCount = 0;
}

void glstate_end(void) {
    g_glState.immediate.active = false;
    
    // Metal does not support quads, so triangulate them.
    if (g_glState.immediate.mode == GL_QUADS) {
        int quadCount = g_glState.immediate.vertexCount / 4;
        int triVertexCount = quadCount * 6;
        
        if (triVertexCount > MAX_IMMEDIATE_VERTICES) {
            triVertexCount = MAX_IMMEDIATE_VERTICES;
            quadCount = MAX_IMMEDIATE_VERTICES / 6;
        }
        
        // Convert quads to triangles in-place.
        // We work backwards to avoid overwriting unprocessed vertices.
        for (int i = quadCount - 1; i >= 0; i--) {
            int qIdx = i * 4;
            int tIdx = i * 6;
            
            PSTVertex2D v0 = g_glState.immediate.vertices[qIdx + 0];
            PSTVertex2D v1 = g_glState.immediate.vertices[qIdx + 1];
            PSTVertex2D v2 = g_glState.immediate.vertices[qIdx + 2];
            PSTVertex2D v3 = g_glState.immediate.vertices[qIdx + 3];
            
            // First triangle: 0, 1, 2
            g_glState.immediate.vertices[tIdx + 0] = v0;
            g_glState.immediate.vertices[tIdx + 1] = v1;
            g_glState.immediate.vertices[tIdx + 2] = v2;
            
            // Second triangle: 0, 2, 3
            g_glState.immediate.vertices[tIdx + 3] = v0;
            g_glState.immediate.vertices[tIdx + 4] = v2;
            g_glState.immediate.vertices[tIdx + 5] = v3;
        }
        
        g_glState.immediate.vertexCount = triVertexCount;
        g_glState.immediate.mode = GL_TRIANGLES;
    }
}

void glstate_vertex2f(float x, float y) {
    if (g_glState.immediate.vertexCount < MAX_IMMEDIATE_VERTICES) {
        PSTVertex2D* v = &g_glState.immediate.vertices[g_glState.immediate.vertexCount++];
        v->position[0] = x;
        v->position[1] = y;
        
        v->texCoord[0] = g_glState.immediate.currentTexCoord[0];
        v->texCoord[1] = g_glState.immediate.currentTexCoord[1];
        
        v->color[0] = g_glState.immediate.currentColor[0];
        v->color[1] = g_glState.immediate.currentColor[1];
        v->color[2] = g_glState.immediate.currentColor[2];
        v->color[3] = g_glState.immediate.currentColor[3];
    }
}

void glstate_vertex3f(float x, float y, float z) {
    // For PSTEE 2D rendering we can largely ignore Z, but if needed,
    // this would be modified to support full 3D.
    (void)z;
    glstate_vertex2f(x, y);
}

void glstate_texcoord2f(float s, float t) {
    g_glState.immediate.currentTexCoord[0] = s;
    g_glState.immediate.currentTexCoord[1] = t;
}

void glstate_color4f(float r, float g, float b, float a) {
    g_glState.immediate.currentColor[0] = r;
    g_glState.immediate.currentColor[1] = g;
    g_glState.immediate.currentColor[2] = b;
    g_glState.immediate.currentColor[3] = a;
}

void glstate_color4ub(uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
    glstate_color4f(r / 255.0f, g / 255.0f, b / 255.0f, a / 255.0f);
}
