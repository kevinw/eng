Texture2D color_tex            : register(t0);
SamplerState color_tex_sampler : register(s0);

cbuffer constants : register(b0)
{
    float4x4 projection;
}

struct vs_in
{
    float2 position: POS;
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
    output.position = mul(float4(input.position.x, input.position.y, 0, 1), projection);
    output.texcoord = input.texcoord;
    output.color    = input.color;
    return output;
}

float4 ps_main(vs_out input): SV_TARGET {
    return input.color * color_tex.Sample(color_tex_sampler, input.texcoord);
}
