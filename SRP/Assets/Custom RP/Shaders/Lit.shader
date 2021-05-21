Shader "MySRP/Lit"
{
   
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color("main color",COLOR) = (0.5,0.5,0.5,1.0)
        _Metallic("metallic",Range(0,1)) = 0.1
        _Roughness("roughness",Range(0,1)) =0.5
        _IndirectSpecular("indirect GI",Range(0,1)) = 0.5
        [Toggle(_MASK_MAP)] _MaskMapToggle ("Mask Map", Float) = 0
        [NoScaleOffset] _MaskMap("Mask(MODS)",2D) = "white" {}

		[HDR] _EmissionColor("Emission", Color) = (0.0, 0.0, 0.0, 0.0)
        [NoScaleOffset] _EmissionMap("Emission", 2D) = "white" {}

        [Toggle(_DETAIL_MAP)] _DetailMapToggle("Detail map",float) = 0
        _DetailMap("Details", 2D) = "linearGrey" {}

        [Toggle(_NORMAL_MAP)] _NormalMapToggle("Normal map",float) = 0
        [NoScaleOffset] _NormalMap("Normals", 2D) = "bump" {}
        _NormalScale("Normal Scale", Range(0, 1)) = 1
        [NoScaleOffset] _DetailNormalMap("details", 2D) = "bump" {}
        _DetailNormalScale("Detail Normal Scale", Range(0, 1)) = 1

        [Enum(UnityEngine.Rendering.BlendMode)]_SrcBlend ("Src Blend", Float) = 1
		[Enum(UnityEngine.Rendering.BlendMode)]_DstBlend ("Dst Blend", Float) = 0
        [Enum(Off, 0, On, 1)] _ZWrite ("Z Write", Float) = 1
        [Toggle(_CLIPPING)] _Clipping("alpha clipping",Float) = 0
        _CutOff("alpha cut off",Float) = 0.0

        [KeywordEnum(On, Clip, Dither, Off)] _Shadows ("Shadows", Float) = 0
        [Toggle(_PREMULTI_ALPHA)] _PremultiAlpha("premultiply alpha",float) = 0
        [Toggle(_RECEIVE_SHADOWS)] _ReceiveShadows ("Receive Shadows", Float) = 1
        [Toggle(_SHADOWS_PCSS)] _pcss("open PCSS",float) = 1
        
    }
    CustomEditor "CustomShaderGUI"
    SubShader
    {
        HLSLINCLUDE
        #include "../ShaderLibrary/Common.hlsl"
        #include "../ShaderLibrary/LitInput.hlsl"
        ENDHLSL
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
            #pragma shader_feature _NORMAL_MAP
            #pragma shader_feature _DETAIL_MAP
            #pragma shader_feature _MASK_MAP
            #pragma multi_compile _ _CASCADE_BLEND_SOFT _CASCADE_BLEND_DITHER
            #pragma multi_compile _ _DIRECTIONAL_PCF3 _DIRECTIONAL_PCF5 _DIRECTIONAL_PCF7
            #pragma multi_compile _ _OTHER_PCF3 _OTHER_PCF5 _OTHER_PCF7
            #pragma multi_compile _ _SHADOW_MASK_ALWAYS _SHADOW_MASK_DISTANCE
			#pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ _LIGHTS_PER_OBJECT
            #pragma multi_compile _ LOD_FADE_CROSSFADE
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
            #pragma shader_feature _SHADOWS_CLIP _SHADOWS_DITHER
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma multi_compile_instancing
			#pragma vertex ShadowCasterPassVertex
			#pragma fragment ShadowCasterPassFragment
			#include "ShadowCasterPass.hlsl"
			ENDHLSL
        }

        Pass
        {
        Tags { "LightMode" = "Meta"}
        Cull Off

			HLSLPROGRAM
			#pragma target 3.5
			#pragma vertex MetaPassVertex
			#pragma fragment MetaPassFragment
			#include "MetaPass.hlsl"
			ENDHLSL
        }
    }

  
}
