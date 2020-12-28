//foo.bar.
// TODO: This should probably remain a Texture2D. the input for this im renderer shader isn't a multiview texture.
// i'm just happening to use it to blit ONE of the views to screen. instead, let's make a special purpose "multiview blit"
// shader for this? and then flip through them in time? and then provide multiple projection matrices to this shader instead.
// THAT is the multiview variable that makes sense here.


//Texture2DArray color_tex       : register(t0);
Texture2D color_tex            : register(t0);
SamplerState color_tex_sampler : register(s0);

cbuffer constants : register(b0)
{
    float4x4 view_projection;
}

struct vs_in
{
    float3 position: POS;
    float2 texcoord: TEX;
    float4 color:    COL;
};

struct vs_out
{
    float4 position: SV_POSITION;
    float2 texcoord: TEX;
    float4 color:    COL;
};

vs_out vs_main(vs_in input) {
    vs_out output;
    output.position = mul(float4(input.position, 1), view_projection);
    output.texcoord = input.texcoord;
    output.color    = input.color;
    return output;
}

float4 ps_main(vs_out input): SV_TARGET {
    return input.color * color_tex.Sample(color_tex_sampler, input.texcoord);
    //int layer = 0;
    //return input.color * color_tex.Sample(color_tex_sampler, float3(input.texcoord, layer));
}
