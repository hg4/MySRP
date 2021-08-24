#ifndef CUSTOM_PBR_UTILS_INCLUDED
#define CUSTOM_PBR_UTILS_INCLUDED

float3 Fresnel_Schlick(float NdotV, float3 F)
{
    return F + (1 - F) * pow(1 - NdotV, 5);
}

float D_GTR2(float NdotH, float r)
{
    float a = r * r;
    float a2 = a * a;
    float cos2 = NdotH * NdotH;
    float den = 1.0 + (a2 - 1.0) * cos2;
    return a2 / max(3.1415926 * den * den, 0.001);
}
float DistributionGGX(float3 N, float3 H, float roughness)
{
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;

    float nom = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = 3.1415926 * denom * denom;

    return nom / denom;
}
float smithG_GGX_disney(float NdotV, float roughness)
{
    float alpha = (0.5 + roughness / 2) * (0.5 + roughness / 2);
    float a = alpha * alpha;
    float b = NdotV * NdotV;
    return 2 * NdotV / (NdotV + sqrt(a + b - a * b));
}
float GeometrySchlickGGX(float NdotV, float roughness)
{
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;

    float nom = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return nom / denom;
}
float GeometrySmith(float3 N, float3 V, float L, float alpha)
{
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx1 = GeometrySchlickGGX(NdotV, alpha);
    float ggx2 = GeometrySchlickGGX(NdotL, alpha);
    //float ggx1 = smithG_GGX_disney(NdotV, alpha);
    //float ggx2 = smithG_GGX_disney(NdotL, alpha);
    return ggx1 * ggx2;
}

#endif