#ifndef PSTMETAL_METALFX_UPSCALER_H
#define PSTMETAL_METALFX_UPSCALER_H

#import <Metal/Metal.h>
#import <MetalFX/MetalFX.h>

#ifdef __cplusplus
extern "C" {
#endif

// Initialize MetalFX spatial upscaler
bool metalfx_upscaler_init(id<MTLDevice> device, NSUInteger inputWidth, NSUInteger inputHeight,
                           NSUInteger outputWidth, NSUInteger outputHeight);

// Perform spatial upscale pass from input texture to output drawable texture
void metalfx_upscaler_encode(id<MTLCommandBuffer> commandBuffer,
                             id<MTLTexture> inputTexture,
                             id<MTLTexture> outputTexture);

// Check if MetalFX is supported and enabled
bool metalfx_upscaler_is_active(void);

#ifdef __cplusplus
}
#endif

#endif // PSTMETAL_METALFX_UPSCALER_H
