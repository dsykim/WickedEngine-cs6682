#include "globals.hlsli"
#include "ShaderInterop_Postprocess.h"

struct Constants {
    // Sampling radius per quadrant. Higher = more painterly, but more expensive.
    int radius;
};
PUSHCONSTANT(c, Constants);

Texture2D<float4> input : register(t0);
RWTexture2D<float4> output : register(u0);

float luminance(float3 col)
{
    return dot(col, float3(0.299, 0.587, 0.114));
}

void SampleQuadrant(int2 coord, int2 dims, int stepX, int stepY,
                    out float3 meanCol, out float variance)
{
    float3 sum = 0;
    float sumSq = 0;
    float count = 0;

    for (int dy = 0; dy <= c.radius; ++dy)
    {
        for (int dx = 0; dx <= c.radius; ++dx)
        {
            int2 s = clamp(coord + int2(dx * stepX, dy * stepY),
                           int2(0, 0), dims - 1);
            float3 col = input[s].rgb;
            float  l   = luminance(col);
            sum   += col;
            sumSq += l * l;
            count += 1.0;
        }
    }

    meanCol = sum / count;
    float meanLum = luminance(meanCol);
    variance = (sumSq / count) - (meanLum * meanLum);
}

[numthreads(POSTPROCESS_BLOCKSIZE, POSTPROCESS_BLOCKSIZE, 1)]
void main(uint3 id : SV_DispatchThreadID)
{
    uint2 dims;
    output.GetDimensions(dims.x, dims.y);
    if (id.x >= dims.x || id.y >= dims.y) return;

    int2 coord  = int2(id.xy);
    int  radius = max(1, c.radius);

    // Sample overlapping quadrants
    float3 meanCol[4];
    float  variance[4];
    SampleQuadrant(coord, int2(dims), +1, +1, meanCol[0], variance[0]);
    SampleQuadrant(coord, int2(dims), -1, +1, meanCol[1], variance[1]);
    SampleQuadrant(coord, int2(dims), +1, -1, meanCol[2], variance[2]);
    SampleQuadrant(coord, int2(dims), -1, -1, meanCol[3], variance[3]);

    // Pick the quadrant with the least variance for the output colour.
    float3 result = meanCol[0];
    float minVar = variance[0];

    [unroll]
    for (int i = 1; i < 4; ++i)
    {
        if (variance[i] < minVar)
        {
            minVar = variance[i];
            result = meanCol[i];
        }
    }

    output[id.xy] = float4(result, input[coord].a);
}