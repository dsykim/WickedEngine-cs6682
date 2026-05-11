#include "globals.hlsli"
#include "ShaderInterop_Postprocess.h"
PUSHCONSTANT(postprocess, PostProcess);

Texture2D<float4> input : register(t0);
RWTexture2D<float4> output : register(u0);

static const int PIXEL_SIZE = 8;

[numthreads(POSTPROCESS_BLOCKSIZE, POSTPROCESS_BLOCKSIZE, 1)]
void main(uint3 DTid : SV_DispatchThreadID)
{
	uint2 dims;
	output.GetDimensions(dims.x, dims.y);

	if (DTid.x >= dims.x || DTid.y >= dims.y)
		return;

    // Snap to nearest pixel block
	uint2 pixelCoord = (DTid.xy / PIXEL_SIZE) * PIXEL_SIZE;

	float4 color = input[pixelCoord];

	output[DTid.xy] = color;
}
