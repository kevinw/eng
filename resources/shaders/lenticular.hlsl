Texture2DArray color_tex         : register(t0);
SamplerState   color_tex_sampler : register(s0);

cbuffer Lenticular_Constants : register(b0) {
    float pitch;
    float slope;
    float center;
    float subpixelSize;
    float4 tile;
    float4 viewPortion;
    float4 aspect;
    float fringe;

    float4 _ScreenParams;
};

struct vs_in
{
    float3 position:  POS;
    float2 texcoord:  TEX;
    float4 color:     COL;
    uint   instance_id: SV_InstanceID;
};

struct vs_out
{
    float4 position:  SV_POSITION;
    float2 uv:        TEXCOORD0;
};

void vs_main(
    in uint id:          SV_VertexID,
    out float4 position: SV_Position,
    out float2 texcoord: TEXCOORD0)
{
        //Buffer/Layout-less fullscreen triangle vertex shader
        texcoord.x = (id == 2) ? 2.0 : 0.0;
        texcoord.y = (id == 1) ? 2.0 : 0.0;
        position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 1.0, 1.0);
}

float4 ps_main (vs_out i) : SV_TARGET {
    // first handle aspect
    // note: recreated this using step functions because my mac didn't like the conditionals
    // if ((aspect.x > aspect.y && aspect.z < 0.5) || (aspect.x < aspect.y && aspect.z > 0.5))
    // 	viewUV.x *= aspect.x / aspect.y;
    // else 
    // 	viewUV.y *= aspect.y / aspect.x;
    float2 viewUV = i.uv;
    viewUV -= 0.5;
    float modx = saturate(
        step(aspect.y, aspect.x) * step(aspect.z, 0.5) +
        step(aspect.x, aspect.y) * step(0.5, aspect.z));
    viewUV.x = modx * viewUV.x * aspect.x / aspect.y +
               (1.0 - modx) * viewUV.x;
    viewUV.y = modx * viewUV.y +
               (1.0 - modx) * viewUV.y * aspect.y / aspect.x;
    viewUV += 0.5;
    clip(viewUV);
    clip(-viewUV + 1.0);

    // then sample quilt
    float4 col = float4(0,0,0,1);
    [unroll]
    for (int subpixel = 0; subpixel < 3; subpixel++) {
        // determine view for this subpixel based on pitch, slope, center
        float viewLerp = i.uv.x + subpixel * subpixelSize;
        viewLerp += i.uv.y * slope;
        viewLerp *= pitch;
        viewLerp -= center;
        // make sure it's positive and between 0-1
        viewLerp = 1.0 - fmod(viewLerp + ceil(abs(viewLerp)), 1.0);
        // translate to quilt coordinates
        float view = floor(viewLerp * tile.z); // multiply by total views
#ifdef QUILT_TEXTURE
        float2 quiltCoords = float2(
            (fmod(view, tile.x) + viewUV.x) / tile.x,
            (floor(view / tile.x) + viewUV.y) / tile.y
        );
        quiltCoords *= viewPortion.xy;
        col[subpixel] = tex2D(_MainTex, quiltCoords)[subpixel];
#else
        // When using a texture array, the UV lookup is a float3 of (viewUV.x,
        // viewUV.y, and z=layer index into the array).
        float3 quiltCoords = float3(viewUV, view);
        col[subpixel] = color_tex.Sample(color_tex_sampler, quiltCoords)[subpixel];
#endif
    }

    // fringe
    // if fringe is negative, that means it's the odd pixels
    // this is so we don't have to store a separate bool for odd or even
    // so that's why we're adding ceil fringe
    // if it's positive it's like we're adding 1
    // so pixel 2 will become pixel 3 and 3 % 2 == 1
    // and so our fringe amount will be multiplied by 1 instead of 0,
    // so for a fringe of 0.2 would make the fringe amount 1 -> 0.8
    float yPixel = i.uv.y * _ScreenParams.y + ceil(fringe * 0.5);
    float fringeAmt = 1.0 - abs(fringe) * floor(fmod(yPixel, 2.0));
    col *= fringeAmt;

    //col = col *0.1 + 0.9* float4(1, 0, 1, 1);

    return col;
}
