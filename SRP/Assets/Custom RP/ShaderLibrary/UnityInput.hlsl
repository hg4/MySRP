#ifndef CUSTOM_UNITY_INPUT
#define CUSTOM_UNITY_INPUT
#define MAX_DIRECTIONAL_LIGHT_COUNT 4
//declare my shader properties in constant buffer

CBUFFER_START(UnityPerDraw)
float4x4 unity_ObjectToWorld;
float4x4 unity_WorldToObject;
float4 unity_LODFade;
float4 unity_WorldTransformParams;
CBUFFER_END

TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex);

CBUFFER_START(Lighting)//any name is ok,
int _DirectionalLightCount;
float3 _DirectionalLightColors[MAX_DIRECTIONAL_LIGHT_COUNT];
float3 _DirectionalLightDirections[MAX_DIRECTIONAL_LIGHT_COUNT];
CBUFFER_END

UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
    UNITY_DEFINE_INSTANCED_PROP(float4, _MainTex_ST)
    UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
    UNITY_DEFINE_INSTANCED_PROP(float, _CutOff)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

float4x4 unity_MatrixVP;
float4x4 unity_MatrixV;
float4x4 glstate_matrix_projection;

struct Attributes
{
    float3 positionOS : POSITION;
    float2 uv : TEXCOORD0;
    float3 normalOS : NORMAL;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};
struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 normalWS : TEXCOORD1;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};
#endif