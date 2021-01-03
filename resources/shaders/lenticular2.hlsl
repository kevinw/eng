cbuffer Lenticular_Constants : register(b0) {
    // Calibration values
    float pitch;
    float tilt;
    float center;
    int invView;
    float subp;
    float displayAspect;
    int ri;
    int bi;

    // Quilt settings
    float3 tile;
    float pad0;
    float2 viewPortion;
    float quiltAspect;
    int overscan;
    int quiltInvert;

    int debug;
}

#ifdef QUILT_TEXTURE
Texture2D      screenTex : register(t0);
#else
Texture2DArray screenTex : register(t0);
#endif
SamplerState screenTex_sampler : register(s0);

#ifdef QUILT_TEXTURE
float2 texArr(float3 uvz)
{
	// decide which section to take from based on the z.
	float z = floor(uvz.z * tile.z);
	float x = (fmod(z, tile.x) + uvz.x) / tile.x;
	float y = (floor(z / tile.x) + uvz.y) / tile.y;
	return float2(x, 1.0-y) * viewPortion.xy;
}
#else
float3 texArr(float3 uvz) {
    return float3(uvz.x, uvz.y, tile.z - uvz.z * tile.z);
}
#endif

void vs_main(in uint id: SV_VertexID,
             out float2 texcoord: TEXCOORD0,
             out float4 position: SV_Position)
{
    // Buffer/Layout-less fullscreen triangle vertex shader
    texcoord.x = (id == 2) ? 2.0 : 0.0;
    texcoord.y = (id == 1) ? 2.0 : 0.0;
    position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 1.0, 1.0);
}

void ps_main(in float2 texCoordsFromVert: TEXCOORD0, out float4 fragColor: SV_TARGET)
{
    float2 texCoords = texCoordsFromVert;
#ifdef QUILT_TEXTURE
    texCoords.y = 1.0 - texCoords.y;
#endif

	if (debug == 1)
	{
#ifdef QUILT_TEXTURE
		fragColor = screenTex.Sample(screenTex_sampler, texCoords.xy);
#else
		fragColor = screenTex.Sample(screenTex_sampler, float3(texCoords.xy, 0.0));
#endif
	}
	else
    {
		float invert = 1.0;
		if (invView + quiltInvert == 1) invert = -1.0;
		float3 nuv = float3(texCoords.xy, 0.0);
		nuv -= 0.5;
		float modx = clamp (step(quiltAspect, displayAspect) * step(float(overscan), 0.5) + step(displayAspect, quiltAspect) * step(0.5, float(overscan)), 0, 1);
        nuv.x *= 1;
		nuv.x = modx * nuv.x * displayAspect / quiltAspect + (1.0-modx) * nuv.x;
		nuv.y = modx * nuv.y + (1.0-modx) * nuv.y * quiltAspect / displayAspect; 
		nuv += 0.5;
		clip (nuv);
		clip (1.0-nuv);
		float4 rgb[3];
		for (int i=0; i < 3; i++)
		{
#ifdef QUILT_TEXTURE
			nuv.z = (texCoords.x + i * subp + texCoords.y * tilt) * pitch - center;
#else
			nuv.z = (texCoords.x + i * subp + (1.0 - texCoords.y) * tilt) * pitch - center;
#endif
			nuv.z = fmod(nuv.z + ceil(abs(nuv.z)), 1.0);
			nuv.z *= invert;

			rgb[i] = screenTex.Sample(screenTex_sampler, texArr(nuv));
		}
		fragColor = float4(rgb[ri].r, rgb[1].g, rgb[bi].b, 1.0);
	}
}
