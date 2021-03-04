#ifndef CUSTOM_UNLIT_PASS
#define CUSTOM_UNLIT_PASS
#include "../ShaderLibrary/Common.hlsl"
float4 UnlitPassVertex(float3 positionOS : POSITION) : SV_Position
{
    float3 positionWS = TransformObjectToWorld(positionOS);
    return TransformWorldToHClip(positionWS);
}

float4 UnlitPassFragment() : SV_Target
{
    return 0.0;
}
#endif
