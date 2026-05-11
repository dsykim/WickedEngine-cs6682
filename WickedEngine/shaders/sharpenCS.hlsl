#include "globals.hlsli"
#include "ShaderInterop_Postprocess.h"
PUSHCONSTANT(postprocess, PostProcess);

Texture2D<float4> input : register(t0);
RWTexture2D<float4> output : register(u0);

static const float g_shadingLevels = 3.0;
static const float g_outlineThickness = 3.0;
static const float g_outlineStrength = 0.4;

float luminance(float3 c)
{
	return dot(c, float3(0.299, 0.587, 0.114));
}

[numthreads(POSTPROCESS_BLOCKSIZE, POSTPROCESS_BLOCKSIZE, 1)]
void main(uint3 DTid : SV_DispatchThreadID)
{
	uint2 dims;
	output.GetDimensions(dims.x, dims.y);
	if (DTid.x >= dims.x || DTid.y >= dims.y)
		return;

	int2 coord = int2(DTid.xy);
	int r = max(1, (int) round(g_outlineThickness));
	int2 cmax = int2(dims) - 1;

    // ---- Cel shading -------------------------------------------------------
	float4 colour = input[coord];
	float lum = luminance(colour.rgb);
	float quant = floor(lum * g_shadingLevels + 0.5) / g_shadingLevels;
	float scale = (lum > 0.001) ? (quant / lum) : 0.0;
	float3 cel = saturate(colour.rgb * scale);

    // ---- Depth-based outlines ----------------------------------------------
	float d_c = texture_depth[clamp(coord, int2(0, 0), cmax)];
	float d_r = texture_depth[clamp(coord + int2(r, 0), int2(0, 0), cmax)];
	float d_l = texture_depth[clamp(coord + int2(-r, 0), int2(0, 0), cmax)];
	float d_u = texture_depth[clamp(coord + int2(0, -r), int2(0, 0), cmax)];
	float d_d = texture_depth[clamp(coord + int2(0, r), int2(0, 0), cmax)];

	float maxDiff = max(max(abs(d_c - d_r), abs(d_c - d_l)),
                          max(abs(d_c - d_u), abs(d_c - d_d)));
	float threshold = (1.0 - g_outlineStrength) * 0.01;
	bool isEdge = (maxDiff > threshold);

    // ---- Composite ---------------------------------------------------------
	output[DTid.xy] = isEdge ? float4(0, 0, 0, 1) : float4(cel, colour.a);
}
