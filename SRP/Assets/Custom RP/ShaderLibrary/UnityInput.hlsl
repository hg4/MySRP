#ifndef CUSTOM_UNITY_INPUT
#define CUSTOM_UNITY_INPUT
#include "GI.hlsl"

#define MAX_DIRECTIONAL_LIGHT_COUNT 4
#define MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT 4
#define MAX_CASCADE_COUNT 4
//declare my shader properties in constant buffer

CBUFFER_START(UnityPerDraw)
float4x4 unity_ObjectToWorld;
float4x4 unity_WorldToObject;
float4 unity_LODFade;
float4 unity_WorldTransformParams;
float4 unity_LightmapST;
float4 unity_DynamicLightmapST;
CBUFFER_END

float3 _WorldSpaceCameraPos;
TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex);
TEXTURE2D_SHADOW(_DirectionalShadowAtlas);
#define SHADOW_SAMPLER linear_clamp
SAMPLER(SHADOW_SAMPLER);


CBUFFER_START(Shadows)
int _CascadeCount;

float4 _ShadowDistanceFade;
float4 _ShadowAtlasSize;
float4 _CascadeData[MAX_CASCADE_COUNT];
float4 _CascadeCullingSpheres[MAX_CASCADE_COUNT];
float4x4 _DirectionalShadowViewMatrices[MAX_CASCADE_COUNT * MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT];
float4x4 _DirectionalShadowMatrices[MAX_CASCADE_COUNT * MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT];
CBUFFER_END



CBUFFER_START(Lighting)//any name is ok,
int _DirectionalLightCount;
float _ShadowDistance;
float3 _DirectionalLightColors[MAX_DIRECTIONAL_LIGHT_COUNT];
float3 _DirectionalLightDirections[MAX_DIRECTIONAL_LIGHT_COUNT];
float3 _DirectionalLightShadowData[MAX_DIRECTIONAL_LIGHT_COUNT];
CBUFFER_END

UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
    UNITY_DEFINE_INSTANCED_PROP(float4, _MainTex_ST)
    UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
    UNITY_DEFINE_INSTANCED_PROP(float, _CutOff)
    UNITY_DEFINE_INSTANCED_PROP(float,_Metallic)
    UNITY_DEFINE_INSTANCED_PROP(float,_Roughness)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

float4x4 unity_MatrixVP;
float4x4 unity_MatrixV;
float4x4 glstate_matrix_projection;

struct Attributes
{
    float3 positionOS : POSITION;
    float2 uv : TEXCOORD0;
    float3 normalOS : NORMAL;
    GI_ATTRIBUTE_DATA
    UNITY_VERTEX_INPUT_INSTANCE_ID
};
struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    float3 normalWS : TEXCOORD2;
    GI_VARYINGS_DATA
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

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
#endif