Shader "MySRP/Lit"
{
   
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor("main color",COLOR) = (0.5,0.5,0.5,1.0)
        _Metallic("metallic",Range(0,1)) = 0.1
        _Roughness("roughness",Range(0,1)) =0.5
        [Enum(UnityEngine.Rendering.BlendMode)]_SrcBlend ("Src Blend", Float) = 1
		[Enum(UnityEngine.Rendering.BlendMode)]_DstBlend ("Dst Blend", Float) = 0
        [Enum(Off, 0, On, 1)] _ZWrite ("Z Write", Float) = 1
        [Toggle(_CLIPPING)] _Clipping("alpha clipping",Float) = 0
        [KeywordEnum(On, Clip, Dither, Off)] _Shadows ("Shadows", Float) = 0
        [Toggle(_PREMULTI_ALPHA)] _PremultiAlpha("premultiply alpha",float) = 0
        [Toggle(_RECEIVE_SHADOWS)] _ReceiveShadows ("Receive Shadows", Float) = 1
        [Toggle(_SHADOWS_PCSS)] _pcss("open PCSS",float) = 1
        _CutOff("alpha cut off",Float) = 0.0
    }
    CustomEditor "CustomShaderGUI"
    SubShader
    {
       
        LOD 100

        Pass
        {
            Tags { "LightMode" = "CustomLit"}
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
			HLSLPROGRAM
            #pragma target 3.5
            #pragma shader_feature _CLIPPING
            #pragma shader_feature _PREMULTI_ALPHA
            #pragma shader_feature _SHADOWS_PCSS
            #pragma shader_feature _RECEIVE_SHADOWS
            #pragma multi_compile _ _CASCADE_BLEND_SOFT _CASCADE_BLEND_DITHER
            #pragma multi_compile _ _DIRECTIONAL_PCF3 _DIRECTIONAL_PCF5 _DIRECTIONAL_PCF7
            #pragma multi_compile_instancing
			#pragma vertex LitPassVertex
			#pragma fragment LitPassFragment
			#include "LitPass.hlsl"
			ENDHLSL
        }
        Pass
        {
        Tags { "LightMode" = "ShadowCaster"}

			HLSLPROGRAM
            #pragma target 3.5
            #pragma shader_feature _ _SHADOWS_CLIP _SHADOWS_DITHER
            #pragma multi_compile_instancing
			#pragma vertex ShadowCasterPassVertex
			#pragma fragment ShadowCasterPassFragment
			#include "ShadowCasterPass.hlsl"
			ENDHLSL
        }
    }

  
}
