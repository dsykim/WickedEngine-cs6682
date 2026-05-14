#include "globals.hlsli"
#include "ShaderInterop_Postprocess.h"


struct Constants {
    // Number of discrete brightness bands
    float shadingLevels;
    // Outline width in pixels
    float outlineThickness;
    // Edge-detection sensitivity. 0 = only strong silhouettes, 1 = almost everything is an edge
    float outlineStrength;
};

PUSHCONSTANT(c, Constants);

Texture2D<float4> input  : register(t0);
RWTexture2D<float4> output : register(u0);


//Rec. 601 luminance
float luminance(float3 col) {
    return dot(col, float3(0.299, 0.587, 0.114));
}

float quantise_luminance(float lum, float levels) {
    return floor(lum * levels + 0.5) / levels;
}

[numthreads(POSTPROCESS_BLOCKSIZE, POSTPROCESS_BLOCKSIZE, 1)]
void main(uint3 id : SV_DispatchThreadID) {
    uint2 dims;
    output.GetDimensions(dims.x, dims.y);
    if (id.x >= dims.x || id.y >= dims.y) return;

    int2 coord = int2(id.xy);
    int2 cmax  = int2(dims) - 1;

    // Cel shading
    float4 colour = input[coord];
    float  lum    = luminance(colour.rgb);
    float  quant  = quantise_luminance(lum, max(2.0, c.shadingLevels));
    float  scale  = (lum > 0.001) ? (quant / lum) : 0.0;
    float3 cel    = saturate(colour.rgb * scale);

    // outline
    int r = max(1, (int)round(c.outlineThickness));

    float d_c = texture_depth[clamp(coord,                int2(0, 0), cmax)];
    float d_r = texture_depth[clamp(coord + int2( r,  0), int2(0, 0), cmax)];
    float d_l = texture_depth[clamp(coord + int2(-r,  0), int2(0, 0), cmax)];
    float d_u = texture_depth[clamp(coord + int2( 0, -r), int2(0, 0), cmax)];
    float d_d = texture_depth[clamp(coord + int2( 0,  r), int2(0, 0), cmax)];

    float maxDiff = max(max(abs(d_c - d_r), abs(d_c - d_l)),
                        max(abs(d_c - d_u), abs(d_c - d_d)));

    float threshold = (1.0 - saturate(c.outlineStrength)) * 0.01;
    bool  isEdge    = (maxDiff > threshold);

    // Composite
    // Edge pixels go to black, everything else to the cel-shaded colour.
    output[id.xy] = isEdge ? float4(0.0, 0.0, 0.0, 1.0) : float4(cel, colour.a);
}
