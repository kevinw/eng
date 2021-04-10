Texture2D    color_tex         : register(t0);
SamplerState color_tex_sampler : register(s0);


/*
TODO generate this constants cbuffer from Jai? ...or vice versa?
    - arguments for generating from the shader:
        when you're "working" on the shader, you're gonna be HERE, editing shader code, and then fiddling with values in the inspector
    - arguments for generating from Jai:
        in some sense, the shader code is "less central" and "downstream" from the source of truth in Jai-land
*/

#define ALPHA_DISCARD
#define MOUSE_PICKING
//#define IRIDESCENCE

#ifdef MOUSE_PICKING
struct ObjectIDInfo {
    uint entity_id;
    int entity_generation;

    float depth;
    float2 uv;
};

AppendStructuredBuffer<ObjectIDInfo> pick_objects : register(u1); // uav starts at one since the rendertarget counts as one
#endif

struct vs_out
{
    float4 position: SV_POSITION;
    float2 texcoord: TEX;
    float4 color:    COL;
    uint   rendertarget_array_index: SV_RenderTargetArrayIndex;

    uint entity_id:             INSTANCE_ENTITY_ID;             // https://www.braynzarsoft.net/viewtutorial/q16390-33-instancing-with-indexed-primitives
    int  entity_generation:     INSTANCE_ENTITY_GENERATION;
};

#ifdef VERT

cbuffer constants : register(b0) 
{
    float4x4 projection;
    float4x4 view;

    // LKG constants
    float viewConeSweep;
    float projModifier;
    int numViews;
}

struct vs_in
{
    float3 position:    POS;
    float2 texcoord:    TEX;
    float4 color:       COL;
    uint   instance_id: SV_InstanceID;

    uint entity_id:             INSTANCE_ENTITY_ID;
    int  entity_generation:     INSTANCE_ENTITY_GENERATION;
};

vs_out vs_main(vs_in input) {
    float4x4 _view = view;
    float4x4 _proj = projection;

    // for multiview LKG rendering, modify the view and projection matrices
    // based on which view we are rendering.
    float currentViewLerp = 0;
    if (numViews > 1)
        currentViewLerp = (float)input.instance_id / ((float)numViews - 1) - 0.5;

    // TODO: do we need a local vector here?
    // TODO: why are these -= instead of += like in the LKG examples?
    _view[3].x -= currentViewLerp * viewConeSweep;
    _proj[2].x -= currentViewLerp * projModifier;

    vs_out output;
    output.position = mul(float4(input.position, 1), mul(_view, _proj));
    output.texcoord = input.texcoord;
    output.color    = input.color;
    output.rendertarget_array_index = input.instance_id;

    output.entity_id = input.entity_id;
    output.entity_generation = input.entity_generation;

    return output;
}
#endif

#ifdef FRAG
cbuffer mousepick_constants : register(b0) {
    float2 mouse_xy;
}

#ifdef IRIDESCENCE
#include "iridescence.hlsl"
#endif

float4 ps_main(vs_out input): SV_TARGET {
    float4 col = input.color * color_tex.Sample(color_tex_sampler, input.texcoord);

#ifdef ALPHA_DISCARD
    if (col.a < 0.1) discard;
#endif

#ifdef IRIDESCENCE
    // TODO: @Perf this could probably be in the vertex shader.
    ApplyIridescence(col.rgb, input.rendertarget_array_index);
#endif

#ifdef MOUSE_PICKING
    if (distance(floor(input.position.xy), mouse_xy) <= 0.5) { // TODO: @Perf do this without a distance() call
        ObjectIDInfo obj;
        obj.entity_id         = input.entity_id;
        obj.entity_generation = input.entity_generation;
        obj.depth             = input.position.z;
        obj.uv                = input.texcoord;
        pick_objects.Append(obj);
    }
#endif

    return col;
}
#endif
