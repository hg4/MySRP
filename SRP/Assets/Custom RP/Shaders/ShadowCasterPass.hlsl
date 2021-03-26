#ifndef SHADOW_CASTER_PASS_INCLUDED
#define SHADOW_CASTER_PASS_INCLUDED
#include "../ShaderLibrary/Common.hlsl"

Varyings_ShadowCaster ShadowCasterPassVertex(Attributes_ShadowCaster input)
{
    Varyings_ShadowCaster output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    float3 positionWS = TransformObjectToWorld(input.positionOS);
    output.positionCS = TransformWorldToHClip(positionWS);
    float4 uv_ST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _MainTex_ST);
    output.uv = input.uv*uv_ST.xy + uv_ST.zw;
    return output;
}

void ShadowCasterPassFragment(Varyings_ShadowCaster input)
{
    UNITY_SETUP_INSTANCE_ID(input);
    float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
    float4 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
    col *= baseColor;
    //float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
    #if defined(_SHADOWS_CLIP)
       clip(col.a-UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_CutOff));
    #elif defined(_SHADOWS_DITHER)
		    float dither = InterleavedGradientNoise(input.positionCS.xy, 0);
		    clip(col.a - dither);
    #endif
}

#endif