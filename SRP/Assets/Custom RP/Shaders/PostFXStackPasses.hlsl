#ifndef CUSTOM_POST_FX_PASSES_INCLUDED
#define CUSTOM_POST_FX_PASSES_INCLUDED
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Filtering.hlsl"
struct Attributes
{
    float3 positionOS : POSITION;
    float2 uv : TEXCOORD0;
};
    struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 screenUV : VAR_SCREEN_UV;
};

TEXTURE2D(_PostFXSource);
TEXTURE2D(_PostFXSource2);
sampler2D _CameraDepthNormalTexture;
sampler2D _CameraDepthTexture;
bool _BloomBicubicUpsampling;
float _BloomIntensity;
float4 _BloomThreshold;



float4 GetSource(float2 screenUV)
{
    return SAMPLE_TEXTURE2D(_PostFXSource, sampler_linear_clamp, screenUV);
}

float4 GetSource2(float2 screenUV)
{
    return SAMPLE_TEXTURE2D_LOD(_PostFXSource2, sampler_linear_clamp, screenUV, 0);
}
float4 _PostFXSource_TexelSize;

float4 GetSourceTexelSize()
{
    return _PostFXSource_TexelSize;
}

float4 GetSourceBicubic(float2 screenUV)
{
    return SampleTexture2DBicubic(
		TEXTURE2D_ARGS(_PostFXSource, sampler_linear_clamp), screenUV,
		_PostFXSource_TexelSize.zwxy, 1.0, 0.0
	);
}

Varyings DefaultPassVertex(Attributes input)
{
    Varyings output;
    output.positionCS = TransformObjectToHClip(input.positionOS);
    output.screenUV = input.uv;
    return output;
}

float4 BloomHorizontalPassFragment(Varyings input) : SV_TARGET
{
    float3 color = 0.0;
    float offsets[] =
    {
        -4.0, -3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0, 4.0
    };
    float weights[] =
    {
        0.01621622, 0.05405405, 0.12162162, 0.19459459, 0.22702703,
		0.19459459, 0.12162162, 0.05405405, 0.01621622
    };
    for (int i = 0; i < 9; i++)
    {
        float offset = offsets[i] * 2.0 * GetSourceTexelSize().x;
        color += GetSource(input.screenUV + float2(offset, 0.0)).rgb * weights[i];
    }
    return float4(color, 1.0);
}

float4 BloomVerticalPassFragment(Varyings input) : SV_TARGET
{
    float3 color = 0.0;
    float offsets[] =
    {
        -3.23076923, -1.38461538, 0.0, 1.38461538, 3.23076923
    };
    float weights[] =
    {
        0.07027027, 0.31621622, 0.22702703, 0.31621622, 0.07027027
    };
    for (int i = 0; i < 5; i++)
    {
        float offset = offsets[i] * GetSourceTexelSize().y;
        color += GetSource(input.screenUV + float2(0.0, offset)).rgb * weights[i];
    }
    return float4(color, 1.0);
}


float4 BloomAddPassFragment(Varyings input) : SV_TARGET
{
    float3 lowRes;
    if(_BloomBicubicUpsampling)
        lowRes = GetSourceBicubic(input.screenUV).rgb;
    else
        lowRes = GetSource(input.screenUV).rgb;
    float3 highRes = GetSource2(input.screenUV).rgb;
    return float4(lowRes * _BloomIntensity + highRes, 1.0);
}

float4 BloomScatterPassFragment(Varyings input) : SV_TARGET
{
    float3 lowRes;
    if (_BloomBicubicUpsampling)
        lowRes = GetSourceBicubic(input.screenUV).rgb;
    else
        lowRes = GetSource(input.screenUV).rgb;
    float3 highRes = GetSource2(input.screenUV).rgb;
    return float4(lerp(highRes, lowRes, _BloomIntensity), 1.0);
}


float3 ApplyBloomThreshold(float3 color)
{
    float brightness = Max3(color.r, color.g, color.b);
    float soft = brightness + _BloomThreshold.y;
    soft = clamp(soft, 0.0, _BloomThreshold.z);
    soft = soft * soft * _BloomThreshold.w;
    float contribution = max(soft, brightness - _BloomThreshold.x);
    contribution /= max(brightness, 0.00001);
    return color * contribution;
}

float4 _ColorAdjustments;
float4 _ColorFilter;
float4 _WhiteBalance;
float4 _SplitToningShadows, _SplitToningHighlights;
float4 _ColorBalanceShadows;
float4 _ColorBalanceMidtones;
float4 _ColorBalanceHighlights;

float3x3 transfer(float3 value)
{
    const float a = 64.0, b = 85.0, scale = 1.785;
    float3x3 result;
    float3 i = value * 255.0;
    float3 shadows = clamp((i - b) / -a + 0.5, 0.0, 1.0) * scale;
    float3 midtones = clamp((i - b) / a + 0.5, 0.0, 1.0) * clamp((i + b - 255.0) / -a + .5, 0.0, 1.0) * scale;
    float3 highlights = clamp(((255.0 - i) - b) / -a + 0.5, 0.0, 1.0) * scale;
    result[0] = shadows;
    result[1] = midtones;
    result[2] = highlights;
    return result;
}

float Luminance(float3 color, bool useACES)
{
    return useACES ? AcesLuminance(color) : Luminance(color);
}

float3 ColorGradeBalance(float3 color)
{
    float3 origin_hsv = RgbToHsv(color);
    float3x3 weights = transfer(color);
    color += _ColorBalanceShadows.rgb * weights[0];
    color += _ColorBalanceMidtones.rgb * weights[1];
    color += _ColorBalanceHighlights.rgb * weights[2];
    color = clamp(color, 0, 255);
    float3 balance_hsv = RgbToHsv(color/255.0);
    balance_hsv.b = origin_hsv.b;
    return HsvToRgb(balance_hsv);
}

float3 ColorGradeSplitToning(float3 color, bool useACES)
{
    color = PositivePow(color, 1.0 / 2.2);
    float t = saturate(Luminance(saturate(color), useACES) + _SplitToningShadows.w);
    float3 shadows = lerp(0.5, _SplitToningShadows.rgb, 1.0 - t);
    float3 highlights = lerp(0.5, _SplitToningHighlights.rgb, t);
    color = SoftLight(color, shadows);
    color = SoftLight(color, highlights);
    return PositivePow(color, 2.2);
}

float3 ColorGradePostExposure(float3 color)
{
    return color * _ColorAdjustments.x;
}

float3 ColorGradingContrast(float3 color, bool useACES)
{
    color = useACES ? ACES_to_ACEScc(unity_to_ACES(color)) : LinearToLogC(color);
    color = (color - ACEScc_MIDGRAY) * _ColorAdjustments.y + ACEScc_MIDGRAY;
    return useACES ? ACES_to_ACEScg(ACEScc_to_ACES(color)) : LogCToLinear(color);
}

float3 ColorGradingHueShift(float3 color)
{
    color = RgbToHsv(color);
    float hue = color.x + _ColorAdjustments.z;
    color.x = RotateHue(hue, 0.0, 1.0);
    return HsvToRgb(color);
}

float3 ColorGradingSaturation(float3 color, bool useACES)
{
    float luminance = Luminance(color,useACES);
    color = (color - luminance) * _ColorAdjustments.w + luminance;
    color = max(color, 0.0);
    return color;
}
float3 ColorGradeColorFilter(float3 color)
{
    return color * _ColorFilter.rgb;
}

float3 ColorGradeWhiteBalance(float3 color)
{
    color = LinearToLMS(color);
    color *= _WhiteBalance.rgb;
    return LMSToLinear(color);
}

float3 ColorGrade(float3 color, bool useACES = false)
{
    color = ColorGradePostExposure(color);
    color = ColorGradeBalance(color);
    color = ColorGradeWhiteBalance(color);
    color = ColorGradingContrast(color, useACES);
    color = ColorGradingHueShift(color);
    color = ColorGradingSaturation(color, useACES);
    color = ColorGradeColorFilter(color);
    color = ColorGradeSplitToning(color, useACES);
    return max(useACES ? ACEScg_to_ACES(color) : color, 0.0);
}

float4 BloomScatterFinalPassFragment(Varyings input) : SV_TARGET
{
    float3 lowRes;
    if (_BloomBicubicUpsampling)
    {
        lowRes = GetSourceBicubic(input.screenUV).rgb;
    }
    else
    {
        lowRes = GetSource(input.screenUV).rgb;
    }
    float3 highRes = GetSource2(input.screenUV).rgb;
    lowRes += highRes - ApplyBloomThreshold(highRes);
    return float4(lerp(highRes, lowRes, _BloomIntensity), 1.0);
}

float4 BloomPrefilterPassFragment(Varyings input) : SV_TARGET
{
    //auto filter by RT filterMode not here.
    float3 color = ApplyBloomThreshold(GetSource(input.screenUV).rgb);
    return float4(color, 1.0);
}

float4 BloomPrefilterFirefliesPassFragment(Varyings input) : SV_TARGET
{
    float3 color = 0.0;
    float weightSum = 0.0;
    float2 offsets[] =
    {
        float2(0.0, 0.0),
		float2(-1.0, -1.0), float2(-1.0, 1.0), float2(1.0, -1.0), float2(1.0, 1.0)
    };
    for (int i = 0; i < 5; i++)
    {
        float3 c =
			GetSource(input.screenUV + offsets[i] * GetSourceTexelSize().xy * 2.0).rgb;
        c = ApplyBloomThreshold(c);
        float w = 1.0 / (Luminance(c) + 1.0);
        color += c * w;
        weightSum += w;
    }
    color /= weightSum;
    return float4(color, 1.0);
}

float4 _ColorGradingLUTParameters;
bool _ColorGradingLUTInLogC;
float3 GetColorGradedLUT(float2 uv, bool useACES = false)
{
    float3 color = GetLutStripValue(uv, _ColorGradingLUTParameters);
    return ColorGrade(_ColorGradingLUTInLogC ? LogCToLinear(color) : color, useACES);
}

float4 ColorGradingNonePassFragment(Varyings input) : SV_TARGET
{
    float3 color = GetColorGradedLUT(input.screenUV);
    return float4(color, 1.0);
}

float4 ColorGradingACESPassFragment(Varyings input) : SV_TARGET
{
    float3 color = GetColorGradedLUT(input.screenUV, true);
    color = AcesTonemap(color);
    return float4(color, 1.0);
}

float4 ColorGradingNeutralPassFragment(Varyings input) : SV_TARGET
{
    float3 color = GetColorGradedLUT(input.screenUV);
    color = NeutralTonemap(color);
    return float4(color, 1.0);
}

float4 ColorGradingReinhardPassFragment(Varyings input) : SV_TARGET
{
    float3 color = GetColorGradedLUT(input.screenUV);
    color /= color + 1.0;
    return float4(color, 1.0);
}

TEXTURE2D(_ColorGradingLUT);

float3 ApplyColorGradingLUT(float3 color)
{
    return ApplyLut2D(
		TEXTURE2D_ARGS(_ColorGradingLUT, sampler_linear_clamp),
		saturate(_ColorGradingLUTInLogC ? LinearToLogC(color) : color),
		_ColorGradingLUTParameters.xyz
	);
}

float4 FinalPassFragment(Varyings input) : SV_TARGET
{
    float4 color = GetSource(input.screenUV);
    color.rgb = ApplyColorGradingLUT(color.rgb);
    return color;
}
float4 CopyPassFragment(Varyings input) : SV_TARGET
{
    float4 color = GetSource(input.screenUV);
    return color;
}

float4 _RimColor;
float _RimLength;
float _RimWidth;
float _RimFeather;
float _RimBlend;
#include "../ShaderLibrary/ColorBlend.hlsl"



float4 RimLightPassFragment(Varyings input) : SV_TARGET
{
    float4 color = GetSource(input.screenUV);
    float2 normalRG = tex2D(_CameraDepthNormalTexture, input.screenUV).rg;
    float id = tex2D(_CameraDepthNormalTexture, input.screenUV).b * 255;
    if(id < 200)
        return color;
    float3 normal = DecodeNormal(normalRG);
    float2 N_view = normalize(TransformWorldToViewDir(normal).xy);
    float originDepth = tex2D(_CameraDepthTexture, input.screenUV).r;
    float depth = LinearEyeDepth(originDepth, _ZBufferParams);
    
    float3 rim = float3(0.0,0.0,0.0);
    if (_DirectionalLightCount != 0)
    {
        float3 L = _DirectionalLightDirections[0];
        //float3 V = _WorldSpaceCameraPos - inputs.positionWS;
        float2 L_view = normalize(TransformWorldToViewDir(L).xy);
        float NdotL = dot(N_view,L_view) + _RimLength;
        float scale = (NdotL + 1) / 2 * _RimWidth * 0.01;
        float2 uv = clamp(input.screenUV + N_view * scale * DepthAttenuation(depth),
        0, _ScreenParams.xy / _ScreenParams.y);
        float originDepth1 = tex2D(_CameraDepthTexture, uv).r;
        float depth1 = LinearEyeDepth(originDepth1, _ZBufferParams);
        float depthDiff = depth1 - depth;
        float intensity = smoothstep(0.24 * _RimFeather * depth, 0.25 * depth, depthDiff);
        if (intensity == 0.0)
            return color;
        rim = _RimColor.rgb * intensity * _DirectionalLightColors[0].rgb;
        //rim = float3(depthDiff,0, 0);
    }
    //float depth, depth1;
    //float3 normal, normal1;
    ////DecodeDepthNormal(depthNormal, depth, normal);
    //return float4(depthNormal.r, 1);
   
    color.rgb = lerp(color.rgb, rim, _RimBlend);
    return color;
    //return float4(rim, color.a);
}


#endif