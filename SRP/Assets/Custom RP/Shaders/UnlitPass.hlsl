#ifndef CUSTOM_UNLIT_PASS
#define CUSTOM_UNLIT_PASS
#include "../ShaderLibrary/Common.hlsl"




Varyings UnlitPassVertex(Attributes input)
{
    Varyings output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input,output);
    float3 positionWS = TransformObjectToWorld(input.positionOS);
    output.positionCS = TransformWorldToHClip(positionWS);
    output.uv = input.uv;
    return output;
}

float4 UnlitPassFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
    #ifdef _CLIPPING
        clip(col.a-UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_CutOff));
    #endif
    return col*UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
}
#endif
