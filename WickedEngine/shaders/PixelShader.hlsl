//I'm gonna use and label this shader so it can be used as a model to create other shaders
//both imports necassary, first for all shaders, second since it wants to be part of the postprocess layer.
#include "globals.hlsli"
#include "ShaderInterop_Postprocess.h"

//You can define any type of struct here and I'll feed you the info you need in the Renderer dispatch! As long as you only need primatives and not anything chunky
//Actually if you only need up to 8 floats, I'd recommend not declaring a struct at all and just using the postprocess.params0 and postprocess.params1 as arrays (as each are float4).
//Thought, for only the pizel shader, I want to use a custom struct to show how it can be further customized if needed
struct Constants {
    float pixelSize;
    //total number of dimensions per channel. Controls how quantized the output is. Set to 0 or greater than 255 to diable quantization
    int paletteSize;
};
//Register your struct with me so that I can feed it to you
PUSHCONSTANT(c, Constants);

//These are your input and output buffers. If you need more, I may be able to get you them, but make sure to register them with the correct register and type! (t for texture, u for RWTexture, etc)
Texture2D<float4> input : register(t0);
RWTexture2D<float4> output : register(u0);


float quantise(float v, int count) {
    float step = 255.0/count;
    int val = round(floor(v * count + 0.5) * step);
    return val/ 255.0;
}

//Its pretty safe to just use this as it lets the engine decide how many gpu threads you'll need
[numthreads(POSTPROCESS_BLOCKSIZE, POSTPROCESS_BLOCKSIZE, 1)]
//Due to how wicked engine works, the entrance point should be called main with a uint3 id. 
void main(uint3 id : SV_DispatchThreadID) {

    //you should ALWAYS get dimensions from the output texture, instead of getting it passed in via the constants.
    uint2 dims;
    output.GetDimensions(dims.x, dims.y);
    //check if out of bounds.
    if (id.x >= dims.x || id.y >= dims.y) return;

    //this is the actual 'core' pixel shader code:
    
    //get the index of the pixel block we are in
    float ps = max(1.0, c.pixelSize);
    uint2 snapped = uint2(
        (uint)(floor(id.x / ps) * ps),
        (uint)(floor(id.y / ps) * ps)
    );
    snapped = clamp(snapped, uint2(0, 0), uint2(dims.x - 1, dims.y - 1));

    //sample the color of the output pixel using the top left corner of the pixel block we are in.
    float4 colour = input[snapped];

    //If the palette size is between 0 and 256, this means we want to quantize colors in some way. Otherwise we just continue
    if(c.paletteSize > 0 && c.paletteSize <= 255) {
        //Quantize colors, if desired
        colour.r = quantise(colour.r, c.paletteSize);
        colour.g = quantise(colour.g, c.paletteSize);
        colour.b = quantise(colour.b, c.paletteSize);
        colour.a = 1.0;
    }
        

    output[id.xy] = colour;
}
