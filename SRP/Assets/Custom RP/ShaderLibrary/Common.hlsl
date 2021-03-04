#ifndef CUSTOM_COMMON
#define CUSTOM_COMMON

#include "UnityInput.hlsl"

float3 TransformObjectToWorld(float3 positionOS)
{
    return mul(unity_ObjectToWorld, float4(positionOS, 1.0)).xyz;
}

float4 TransformWorldToHClip(float3 positionWS)
{
    return mul(unity_MatrixVP, float4(positionWS, 1.0));
}

#endif