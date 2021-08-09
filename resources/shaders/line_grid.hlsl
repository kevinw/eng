// Call with context->Draw((rows + 1) * 4, 0); (Line list topology)

cbuffer constants : register(b0)
{
    float4x4 WorldViewProjection;
    uint Rows;
}

void LineGridVS(uint vid: SV_VertexID,
	out float4 color: COLOR,
	out float4 position: SV_Position)
{
    // which row ?
    uint n = vid / 2;	
    // line start or end (column coordinate)
    position.x = (vid % 2) * Rows;	
    // row coordinate (modulo needed for later flip to work)	
    position.z = n % (Rows + 1);
    position.y = 0;
    position.w = 1;
    // center around origin
    position.xz -= (Rows / 2);		
    color = float4(1,0,0,1);
    // rows or columns ? flip x and z (and also give a different color)
    if (n > Rows) {
        position.xz = position.zx;
        color = float4(0,1,0,1);
    }
    position = mul(position, WorldViewProjection);		
}

float4 LineGridPS() : SV_Target {
    return float4(1, 1, 1, 1);
}
