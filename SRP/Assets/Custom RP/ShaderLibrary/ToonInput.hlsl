#ifndef TOON_INPUT_INCLUDED
#define TOON_INPUT_INCLUDED

TEXTURE2D(_MainTex);
TEXTURE2D(_RampTex);
TEXTURE2D(_RoughnessTex);
TEXTURE2D(_MetallicTex);
TEXTURE2D(_BrdfLUT);
TEXTURE2D(_LightMapTex);
TEXTURE2D(_OutlineZOffsetMask);
TEXTURECUBE(_IrradianceMap);
TEXTURECUBE(_PrefilterMap);
SAMPLER(sampler_MainTex);
SAMPLER(sampler_RampTex);
SAMPLER(sampler_OutlineZOffsetMask);
SAMPLER(sampler_LightMapTex);
SAMPLER(sampler_BrdfLUT);
SAMPLER(sampler_IrradianceMap);
SAMPLER(sampler_PrefilterMap);
UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
    UNITY_DEFINE_INSTANCED_PROP(float4, _MainTex_ST)
    UNITY_DEFINE_INSTANCED_PROP(float,_OutlineWidth)
    UNITY_DEFINE_INSTANCED_PROP(float4,_OutlineColor)
    UNITY_DEFINE_INSTANCED_PROP(float,_OutlineZOffsetStrength)
    UNITY_DEFINE_INSTANCED_PROP(float,_OutlineZOffsetMaskRemapStart)
    UNITY_DEFINE_INSTANCED_PROP(float,_OutlineZOffsetMaskRemapEnd)
    UNITY_DEFINE_INSTANCED_PROP(float4,_ShadowColor)
    UNITY_DEFINE_INSTANCED_PROP(float,_ShadowThreshold)
    UNITY_DEFINE_INSTANCED_PROP(float,_ShadowSmooth)
    UNITY_DEFINE_INSTANCED_PROP(float4,_BaseColor)
    UNITY_DEFINE_INSTANCED_PROP(float4,_MidColor)
    UNITY_DEFINE_INSTANCED_PROP(float,_Cutoff)
    UNITY_DEFINE_INSTANCED_PROP(float4,_LightMapTex_ST)
    UNITY_DEFINE_INSTANCED_PROP(float,_DiffuseEnvScale)
    UNITY_DEFINE_INSTANCED_PROP(float,_SpecularEnvScale)
    

    //UNITY_DEFINE_INSTANCED_PROP(float4,_RimColor)
    //UNITY_DEFINE_INSTANCED_PROP(float,_RimAttenuation)

UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

float GetOutlineWidth()
{
  return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_OutlineWidth);
}

float GetOutlineZOffsetStrength()
{
    return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _OutlineZOffsetStrength)*10;
}
float4 GetOutlineColor()
{
    return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _OutlineColor);
}
float GetOutlineZOffsetMaskRemapStart()
{
    return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _OutlineZOffsetMaskRemapStart);
}
float GetOutlineZOffsetMaskRemapEnd()
{
    return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _OutlineZOffsetMaskRemapEnd);
}
float GetOutlineZOffsetMask(float2 uv)
{
    return SAMPLE_TEXTURE2D_LOD(_OutlineZOffsetMask, sampler_OutlineZOffsetMask, uv, 0.0).r;
}
float4 GetShadowColor()
{
    return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _ShadowColor);
}
float4 GetBaseColor()
{
    return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
}
float4 GetMidColor()
{
    return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _MidColor);
}
float GetShadowSmooth()
{
    return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _ShadowSmooth);
}
float GetShadowThreshold()
{
    return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _ShadowThreshold);
}
float4 GetMainTex(float2 uv)
{
    return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
}
float4 GetRampTex(float ramp)   
{
    return SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(ramp,ramp));
}
float2 TransformLightMapTexUV(float2 uv)
{
    float4 LightMapTex_ST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _LightMapTex_ST);
    return uv * LightMapTex_ST.xy + LightMapTex_ST.zw;
}
float3 GetFaceLightmap(float2 uv)
{
    return SAMPLE_TEXTURE2D(_LightMapTex, sampler_LightMapTex, TransformLightMapTexUV(uv)).rgb;
    
}
float GetRoughness(float2 uv)
{
    return SAMPLE_TEXTURE2D(_RoughnessTex, sampler_MainTex, uv).r;
    
}
float GetMetallic(float2 uv)
{
    return SAMPLE_TEXTURE2D(_MetallicTex, sampler_MainTex, uv).r;    
}
float2 GetBrdfLUT(float2 uv)
{
    return SAMPLE_TEXTURE2D(_BrdfLUT, sampler_BrdfLUT, uv).rg;    
}
float3 GetIrradianceMap(float3 uvw)
{
    return SAMPLE_TEXTURECUBE(_IrradianceMap, sampler_IrradianceMap, uvw).rgb;
}
float3 GetPrefilterMap(float3 uvw)
{
    return SAMPLE_TEXTURECUBE(_PrefilterMap, sampler_PrefilterMap, uvw).rgb;
}
float GetDiffuseEnvScale()
{
    return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _DiffuseEnvScale);
    
}
float GetSpecularEnvScale()
{
    return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _SpecularEnvScale);   
}
//float4 GetRimColor()
//{
//    return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _RimColor);
//}
//float GetRimAttenuation()
//{
//    return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _RimAttenuation);
//}

#endif