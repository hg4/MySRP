#ifndef CUSTOM_LIGHT_INCLUDED
#define CUSTOM_LIGHT_INCLUDED

#include "Surface.hlsl"
#include "Shadows.hlsl"
#define MAX_DIRECTIONAL_LIGHT_COUNT 4
#define MAX_OTHER_LIGHT_COUNT 64

CBUFFER_START(Lighting)//any name is ok,
int _DirectionalLightCount;
float _ShadowDistance;
float3 _DirectionalLightColors[MAX_DIRECTIONAL_LIGHT_COUNT];
float3 _DirectionalLightDirections[MAX_DIRECTIONAL_LIGHT_COUNT];
float4 _DirectionalLightShadowData[MAX_DIRECTIONAL_LIGHT_COUNT];
int _OtherLightCount;
float3 _OtherLightColors[MAX_OTHER_LIGHT_COUNT];
float4 _OtherLightPositions[MAX_OTHER_LIGHT_COUNT];
float4 _OtherLightDirections[MAX_OTHER_LIGHT_COUNT];
float4 _OtherLightSpotAngles[MAX_OTHER_LIGHT_COUNT];
float4 _OtherLightShadowData[MAX_OTHER_LIGHT_COUNT];
CBUFFER_END

struct Light
{
    float3 direction;
    float3 color;
    float attenuation;
};
int GetOtherLightCount()
{
    return _OtherLightCount;
}
DirectionalShadowData GetDirectionalShadowData(int lightIndex, ShadowData shadowData)
{
    DirectionalShadowData data;
    data.strength = _DirectionalLightShadowData[lightIndex].x;
    data.tileIndex = _DirectionalLightShadowData[lightIndex].y + shadowData.cascadeIndex;
    data.normalBias = _DirectionalLightShadowData[lightIndex].z;
    data.shadowMaskChannel = _DirectionalLightShadowData[lightIndex].w;
    return data;
}
OtherShadowData GetOtherShadowData(int lightIndex, ShadowData shadowData)
{
    OtherShadowData data;
    data.strength = _OtherLightShadowData[lightIndex].x;
    data.shadowMaskChannel = _OtherLightShadowData[lightIndex].w;
    data.tileIndex = _OtherLightShadowData[lightIndex].y;
    data.lightPositionWS = 0.0;
    data.spotDirectionWS = 0.0;
    data.lightDirectionWS = 0.0;
    data.isPoint = _OtherLightShadowData[lightIndex].z == 1.0;
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
Light GetOtherLight(int index, Surface surface, ShadowData shadowData)
{
    Light light;
    light.color = _OtherLightColors[index].rgb;
    float3 position = _OtherLightPositions[index].xyz;
    float3 dist_vec = position - surface.positionWS;
    float r_inv_square = _OtherLightPositions[index].w;
    float3 spotDirection = _OtherLightDirections[index].xyz;
    light.direction = normalize(dist_vec);
    float dist_sqr = max(dot(dist_vec, dist_vec), 0.0001);
    float rangeAttenuation = saturate(1 - Square(dist_sqr * r_inv_square));
    float4 spotAngles = _OtherLightSpotAngles[index];
    float spotAttenuation = Square(
		saturate(dot(spotDirection, light.direction) *
		spotAngles.x + spotAngles.y)
	);
    OtherShadowData other = GetOtherShadowData(index, shadowData);
    other.lightPositionWS = position;
    other.lightDirectionWS = light.direction;
    other.spotDirectionWS = spotDirection;
    light.attenuation = GetOtherShadowsAttenuation(other,shadowData,surface) * 
    spotAttenuation * rangeAttenuation / dist_sqr;
    return light;
}
#endif