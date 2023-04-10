#ifndef TOON_SHADING_PASS
#define TOON_SHADING_PASS

#include "../ShaderLibrary/Surface.hlsl"
#include "../ShaderLibrary/Shadows.hlsl"
#include "../ShaderLibrary/Light.hlsl"
#include "../ShaderLibrary/GI.hlsl"
#include "../ShaderLibrary/PBRUtils.hlsl"
#include "../ShaderLibrary/ToonLighting.hlsl"

struct Attributes
{
    float3 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 color : COLOR;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};
struct Varyings
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : VAR_POSITION;
    float3 normalWS : VAR_NORMAL;
    float4 color : VAR_COLOR;
    float2 uv : TEXCOORD0;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

Varyings ToonShadingPassVertex(Attributes input)
{
    Varyings output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);

    output.positionWS = TransformObjectToWorld(input.positionOS);
    output.positionCS = TransformWorldToHClip(output.positionWS);
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    output.color = input.color;
    output.uv = input.uv;
    return output;
}

float4 ToonShadingPassFragment(Varyings input) : SV_Target
{
    float4x4 viewMatrix = GetWorldToViewMatrix();
    float4x4 modelMatrix = GetObjectToWorldMatrix();

    float3 V = normalize(_WorldSpaceCameraPos - input.positionWS);
    //float NdotV = saturate(dot(normalize(input.normalWS), V));
    float4 col = GetMainTex(input.uv);
#ifdef _CLIPPING
    clip(col.a - _Cutoff);    
#endif
    Surface surface;
    surface.positionWS = input.positionWS;
    surface.positionVS = TransformWorldToView(input.positionWS);
    surface.positionCS = TransformWorldToHClip(input.positionWS);
    surface.positionSS = input.positionCS;
    ClipLOD(surface.positionSS, unity_LODFade.x);
    surface.color = col.rgb;
    surface.metallic = GetMetallic(input.uv);
    surface.roughness = GetRoughness(input.uv);
    //surface.roughness = 0.5;
    surface.alpha = col.a;
    surface.V = V;
    surface.screenUV = surface.positionSS / _ScreenParams.xy;
    surface.originNormal = input.normalWS;
    surface.normal = input.normalWS;
    surface.ao = 1.0;
    surface.dither = InterleavedGradientNoise(input.positionCS.xy, 0);
    surface.depth = -TransformWorldToView(input.positionWS).z;
#ifdef _FACE_LIGHT_MAP
    if(_DirectionalLightCount != 0){
        surface.lightmapMask = SampleFaceLightmap(normalize(_DirectionalLightDirections[0].xyz),input.uv);    
    }
#endif
    #ifdef _AO_LIGHT_MAP
    surface.aoMask = GetAOLightMap(input.uv).r;
    #endif
    #ifdef _HIGHLIGHT_MASK
        surface.highlightMask = GetHighlightMask(input.uv);
    #endif 
    GI gi = GetGI(GI_FRAGMENT_DATA(input), surface);
    float3 color = GetToonLighting(surface, gi ,input.color);
    //if(NdotV <0.1)
    //    return float4(1.0, 1.0, 1.0, 1.0);
    //return float4(surface.normal * 0.5 + 0.5, 1.0);
    //return input.color;
    //return float4(1, 1, 1, 1);
    return float4(color, 1.0);
    //return input.color;
}

#endif