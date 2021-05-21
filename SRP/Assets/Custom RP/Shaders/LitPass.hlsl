#ifndef CUSTOM_LIT_PASS_INCLUDED
#define CUSTOM_LIT_PASS_INCLUDED

#include "../ShaderLibrary/Surface.hlsl"
#include "../ShaderLibrary/Shadows.hlsl"
#include "../ShaderLibrary/Light.hlsl"
#include "../ShaderLibrary/GI.hlsl"
#include "../ShaderLibrary/Lighting.hlsl"

struct Attributes
{
    float3 positionOS : POSITION;
    float2 uv : TEXCOORD0;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    GI_ATTRIBUTE_DATA
    UNITY_VERTEX_INPUT_INSTANCE_ID
};
struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 uv : VAR_BASE_UV;
    float2 detailUV : VAR_DETAIL_UV;
#if defined(_NORMAL_MAP)
    float4 tangentWS : VAR_TANGENT;
#endif
    float3 positionWS : TEXCOORD1;
    float3 normalWS : TEXCOORD2;
    GI_VARYINGS_DATA
	UNITY_VERTEX_INPUT_INSTANCE_ID
};
bool4 unity_MetaFragmentControl;

Varyings LitPassVertex(Attributes input)
{
    Varyings output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    TRANSFER_GI_DATA(input, output);
    output.positionWS = TransformObjectToWorld(input.positionOS);
    output.positionCS = TransformWorldToHClip(output.positionWS);
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    float4 uv_ST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _MainTex_ST);
    output.uv = TransformBaseUV(input.uv);
    output.detailUV = TransformDetailUV(input.uv);
    #if defined(_NORMAL_MAP)
        output.tangentWS = float4(TransformObjectToWorldDir(input.tangentOS.xyz),
        input.tangentOS.w);
    #endif    
    return output;
}

void ClipLOD(float2 positionSS, float fade)
{
#if defined(LOD_FADE_CROSSFADE)
// Screen-door transparency: Discard pixel if below threshold.
    float4x4 thresholdMatrix =
    {  1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0,
      13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0,
       4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0,
      16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0
    };
    float4x4 _RowAccess = { 1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1 };
    float2 pos = positionSS;
    clip(fade - thresholdMatrix[fmod(pos.x, 4)] * _RowAccess[fmod(pos.y, 4)]);
#endif
}

float4 LitPassFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
 
    float4 col = GetBaseMap(input.uv, input.detailUV);
    float4 baseColor = GetBaseColor(input.uv);
    Surface surface;
    surface.positionWS = input.positionWS;
    surface.positionVS = TransformWorldToView(input.positionWS);
    surface.positionCS = input.positionCS;
    surface.positionSS = input.positionCS.xy / input.positionCS.w * _ScreenParams.xy;
    ClipLOD(surface.positionSS, unity_LODFade.x);
    #if defined(_NORMAL_MAP)
        surface.normal = NormalTangentToWorld(
		    GetNormalTS(input.uv,input.detailUV), input.normalWS, input.tangentWS);
        surface.originNormal = normalize(input.normalWS);
    #else
        surface.normal = normalize(input.normalWS);
        surface.originNormal = surface.normal;
    #endif
    surface.color = col.rgb * baseColor.rgb;
    surface.alpha = col.a;
    surface.depth = -TransformWorldToView(input.positionWS).z;
    surface.V = normalize(_WorldSpaceCameraPos - input.positionWS);
    surface.dither = InterleavedGradientNoise(input.positionCS.xy, 0);
    surface.metallic = GetMetallic(input.uv);
    surface.roughness = PerceptualRoughnessToRoughness(GetRoughness(input.uv,input.detailUV));
    surface.ao = GetAO(input.uv);
    BRDF brdf = GetBRDF(surface);
    //return float4(brdf.specular, 1.0);
    GI gi = GetGI(GI_FRAGMENT_DATA(input),surface);
    float3 color = GetLighting(surface,brdf,gi);
    color += GetEmission(input.uv);
    //float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
#ifdef _CLIPPING
        clip(col.a-GetCutoff(input.uv));
#endif
    return float4(color, surface.alpha);
}

#endif