#ifndef CUSTOM_SURFACE_INCLUDED
#define CUSTOM_SURFACE_INCLUDED
//surface class defination and function
#define F0 0.04

struct Surface
{
    float3 positionWS;
    float3 positionVS;
    float3 positionCS;
    float2 positionSS;
    float3 normal;
    float3 originNormal;
    float3 color;
    float3 V;
    float depth;
    float dither;
    float alpha;
    float2 screenUV;
    float roughness;
    float metallic;
    float ao;
#ifdef _FACE_LIGHT_MAP
    float lightmapMask;
#endif
#ifdef _AO_LIGHT_MAP
    float aoMask;
#endif 
#ifdef _HIGHLIGHT_MASK
    float highlightMask;
#endif
};
struct BRDF
{
    float3 diffuse;
    float3 specular;
};

float3 IndirectBRDF(Surface surface,BRDF brdf,float3 diffuse,float3 specular)
{
    float3 V = surface.V;
    float3 N = surface.normal;
    float NdotV = saturate(dot(N, V));
    float2 envBRDF = GetBrdfLUT(float2(NdotV, surface.roughness));
    float3 reflection = specular * (brdf.specular * envBRDF.x + envBRDF.y);
    //reflection /= surface.roughness * surface.roughness + 1.0;
    return (diffuse * brdf.diffuse *M_PI + reflection)*surface.ao;
}
#endif