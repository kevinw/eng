Texture2D    color_tex         : register(t0);
SamplerState color_tex_sampler : register(s0);

/*
TODO generate this constants cbuffer from Jai? ...or vice versa?
    - arguments for generating from the shader:
        when you're "working" on the shader, you're gonna be HERE, editing shader code, and then fiddling with values in the inspector
    - arguments for generating from Jai:
        in some sense, the shader code is "less central" and "downstream" from the source of truth in Jai-land
*/
cbuffer constants : register(b0) 
{
    float4x4 projection;
    float4x4 view;
    float3 translation;
}

struct vs_in
{
    float3 position:    POS;
    float2 texcoord:    TEX;
    float4 color:       COL;
    uint   instance_id: SV_InstanceID;
};

struct vs_out
{
    float4 position: SV_POSITION;
    float2 texcoord: TEX;
    float4 color:    COL;
    uint   rendertarget_array_index: SV_RenderTargetArrayIndex;
};

vs_out vs_main(vs_in input) {
    float4x4 _view = view;
    _view[3].xyz += translation * input.instance_id;
    float4x4 vp = mul(_view, projection);

    vs_out output;
    output.position = mul(float4(input.position, 1), vp);
    output.texcoord = input.texcoord;
    output.color    = input.color;
    output.rendertarget_array_index = input.instance_id;
    return output;
}

float4 ps_main(vs_out input): SV_TARGET {
    return input.color * color_tex.Sample(color_tex_sampler, input.texcoord);
}
