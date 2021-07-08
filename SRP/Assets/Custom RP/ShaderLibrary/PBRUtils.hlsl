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
void PbrBRDF(float3 N,float3 L, Surface surface,
            inout float3 diffuse, inout float3 specular)
{
    float3 V = surface.V;
    float roughness = surface.roughness;
    float metallic = surface.metallic;
    float3 albedo = surface.color;
    float NdotL = saturate(dot(N, L));
    float NdotV = saturate(dot(N, V));

    
    float3 H = normalize(L + V);
    float NdotH = saturate(dot(N, H));
    float3 R = reflect(-V, N);
    float HdotV = saturate(dot(H, V));
    float NDF = D_GTR2(NdotH, roughness);
    float G = GeometrySmith(N, V, L, roughness);
    float3 F = float3(0.04, 0.04, 0.04);
    F = lerp(F, albedo, metallic);
    F = Fresnel_Schlick(HdotV, F);
    float3 ks = F;
    float3 kd = (1 - metallic) * (1 - F);
    float denominator = 4.0 * NdotV * NdotL;
    float3 spec = NDF * G * F / (denominator + 0.001);
    float3 prefilteredColor = GetPrefilterMap(R);
    float2 envBRDF = GetBrdfLUT(float2(NdotV, roughness));
    float3 irradiance = GetIrradianceMap(N);
    float3 diffuseEnv = GetDiffuseEnvScale() * kd * irradiance * 3.1415926;
    float3 specularEnv = metallic * prefilteredColor * (F * envBRDF.x + envBRDF.y);
    diffuse = diffuseEnv;
    specular = (spec + specularEnv) * GetSpecularEnvScale();
    //specular = specular / (specular + 1);

}
#endif