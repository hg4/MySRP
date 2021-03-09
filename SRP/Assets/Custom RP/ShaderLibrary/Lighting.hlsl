#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED
#include "Surface.hlsl"
#include "Light.hlsl"
//lighting.hlsl is a utils class used for lighting model calculation.
float3 GetDiffuseLighting(Surface surface, Light light)
{
    return saturate(dot(surface.normal, light.direction)) * light.color;
}

float3 GetLighting(Surface surface)
{
    float3 finalColor;
    for (int i = 0; i < _DirectionalLightCount;i++)
        finalColor += GetDiffuseLighting(surface, GetDirectionalLight(i));
    return finalColor * surface.color;
}


#endif
