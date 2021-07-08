#ifndef CUSTOM_UNLIT_PASS
#define CUSTOM_UNLIT_PASS

Texture2D _CameraDepthTexture;
Texture2D _CameraColorTexture;

struct Attributes
{
    float3 positionOS : POSITION;
#if defined(_VERTEX_COLORS)
    float4 uv : TEXCOORD0;
    float flipbookBlend : TEXCOORD1;
#else 
    float2 uv : TEXCOORD0;
#endif
    float4 color : COLOR;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};
struct Varyings
{
    float4 positionCS : SV_POSITION;
    float3 positionVS : VAR_POSITION;
    float2 uv : TEXCOORD0;
    #if defined(_VERTEX_COLORS)
		float4 color : VAR_COLOR;
	#endif
    #if defined(_FLIPBOOK_BLENDING)
		float3 flipbookUVB : VAR_FLIPBOOK;
	#endif
	UNITY_VERTEX_INPUT_INSTANCE_ID
};



Varyings UnlitPassVertex(Attributes input)
{
    Varyings output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input,output);
    float3 positionWS = TransformObjectToWorld(input.positionOS);
    #if defined(_VERTEX_COLORS)
		output.color = input.color;
	#endif
    output.positionCS = TransformWorldToHClip(positionWS);
    output.positionVS = TransformWorldToView(positionWS);
    output.uv.xy = TransformBaseUV(input.uv.xy);
    #if defined(_FLIPBOOK_BLENDING)
		output.flipbookUVB.xy = TransformBaseUV(input.uv.zw);
		output.flipbookUVB.z = input.flipbookBlend;
	#endif
    return output;
}

float4 GetBufferColor(float2 screenUV, float2 uvOffset = float2(0.0, 0.0))
{
    float2 uv = screenUV + uvOffset;
    return SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_linear_clamp, uv);
}

float2 GetDistortion(float2 baseUV, bool flipbookBlending, float3 flipbookUVB)
{
    float4 rawMap = SAMPLE_TEXTURE2D(_DistortionMap, sampler_MainTex, baseUV);
    if (flipbookBlending)
    {
        rawMap = lerp(
			rawMap, SAMPLE_TEXTURE2D(_DistortionMap, sampler_MainTex, flipbookUVB.xy),
			flipbookUVB.z
		);
    }
    return DecodeNormal(rawMap, UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _DistortionStrength)).xy;
}

float4 UnlitPassFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    float4 vcolor = 1.0;
    float3 flipbookUVB = 0.0;
    bool flipbookBlending = false;
    bool nearFade = false;
    bool softParticles = false;
    float2 screenUV = input.positionCS / _ScreenParams.xy;
    float4 col = GetBaseMap(input.uv);
 
    #if defined(_FLIPBOOK_BLENDING)
		flipbookUVB = input.flipbookUVB;
		flipbookBlending = true;
	#endif
    #ifdef _CLIPPING
        clip(col.a-GetCutoff(input.uv));
    #endif
    #if defined(_VERTEX_COLORS)
		vcolor = input.color;
	#endif
    #if defined(_NEAR_FADE)
        nearFade = true;
    #endif
    #if defined(_SOFT_PARTICLES)
        softParticles = true;   
    #endif 
    float4 base = GetBaseColor(input.uv) * col *vcolor;
    #if defined(_DISTORTION)
		float2 distortion = GetDistortion(input.uv,flipbookBlending,flipbookUVB) * base.a;
		base.rgb = lerp(
			GetBufferColor(screenUV, distortion).rgb, base.rgb,
			saturate(base.a - UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_DistortionBlend))
		);
	#endif
    if (flipbookBlending)
    {
        col = lerp(col, GetBaseMap(flipbookUVB.xy),
			flipbookUVB.z);
    }
    if (nearFade)
    {
        float nearAttenuation = (abs(input.positionVS.z) - UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _NearFadeDistance)) /
			UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _NearFadeRange);
        col.a *= saturate(nearAttenuation);
    }
    if(softParticles)
    {
        //in viewspace, camera face -z axis dir,positionVS.z is negative.
        float particlesVSDepth = input.positionVS.z;
        
        float bufferDepth = _CameraDepthTexture.Sample(sampler_point_clamp, screenUV).r;
        float bufferVSDepth = IsOrthographicCamera() ?
		OrthographicDepthBufferToLinear(bufferDepth) :
		LinearEyeDepth(bufferDepth, _ZBufferParams);
        //if (input.positionCS.x < 800)
        //    return float4(1.0, 0.0, 0.0, 1.0);
        float depthDelta = bufferVSDepth - abs(particlesVSDepth);
        float nearAttenuation = (depthDelta - UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _SoftParticlesDistance)) /
			UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_SoftParticlesRange);
        col.a *= saturate(nearAttenuation);
    }
    //return col * GetBaseColor(input.uv) * vcolor;
    return base;
}
#endif
