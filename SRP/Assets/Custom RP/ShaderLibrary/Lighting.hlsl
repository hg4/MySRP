#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED
#define AMBIENT_FACTOR 0.03
#include "common.hlsl"
#include "Surface.hlsl"
#include "Shadows.hlsl"
#include "Light.hlsl"
//lighting.hlsl is a utils class used for lighting model calculation.


//get light radiance distribution for surface
float3 IncomingLight(Surface surface, Light light)
{
    return saturate(dot(surface.normal, light.direction) * light.attenuation) * light.color;
}

//get diffuse and specular base color
BRDF GetBRDF(Surface surface, bool applyAlphaToDiffuse = false)
{
    float3 F = lerp(F0, surface.color, surface.metallic);
    BRDF brdf;
    #ifdef _PREMULTI_ALPHA
        brdf.diffuse = surface.color * (1 - F) * surface.alpha;
    #else
        brdf.diffuse = surface.color * (1 - F);
    #endif
    brdf.specular = F ;
    return brdf;
}

//Minimalist CookTorrance BRDF
float SpecularStrength(Surface surface, BRDF brdf, Light light)
{
    float3 H = SafeNormalize(light.direction + surface.V);
    float nh2 = Square(saturate(dot(surface.normal, H)));
    float lh2 = Square(saturate(dot(light.direction, H)));
    float r2 = Square(surface.roughness);
    float d2 = Square(nh2 * (r2 - 1.0) + 1.00001);
    float normalization = surface.roughness * 4.0 + 2.0;
    return r2 / (d2 * max(0.1, lh2) * normalization);
}

// brdf_lit use lambert diffuse BRDF(without pi) and Minimalist CookTorrance specular BRDF
float3 BRDF_Lit(Surface surface, BRDF brdf, Light light)
{
    return SpecularStrength(surface, brdf, light) * brdf.specular + brdf.diffuse;
}
float3 GetAmbient(Surface surface)
{
    return surface.color * AMBIENT_FACTOR;
}

float3 GetLighting(Surface surface, BRDF brdf, Light light)
{
    return IncomingLight(surface, light) * BRDF_Lit(surface, brdf, light) + GetAmbient(surface);
}

float3 GetLighting(Surface surface, BRDF brdf)
{
    float3 finalColor;
    for (int i = 0; i < _DirectionalLightCount; i++)
    {
        ShadowData shadowData = GetShadowData(surface);
        Light light = GetDirectionalLight(i,surface,shadowData);
        finalColor += GetLighting(surface, brdf, light);
    }
       
    return finalColor;
}


#endif
