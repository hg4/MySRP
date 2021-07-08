Shader "MySRP/Toon"
{
    Properties
    {
        [Header(General)]
        _BaseColor("Color",Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
        [Enum(UnityEngine.Rendering.CullMode)]_CullMode("Cull Mode",float) = 2
        [Toggle(_CLIPPING)] _Clipping("alpha clipping",Float) = 0
        _Cutoff("alpha cut off",Float) = 0.5

        [Header(Outline)]
        _OutlineWidth("Outline width ",Range(0,1)) = 0.1
        _OutlineColor("Outline Color",Color) = (0,0,0,1)
        [Toggle(_ZOFFSET)]_ZOffset("use outline Z-offset",float) = 0
        _OutlineZOffsetStrength("outline Z-offset strength",Range(-1,1)) = 0 
        [NoScaleOffset]_OutlineZOffsetMask("outline Z-offset mask(black for use mask)",2D) = "black" {}
        _OutlineZOffsetMaskRemapStart("_OutlineZOffsetMaskRemapStart", Range(0,1)) = 0
        _OutlineZOffsetMaskRemapEnd("_OutlineZOffsetMaskRemapEnd", Range(0,1)) = 1
        [Header(Lighting)]
        //[Toggle(_RIM)]_EnableRim("Enable rim",float) = 1
        //_RimColor("rim color",Color) = (1,1,1,1)
        //_RimAttenuation("rim decay",Range(0.8,1.0)) = 0.9 
        [Toggle(_FACE_LIGHT_MAP)]_EnableFaceLightMap("Enable face Lightmap",float) = 0
        _LightMapTex("LightMap",2D) = "white" {}
        [Toggle(_RAMP_SHADOW)]_EnableRampShadow("Enable Ramp Shadow",float) = 0
        [NoScaleOffset]_RampTex("Ramp Texture",2D) = "white" {}
        _ShadowColor("Shadow Color",Color) = (1,1,1,1)
        _MidColor("mid ramp color",Color) = (1,1,1,1)
        _ShadowThreshold("Shadow Range",Range(0,1)) = 0.5
        _ShadowSmooth("Shadow Smooth",Range(0,1)) = 0.2
        [Toggle(_USE_PBR)]_UsePBR("Combine PBR",float) = 0
        [NoScaleOffset]_RoughnessTex("Roughness Texture",2D) = "black" {}
        [NoScaleOffset]_MetallicTex("Metallic Texture",2D) = "black" {}
        [NoScaleOffset]_IrradianceMap("irradiance cubemap for diffuse BRDF",Cube) = "_Skybox"{}
        [NoScaleOffset]_PrefilterMap("prefilter cubemap for specular BRDF",Cube) = "_Skybox"{}
        [NoScaleOffset]_BrdfLUT("LUT 2d texture",2D) = "white"{}
        _DiffuseEnvScale("diffuse scale",Range(0.0,2.0)) = 0.66
        _SpecularEnvScale("specular scale",Range(0.0,2.0)) = 1.0

        //_angle ("lightmap rotate adjustment",Range(-90,90)) =0.0
       
       // [Toggle]_EnablePBR("use pbr texture",float) = 0
       //_F0("fresnel",Vector) = (0.04,0.04,0.04)
       // _roughness("roughness",Range(0.0,1.0)) = 0.0
       //// _metallic("metallic",Range(0.0,1.0)) = 0.0
       // [NoScaleOffset]_metallic("metallic texture for pbr",2D) ="black" {}
       // _diffuseEnvScale("diffuse scale",Range(0.0,2.0)) =1.0
       // [NoScaleOffset]_irradianceMap("irradiance cubemap for diffuse BRDF",Cube) = "_Skybox"{}
       // [NoScaleOffset]_prefilterMap("prefilter cubemap for specular BRDF",Cube) = "_Skybox"{}
       // [NoScaleOffset]_brdfLUT("LUT 2d texture",2D) = "white"{}
    }
    SubShader
    {
        
        LOD 100
        HLSLINCLUDE
        #include "../ShaderLibrary/Common.hlsl"
        #include "../ShaderLibrary/ToonInput.hlsl"
        ENDHLSL
        Pass
        {
            Name "Toon"
            Tags { "LightMode" = "CustomToon"}
            Cull [_CullMode]
      
            HLSLPROGRAM
            #pragma target 3.5
            #pragma shader_feature _CLIPPING
            #pragma shader_feature _PREMULTI_ALPHA
            #pragma shader_feature _SHADOWS_PCSS
            #pragma shader_feature _RECEIVE_SHADOWS
            #pragma shader_feature _RAMP_SHADOW
            #pragma shader_feature _FACE_LIGHT_MAP
            #pragma shader_feature _RIM
            #pragma shader_feature _USE_PBR
            #pragma multi_compile _ _CASCADE_BLEND_SOFT _CASCADE_BLEND_DITHER
            #pragma multi_compile _ _DIRECTIONAL_PCF3 _DIRECTIONAL_PCF5 _DIRECTIONAL_PCF7
            #pragma multi_compile _ _OTHER_PCF3 _OTHER_PCF5 _OTHER_PCF7


            #pragma multi_compile_instancing
            #pragma vertex ToonShadingPassVertex
			#pragma fragment ToonShadingPassFragment
		    #include "ToonShadingPass.hlsl"

			ENDHLSL
        }
        Pass
        {
            Name "Outline"
            Tags { "LightMode" = "CustomOutline"}
            Cull front
            Offset 1,1
            HLSLPROGRAM
            #pragma target 3.5
            #pragma shader_feature _CLIPPING
            #pragma shader_feature _PREMULTI_ALPHA
            #pragma shader_feature _ZOFFSET
            #pragma multi_compile_instancing
            #pragma vertex OutlinePassVertex
			#pragma fragment OutlinePassFragment
		    #include "OutlinePass.hlsl"
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
            Tags { "LightMode" = "CustomGBuffer"}
            HLSLPROGRAM
            #pragma target 3.5
            #pragma multi_compile_instancing
            #pragma vertex GBufferPassVertex
			#pragma fragment GBufferPassFragment
            #include "CustomGBufferPass.hlsl"
            ENDHLSL
        }
    }
}
