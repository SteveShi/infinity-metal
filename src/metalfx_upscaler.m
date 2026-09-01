#import "metalfx_upscaler.h"
#import <Foundation/Foundation.h>

API_AVAILABLE(macos(13.0))
static id<MTLFXSpatialScaler> s_spatialScaler = nil;
static id<MTLDevice> s_device = nil;
static BOOL s_isActive = NO;
static NSUInteger s_inW = 0, s_inH = 0, s_outW = 0, s_outH = 0;

bool metalfx_upscaler_init(id<MTLDevice> device, NSUInteger inputWidth, NSUInteger inputHeight,
                           NSUInteger outputWidth, NSUInteger outputHeight) {
    s_device = device;
    
    // Check environment flag (default enabled on Apple Silicon)
    const char *envDisable = getenv("INFINITY_METALFX_DISABLE");
    if (!envDisable) envDisable = getenv("PST_METALFX_DISABLE");
    if (envDisable && strcmp(envDisable, "1") == 0) {
        NSLog(@"[InfinityMetal] MetalFX explicitly disabled via INFINITY_METALFX_DISABLE.");
        s_isActive = NO;
        return false;
    }

    if (@available(macOS 13.0, *)) {
        if (inputWidth == 0 || inputHeight == 0 || outputWidth == 0 || outputHeight == 0) {
            s_isActive = NO;
            return false;
        }

        if (inputWidth == outputWidth && inputHeight == outputHeight) {
            s_isActive = NO;
            return false;
        }

        if (![MTLFXSpatialScalerDescriptor supportsDevice:device]) {
            NSLog(@"[InfinityMetal] Device %@ does not support MTLFXSpatialScaler.", device.name);
            s_isActive = NO;
            return false;
        }

        if (s_spatialScaler && s_inW == inputWidth && s_inH == inputHeight &&
            s_outW == outputWidth && s_outH == outputHeight) {
            s_isActive = YES;
            return true;
        }

        s_inW = inputWidth;
        s_inH = inputHeight;
        s_outW = outputWidth;
        s_outH = outputHeight;

        MTLFXSpatialScalerDescriptor *desc = [[MTLFXSpatialScalerDescriptor alloc] init];
        desc.inputWidth = inputWidth;
        desc.inputHeight = inputHeight;
        desc.outputWidth = outputWidth;
        desc.outputHeight = outputHeight;
        desc.colorTextureFormat = MTLPixelFormatBGRA8Unorm;
        desc.outputTextureFormat = MTLPixelFormatBGRA8Unorm;
        desc.colorProcessingMode = MTLFXSpatialScalerColorProcessingModePerceptual;

        s_spatialScaler = [desc newSpatialScalerWithDevice:device];
        if (s_spatialScaler) {
            s_isActive = YES;
            NSLog(@"[InfinityMetal] 🚀 MetalFX Spatial Upscaler initialized: %lux%lu -> %lux%lu (%.1fx scale)",
                  (unsigned long)inputWidth, (unsigned long)inputHeight,
                  (unsigned long)outputWidth, (unsigned long)outputHeight,
                  (double)outputWidth / inputWidth);
            return true;
        } else {
            NSLog(@"[InfinityMetal] Failed to create MTLFXSpatialScaler.");
            s_isActive = NO;
            return false;
        }
    } else {
        s_isActive = NO;
        return false;
    }
}

void metalfx_upscaler_encode(id<MTLCommandBuffer> commandBuffer,
                             id<MTLTexture> inputTexture,
                             id<MTLTexture> outputTexture) {
    if (@available(macOS 13.0, *)) {
        if (!s_isActive || !s_spatialScaler || !inputTexture || !outputTexture) return;

        s_spatialScaler.colorTexture = inputTexture;
        s_spatialScaler.outputTexture = outputTexture;
        [s_spatialScaler encodeToCommandBuffer:commandBuffer];
    }
}

bool metalfx_upscaler_is_active(void) {
    return s_isActive;
}
