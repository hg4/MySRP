#ifndef CUSTOM_GBUFFER_INCLUDED
#define CUSTOM_GBUFFER_INCLUDED

float _MaterialID;
struct Attributes
{
    float3 positionOS : POSITION;
    float3 normalOS : NORMAL;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float4 normalDepth : TEXCOORD0;
    float3 positionVS : TEXCOORD1;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

Varyings GBufferPassVertex(Attributes input)
{
    Varyings output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    output.positionCS = TransformObjectToHClip(input.positionOS);
    output.normalDepth.xyz = TransformWorldToViewDir(
    TransformObjectToWorldNormal(input.normalOS));
    float3 positionWS = TransformObjectToWorld(input.positionOS);
    output.positionVS = TransformWorldToView(positionWS);
    output.normalDepth.w = output.positionCS.z * _ProjectionParams.w;
    return output;
}

float4 GBufferPassFragment(Varyings input) : SV_Target
{
    float3 normal_packed = normalize(input.normalDepth.xyz) * 0.5 + 0.5;
    return float4(normal_packed.xy, _MaterialID/255,input.positionCS.z);
}
#endif