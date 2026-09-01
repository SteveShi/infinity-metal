#include <metal_stdlib>
using namespace metal;

// ----------------------------------------------------------------------------
// Uniforms & Structures
// ----------------------------------------------------------------------------

struct VertexIn {
    float2 position  [[attribute(0)]];
    float2 texCoord  [[attribute(1)]];
    float4 color     [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float4 color;
};

struct VertexYUVOut {
    float4 position [[position]];
    float2 texCoord;
    float2 texCoordU;
    float2 texCoordV;
    float4 color;
};

struct Uniforms {
    float4 uST;              // Scale (x, y) and Translate (z, w)
    float2 uTcScale;         // Texture coordinate scale
    float4 uColorTone;       // Color tone & grayscale mix factor
    float  uSpriteBlurAmount;// Sprite blur / outline
    float  uZoomStrength;    // Zoom strength
    float  uBrightness;      // Brightness offset
    float  uGamma;           // Gamma correction factor
};

// ----------------------------------------------------------------------------
// Helpers
// ----------------------------------------------------------------------------

inline float4 SolveBrightnessContrast(float4 color, constant Uniforms &u) {
    if (u.uGamma < 0.01) return color;
    const float fBrightnessFactor = 32.0;
    const float fMinColor = 1.0 / 255.0;
    if (u.uGamma >= 2.0) {
        color.rgb = max(color.rgb, float3(fMinColor));
    }
    color.rgb = pow(max(color.rgb, float3(0.0)), float3(1.0 / u.uGamma));
    color.rgb = color.rgb * (1.0 / fBrightnessFactor + u.uBrightness) * fBrightnessFactor;
    return color;
}

// ----------------------------------------------------------------------------
// Vertex Shaders
// ----------------------------------------------------------------------------

// Universal 2D Vertex Shader (vpDraw.glsl, vpBlit.glsl)
vertex VertexOut vertex_main(VertexIn in [[stage_in]],
                             constant Uniforms &u [[buffer(1)]]) {
    VertexOut out;
    out.position.xy = in.position * u.uST.xy + u.uST.zw;
    out.position.z  = 0.0;
    out.position.w  = 1.0;
    out.texCoord    = in.texCoord * u.uTcScale;
    out.color       = in.color;
    return out;
}

// YUV Video Vertex Shader (vpYUV.glsl)
vertex VertexYUVOut vertex_yuv(VertexIn in [[stage_in]],
                               constant Uniforms &u [[buffer(1)]]) {
    VertexYUVOut out;
    out.position.xy = in.position * u.uST.xy + u.uST.zw;
    out.position.z  = 0.0;
    out.position.w  = 1.0;
    out.color       = in.color;

    float2 tc = in.texCoord * u.uTcScale;
    out.texCoord = tc;
    float t = 0.6666666 + (tc.y * 0.5);
    out.texCoordU = float2(tc.x * 0.5, t);
    out.texCoordV = float2(tc.x * 0.5 + 0.5, t);
    return out;
}

// ----------------------------------------------------------------------------
// Fragment Shaders
// ----------------------------------------------------------------------------

// 0. fpDraw.glsl - Main 2D Drawing & UI Shader
fragment float4 fragment_draw(VertexOut in [[stage_in]],
                              texture2d<float> tex [[texture(0)]],
                              sampler smp [[sampler(0)]],
                              constant Uniforms &u [[buffer(1)]]) {
    float4 texColor = tex.sample(smp, in.texCoord) * in.color;
    float grey = dot(texColor.rgb, float3(0.299, 0.587, 0.114));
    float3 tone = grey * u.uColorTone.rgb;
    float4 c = float4(mix(texColor.rgb, tone, u.uColorTone.a), texColor.a);
    return SolveBrightnessContrast(c, u);
}

// 1. fpTone.glsl - Grayscale/Monochrome on Pause / Time Stop
fragment float4 fragment_tone(VertexOut in [[stage_in]],
                              texture2d<float> tex [[texture(0)]],
                              sampler smp [[sampler(0)]],
                              constant Uniforms &u [[buffer(1)]]) {
    float4 c = tex.sample(smp, in.texCoord) * in.color;
    float grey = dot(c.rgb, float3(0.299, 0.587, 0.114));
    float3 tone = grey * u.uColorTone.rgb;
    return SolveBrightnessContrast(float4(mix(c.rgb, tone, u.uColorTone.a), c.a), u);
}

// 2. fpCatRom.glsl - Catmull-Rom Bicubic Blit
fragment float4 fragment_catrom(VertexOut in [[stage_in]],
                                texture2d<float> tex [[texture(0)]],
                                sampler smp [[sampler(0)]],
                                constant Uniforms &u [[buffer(1)]]) {
    float4 c = tex.sample(smp, in.texCoord) * in.color;
    return SolveBrightnessContrast(c, u);
}

// 3. fpYUV.glsl - Cutscene Video (Packed Single-Texture YUV 4:2:0)
constant float3 yuv_off  = float3(0.06250,  0.50000,  0.50000);
constant float3 yuv_dotR = float3(1.00000,  0.00000,  1.28033);
constant float3 yuv_dotG = float3(1.00000, -0.21482, -0.38059);
constant float3 yuv_dotB = float3(1.00000,  2.12798,  0.00000);
constant float Yextent = 0.6666666;
constant float epsilonPadding = 0.001;

inline float fracV(float y) {
    y = y / Yextent;
    y = fract(y);
    y = y * Yextent;
    y = min(y, Yextent - epsilonPadding);
    y = max(y, epsilonPadding);
    return y;
}

inline float fracUV(float y) {
    y = y - Yextent;
    y = y / (1.0 - Yextent);
    y = fract(y);
    y = y * (1.0 - Yextent);
    y = y + Yextent;
    y = min(y, 1.0 - epsilonPadding);
    y = max(y, Yextent + epsilonPadding);
    return y;
}

fragment float4 fragment_yuv(VertexYUVOut in [[stage_in]],
                             texture2d<float> tex [[texture(0)]],
                             sampler smp [[sampler(0)]],
                             constant Uniforms &u [[buffer(1)]]) {
    float2 tc = in.texCoord;
    float2 tcU = in.texCoordU;
    float2 tcV = in.texCoordV;

    tc.y  = fracV(tc.y);
    tcU.y = fracUV(tcU.y);
    tcV.y = fracUV(tcV.y);

    float3 yuv;
    yuv.r = tex.sample(smp, tc).r;
    yuv.g = tex.sample(smp, tcU).r;
    yuv.b = tex.sample(smp, tcV).r;
    yuv = yuv - yuv_off;

    float r = dot(yuv, yuv_dotR);
    float g = dot(yuv, yuv_dotG);
    float b = dot(yuv, yuv_dotB);
    return SolveBrightnessContrast(float4(r, g, b, in.color.a), u);
}

// 4. fpYUVGRY.glsl - Cutscene Video Grayscale
fragment float4 fragment_yuv_gray(VertexYUVOut in [[stage_in]],
                                  texture2d<float> tex [[texture(0)]],
                                  sampler smp [[sampler(0)]],
                                  constant Uniforms &u [[buffer(1)]]) {
    float2 tc = in.texCoord;
    tc.y = fracV(tc.y);
    float y = tex.sample(smp, tc).r;
    return SolveBrightnessContrast(float4(float3(y) * in.color.rgb, in.color.a), u);
}

// 5. fpSprite.glsl - Character / Monster Sprites
fragment float4 fragment_sprite(VertexOut in [[stage_in]],
                                texture2d<float> tex [[texture(0)]],
                                sampler smp [[sampler(0)]],
                                constant Uniforms &u [[buffer(1)]]) {
    float4 tex_color = tex.sample(smp, in.texCoord);
    return SolveBrightnessContrast(tex_color * in.color, u);
}

// 6. fpFONT.glsl - Text & Font Glyph rasterization
fragment float4 fragment_font(VertexOut in [[stage_in]],
                              texture2d<float> tex [[texture(0)]],
                              sampler smp [[sampler(0)]],
                              constant Uniforms &u [[buffer(1)]]) {
    float4 c = tex.sample(smp, in.texCoord);
    float glyphAlpha = (c.a < 0.999f) ? c.a : c.r;
    float4 fontColor = float4(in.color.rgb, in.color.a * glyphAlpha);
    return SolveBrightnessContrast(fontColor, u);
}

// 7. fpSELECT.glsl - Selection Circle & Highlight
fragment float4 fragment_select(VertexOut in [[stage_in]],
                                texture2d<float> tex [[texture(0)]],
                                sampler smp [[sampler(0)]],
                                constant Uniforms &u [[buffer(1)]]) {
    float4 texColor = tex.sample(smp, in.texCoord);
    return SolveBrightnessContrast(texColor * in.color, u);
}

// 8. fpSEAM.glsl - Map Background Tiles
fragment float4 fragment_seam(VertexOut in [[stage_in]],
                              texture2d<float> tex [[texture(0)]],
                              sampler smp [[sampler(0)]],
                              constant Uniforms &u [[buffer(1)]]) {
    float4 texColor = tex.sample(smp, in.texCoord) * in.color;
    float grey = dot(texColor.rgb, float3(0.299, 0.587, 0.114));
    float3 tone = grey * u.uColorTone.rgb;
    return SolveBrightnessContrast(float4(mix(texColor.rgb, tone, u.uColorTone.a), texColor.a), u);
}
