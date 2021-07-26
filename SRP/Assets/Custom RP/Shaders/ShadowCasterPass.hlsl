#ifndef SHADOW_CASTER_PASS_INCLUDED
#define SHADOW_CASTER_PASS_INCLUDED
#include "../ShaderLibrary/Common.hlsl"

struct Attributes_ShadowCaster
{
    float3 positionOS : POSITION;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};
struct Varyings_ShadowCaster
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};
bool _ShadowPancaking;
Varyings_ShadowCaster ShadowCasterPassVertex(Attributes_ShadowCaster input)
{
    Varyings_ShadowCaster output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    float3 positionWS = TransformObjectToWorld(input.positionOS);
    output.positionCS = TransformWorldToHClip(positionWS);
    float4 uv_ST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _MainTex_ST);
    if (_ShadowPancaking)
    {
        #if UNITY_REVERSED_Z
		        output.positionCS.z =
			        min(output.positionCS.z, output.positionCS.w * UNITY_NEAR_CLIP_VALUE);
        #else
                output.positionCS.z =
			        max(output.positionCS.z, output.positionCS.w * UNITY_NEAR_CLIP_VALUE);
        #endif
                output.uv = input.uv * uv_ST.xy + uv_ST.zw;
    }
    return output;
}

void ShadowCasterPassFragment(Varyings_ShadowCaster input)
{
    UNITY_SETUP_INSTANCE_ID(input);
    float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
    //float4 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Color);
    //col *= baseColor;
    //float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
    #if defined(_SHADOWS_CLIP)
               clip(col.a-UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_Cutoff));
    #elif defined(_SHADOWS_DITHER)
		            float dither = InterleavedGradientNoise(input.positionCS.xy, 0);
		            clip(col.a - dither);
    #endif
}

#endif