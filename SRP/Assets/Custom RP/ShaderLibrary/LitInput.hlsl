#ifndef CUSTOM_LIT_INPUT_INCLUDED
#define CUSTOM_LIT_INPUT_INCLUDED

TEXTURE2D(_MainTex);
TEXTURE2D(_EmissionMap);
TEXTURE2D(_MaskMap);
TEXTURE2D(_DetailMap);
TEXTURE2D(_NormalMap);
TEXTURE2D(_DetailNormalMap);
SAMPLER(sampler_MainTex);
SAMPLER(sampler_DetailMap);
SAMPLER(sampler_EmissionMap);
UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
    UNITY_DEFINE_INSTANCED_PROP(float4, _MainTex_ST)
    UNITY_DEFINE_INSTANCED_PROP(float4, _DetailMap_ST)
    UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
    UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
    UNITY_DEFINE_INSTANCED_PROP(float,_Metallic)
    UNITY_DEFINE_INSTANCED_PROP(float,_Roughness)   
    UNITY_DEFINE_INSTANCED_PROP(float,_IndirectSpecular)
    UNITY_DEFINE_INSTANCED_PROP(float, _NormalScale)
    UNITY_DEFINE_INSTANCED_PROP(float, _DetailNormalScale)
    UNITY_DEFINE_INSTANCED_PROP(float4, _EmissionColor)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

float2 TransformBaseUV(float2 baseUV)
{
    float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _MainTex_ST);
    return baseUV * baseST.xy + baseST.zw;
}
float2 TransformDetailUV(float2 detailUV)
{
    #if defined(_DETAIL_MAP)
        float4 detailST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _DetailMap_ST);
        return detailUV * detailST.xy + detailST.zw;
    #else
        return 0.0;
    #endif
}
float4 GetMask(float2 baseUV)
{
    #if defined(_MASK_MAP)
        return SAMPLE_TEXTURE2D(_MaskMap, sampler_MainTex, baseUV);
    #else
    return float4(1.0, 1.0, 1.0, 0.0);
    #endif
}
float4 GetDetailMap(float2 baseUV)
{
    float4 map = SAMPLE_TEXTURE2D(_DetailMap, sampler_DetailMap, baseUV);
    return map;
}
float4 GetBaseMap(float2 baseUV,float2 detailUV = 0.0)
{
    float4 map = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, baseUV);
    #if defined(_DETAIL_MAP)
        float4 detail = float4(GetDetailMap(detailUV).rrr,1.0);
        return Soft_Light(map, detail);
    #else 
        return map;
    #endif
}
float3 GetEmission(float2 baseUV)
{
    float4 map = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, baseUV);
    float4 color = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _EmissionColor);
    return map.rgb * color.rgb;
}
float4 GetBaseColor(float2 baseUV)
{
    float4 color = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Color);
    return color;
}
float GetCutoff(float2 baseUV)
{
    return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff);
}

float GetIndirectSpecular()
{
    return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _IndirectSpecular);
}

float GetMetallic(float2 baseUV)
{
    return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Metallic) * GetMask(baseUV).r;
}

float GetRoughness(float2 baseUV,float2 detailUV = 0.0)
{
    float roughness =  UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Roughness) 
    * (1-GetMask(baseUV).a);
    #if defined(_DETAIL_MAP)
        float detail = GetDetailMap(detailUV).b;
        float mask = GetMask(baseUV).b;
        return SOFT_LIGHT(roughness, detail * mask);
    #else 
        return roughness;
    #endif
}
float GetAO(float2 baseUV)
{
    return GetMask(baseUV).g;
}

float3 GetNormalTS(float2 baseUV, float2 detailUV = 0.0)
{
    float4 map = SAMPLE_TEXTURE2D(_NormalMap, sampler_MainTex, baseUV);
    float scale = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _NormalScale);
    float3 normal = DecodeNormal(map, scale);
    #if defined(_DETAIL_MAP)
        map = SAMPLE_TEXTURE2D(_DetailNormalMap, sampler_DetailMap, detailUV);
        scale = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _DetailNormalScale) * GetMask(baseUV).b;
        float3 detail = DecodeNormal(map, scale);
        normal = BlendNormalRNM(normal, detail);
    #endif
    return normal;
}
#endif