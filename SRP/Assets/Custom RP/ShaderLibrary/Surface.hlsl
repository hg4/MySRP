#ifndef CUSTOM_SURFACE_INCLUDED
#define CUSTOM_SURFACE_INCLUDED
//surface class defination and function
#define F0 0.04

struct Surface
{
    float3 positionWS;
    float3 positionVS;
    float3 positionCS;
    float3 normal;
    float3 color;
    float3 V;
    float depth;
    float dither;
    float alpha;
    float roughness;
    float metallic;
};
struct BRDF
{
    float3 diffuse;
    float3 specular;
};
#endif