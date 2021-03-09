#ifndef CUSTOM_LIGHT_INCLUDED
#define CUSTOM_LIGHT_INCLUDED

#include "UnityInput.hlsl"

struct Light
{
    float3 direction;
    float3 color;
};

Light GetDirectionalLight(int index)
{
    Light light;
    light.color = _DirectionalLightColors[index].rgb;
    light.direction = _DirectionalLightDirections[index].xyz;
    
    return light;
}
#endif