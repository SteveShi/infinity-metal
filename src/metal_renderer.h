#ifndef PSTMETAL_RENDERER_H
#define PSTMETAL_RENDERER_H

#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <Cocoa/Cocoa.h>
#import <OpenGL/gl.h>

#ifdef __cplusplus
extern "C" {
#endif

// Initialize the Metal rendering engine
bool metal_renderer_init(void);

// Attach CAMetalLayer to host NSView
void metal_renderer_attach_to_view(NSView *view);

// Frame lifecycle
void metal_renderer_frame_flush(void);

// GL Draw Call Execution via Metal
void metal_renderer_draw_arrays(GLenum mode, GLint first, GLsizei count);

// Viewport / Scissor / Clear
void metal_renderer_clear(GLbitfield mask);
void metal_renderer_viewport(GLint x, GLint y, GLsizei width, GLsizei height);
void metal_renderer_scissor(GLint x, GLint y, GLsizei width, GLsizei height);

// Accessors
id<MTLDevice> metal_renderer_get_device(void);

#ifdef __cplusplus
}
#endif

#endif // PSTMETAL_RENDERER_H
