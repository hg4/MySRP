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
    float roughness;
    float metallic;
    float ao;
};
struct BRDF
{
    float3 diffuse;
    float3 specular;
};

float3 IndirectBRDF(Surface surface,BRDF brdf,float3 diffuse,float3 specular)
{
    float3 reflection = specular * brdf.specular;
    reflection /= surface.roughness * surface.roughness + 1.0;
    return (diffuse * brdf.diffuse + reflection)*surface.ao;
}
#endif