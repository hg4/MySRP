Shader "MySRP/Lit"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor("main color",COLOR) = (0.5,0.5,0.5,1.0)
    
        [Enum(UnityEngine.Rendering.BlendMode)]_SrcBlend ("Src Blend", Float) = 1
		[Enum(UnityEngine.Rendering.BlendMode)]_DstBlend ("Dst Blend", Float) = 0
        [Enum(Off, 0, On, 1)] _ZWrite ("Z Write", Float) = 1
        [Toggle(_CLIPPING)] _clipping("alpha clipping",Float) = 0
        _CutOff("alpha cut off",Float) = 0.0
    }
    SubShader
    {
        Tags { "LightMode" = "CustomLit"}
        LOD 100

        Pass
        {
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
			HLSLPROGRAM
            #pragma target 3.5
            #pragma shader_feature _CLIPPING
            #pragma multi_compile_instancing
			#pragma vertex LitPassVertex
			#pragma fragment LitPassFragment
			#include "LitPass.hlsl"
			ENDHLSL
        }
    }
}
