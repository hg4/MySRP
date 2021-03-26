#ifndef CUSTOM_LIGHT_INCLUDED
#define CUSTOM_LIGHT_INCLUDED

#include "UnityInput.hlsl"
#include "Shadows.hlsl"
#include "Surface.hlsl"
struct Light
{
    float3 direction;
    float3 color;
    float attenuation;
};



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