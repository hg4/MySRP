#ifndef CUSTOM_LIGHT_INCLUDED
#define CUSTOM_LIGHT_INCLUDED

#include "Surface.hlsl"
#include "Shadows.hlsl"

CBUFFER_START(Lighting)//any name is ok,
int _DirectionalLightCount;
float _ShadowDistance;
float3 _DirectionalLightColors[MAX_DIRECTIONAL_LIGHT_COUNT];
float3 _DirectionalLightDirections[MAX_DIRECTIONAL_LIGHT_COUNT];
float3 _DirectionalLightShadowData[MAX_DIRECTIONAL_LIGHT_COUNT];
CBUFFER_END

struct Light
{
    float3 direction;
    float3 color;
    float attenuation;
};

DirectionalShadowData GetDirectionalShadowData(int lightIndex, ShadowData shadowData)
{
    DirectionalShadowData data;
    data.strength = _DirectionalLightShadowData[lightIndex].x * shadowData.strength;
    data.tileIndex = _DirectionalLightShadowData[lightIndex].y + shadowData.cascadeIndex;
    data.normalBias = _DirectionalLightShadowData[lightIndex].z;
    return data;
}

Light GetDirectionalLight(int index, Surface surface, ShadowData shadowData)
{
    Light light;
    light.color = _DirectionalLightColors[index].rgb;
    light.direction = _DirectionalLightDirections[index].xyz;
    DirectionalShadowData data = GetDirectionalShadowData(index, shadowData);
    light.attenuation = GetDirectionalShadowsAttenuation(surface, data,shadowData);
    
    return light;
}
#endif