#ifndef CUSTOM_LIT_PASS_INCLUDED
#define CUSTOM_LIT_PASS_INCLUDED
#include "../ShaderLibrary/Common.hlsl"
#include "../ShaderLibrary/Surface.hlsl"
#include "../ShaderLibrary/Lighting.hlsl"
Varyings LitPassVertex(Attributes input)
{
    Varyings output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    float3 positionWS = TransformObjectToWorld(input.positionOS);
    output.positionCS = TransformWorldToHClip(positionWS);
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    output.uv = input.uv;
    return output;
}

float4 LitPassFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    float4 col = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
    Surface surface;
    surface.normal = (normalize(input.normalWS));
    surface.color = col.rgb;
    surface.alpha = col.a;
    float3 color = GetLighting(surface);
    //float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
#ifdef _CLIPPING
        clip(col.a-UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_CutOff));
#endif
    return float4(color, surface.alpha);
}

#endif