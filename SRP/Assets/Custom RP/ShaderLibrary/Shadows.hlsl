#ifndef CUSTOM_SHADOWS_INCLUDED
#define CUSTOM_SHADOWS_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"


#if defined(_DIRECTIONAL_PCF3)
#define DIRECTIONAL_FILTER_SAMPLES 4
#define DIRECTIONAL_FILTER_SIZE 3
#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_3x3
#elif defined(_DIRECTIONAL_PCF5)
#define DIRECTIONAL_FILTER_SAMPLES 9
#define DIRECTIONAL_FILTER_SIZE 5
#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_5x5
#elif defined(_DIRECTIONAL_PCF7)
#define DIRECTIONAL_FILTER_SAMPLES 16
#define DIRECTIONAL_FILTER_SIZE 7
#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_7x7
#endif
#if defined(_OTHER_PCF3)
	#define OTHER_FILTER_SAMPLES 4
	#define OTHER_FILTER_SETUP SampleShadow_ComputeSamples_Tent_3x3
#elif defined(_OTHER_PCF5)
	#define OTHER_FILTER_SAMPLES 9
	#define OTHER_FILTER_SETUP SampleShadow_ComputeSamples_Tent_5x5
#elif defined(_OTHER_PCF7)
	#define OTHER_FILTER_SAMPLES 16
	#define OTHER_FILTER_SETUP SampleShadow_ComputeSamples_Tent_7x7
#endif
#define CONST_SEARCH_LENGTH 16
#define BLOCKER_SEARCH_NUM_SAMPLES 16


TEXTURE2D_SHADOW(_DirectionalShadowAtlas);
TEXTURE2D_SHADOW(_OtherShadowAtlas);
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
float4x4 _OtherShadowMatrices[MAX_SHADOWED_OTHER_LIGHT_COUNT];
float4 _OtherShadowTiles[MAX_SHADOWED_OTHER_LIGHT_COUNT];
CBUFFER_END



static const float2 poissonDisk[16] =
{
    float2(-0.94201624, -0.39906216),
         float2(0.94558609, -0.76890725),
         float2(-0.094184101, -0.92938870),
         float2(0.34495938, 0.29387760),
         float2(-0.91588581, 0.45771432),
         float2(-0.81544232, -0.87912464),
         float2(-0.38277543, 0.27676845),
         float2(0.97484398, 0.75648379),
         float2(0.44323325, -0.97511554),
         float2(0.53742981, -0.47373420),
         float2(-0.26496911, -0.41893023),
         float2(0.79197514, 0.19090188),
         float2(-0.24188840, 0.99706507),
         float2(-0.81409955, 0.91437590),
         float2(0.19984126, 0.78641367),
         float2(0.14383161, -0.14100790)
};

struct DirectionalShadowData
{
    float strength;
    int tileIndex;
    float normalBias;
    int shadowMaskChannel;
    
};
struct OtherShadowData
{
    float strength;
    int shadowMaskChannel;
    int tileIndex;
    bool isPoint;
    float3 lightPositionWS;
    float3 lightDirectionWS;
    float3 spotDirectionWS;
};
struct ShadowMask
{
    bool always;
    bool distance;
    float4 shadows;
};

/*
used for all shadow type, 
adjust strength by cascade level and distance,
and get GI shadowMask here.
*/
struct ShadowData
{
    int cascadeIndex;
    float cascadeBlend;
    float strength;
    ShadowMask shadowMask;
};

float FadedShadowStrength(float distance, float scale, float fade)
{
    return saturate((1.0 - distance * scale) * fade);
}

ShadowData GetShadowData(Surface surface)
{
    ShadowData data;
    //fade if shadow map cover beyond max distance.
    data.cascadeBlend = 1.0;
    data.strength = FadedShadowStrength(surface.depth, 
    _ShadowDistanceFade.x, _ShadowDistanceFade.y);
    data.shadowMask.distance = false;   //not use bake shadow in realtime by default.
    data.shadowMask.always = false;
    data.shadowMask.shadows = 1.0;
    int i;
    for (i = 0; i < _CascadeCount; i++)
    {
        float4 sphere = _CascadeCullingSpheres[i];
        float distanceSqr = DistanceSquared(surface.positionWS, sphere.xyz);
        if (distanceSqr < sphere.w)
        {
            //fade cascaded shadow map's boundary
            float fade = FadedShadowStrength(
					distanceSqr, _CascadeData[i].x, _ShadowDistanceFade.z);
            if (i == _CascadeCount - 1)
            {
                data.strength *= fade;
            }
            else
                data.cascadeBlend = fade;
            break;
        }
    }
    
    if (i == _CascadeCount && _CascadeCount > 0)
    {
        data.strength = 0.0;
    }
    #ifdef _CASCADE_BLEND_DITHER
	    else if (data.cascadeBlend < surface.dither) {
            i += 1;
		}
    #endif
    #ifndef _CASCADE_BLEND_SOFT
        data.cascadeBlend = 1.0;
	#endif
    data.cascadeIndex = i;
    return data;
}


float SampleDirectionalShadowAtlasDepth(float2 uv,bool useLod=false)
{
    if(!useLod)
        return SAMPLE_TEXTURE2D(_DirectionalShadowAtlas, SHADOW_SAMPLER, uv).r;
    else
        return SAMPLE_TEXTURE2D_LOD(_DirectionalShadowAtlas, SHADOW_SAMPLER, uv,0).r;

}

float SampleDirectionalShadowAtlas(float3 positionSTS, bool useLod = false)
{
    float depth = SampleDirectionalShadowAtlasDepth(positionSTS.xy,useLod);
    #if defined(UNITY_REVERSED_Z)
        return positionSTS.z < depth ? 0 : 1;
    #else 
        return positionSTS.z < depth ? 1 : 0;
    #endif
}


float PenumbraSize(float zReceiver, float zBlocker) //Parallel plane estimation
{
    #if defined(UNITY_REVERSED_Z)
        return -(zReceiver - zBlocker) / zBlocker;
    #else 
        return (zReceiver - zBlocker) / zBlocker;
    #endif

    
}

float BlockerSearch( float2 uv, float zReceiver)
{
     //This uses similar triangles to compute what
     //area of the shadow map we should search
    float searchWidth = CONST_SEARCH_LENGTH * _ShadowAtlasSize.y;
    float blockerSum = 0;
    float avgBlockerDepth = 0;
    float numBlockers = 0;

    for (int i = 0; i < BLOCKER_SEARCH_NUM_SAMPLES; ++i)
    {
        float2 offset = poissonDisk[i] * searchWidth * 0.5;
        float shadowMapDepth = SampleDirectionalShadowAtlasDepth(uv + poissonDisk[i] * offset);
        if (shadowMapDepth > zReceiver)
        {
            blockerSum += shadowMapDepth;
            numBlockers++;
        }
    }
  
    avgBlockerDepth = blockerSum / (numBlockers+0.0001);
    return avgBlockerDepth;
}

float PCF_Filter(float2 uv, float zReceiver, float filterRadiusUV)
{
    
    float sum = 0.0f;
#if defined(_SHADOWS_PCSS)
    
    int len = filterRadiusUV / _ShadowAtlasSize.y;
     
    int cnt=0;
    for (int x = -len/2; x <= len/2; ++x)
    {
        for(int y= -len/2; y <=len/2;++y)
        {
         float2 offset = float2(x*_ShadowAtlasSize.y,y*_ShadowAtlasSize.y);
         sum += SampleDirectionalShadowAtlas(float3(uv + offset, zReceiver),true);
         cnt+=1;
        }
           
    }
    return sum / cnt;
    //  for (int i = 0; i < 16; ++i)
    //{
    //    float2 offset = poissonDisk[i] * filterRadiusUV*0.5;
    //     sum += SampleDirectionalShadowAtlas(float3(uv + offset, zReceiver));
    //}
    //return sum / 16;
#elif defined(DIRECTIONAL_FILTER_SETUP)
    for (int i = 0; i < DIRECTIONAL_FILTER_SAMPLES; ++i)
    {
        float2 offset = poissonDisk[i] * filterRadiusUV*0.5;
         sum += SampleDirectionalShadowAtlas(float3(uv + offset, zReceiver));
    }
    return sum / DIRECTIONAL_FILTER_SAMPLES;
 #else
    return sum;
#endif
}

float FilterDirectionalShadow(float3 positionSTS)
{
#if defined(_SHADOWS_PCSS)
    float averageDepth = 0.0;
    float numBlockers = 0.0;
    averageDepth = BlockerSearch(positionSTS.xy,positionSTS.z);
    
    if(averageDepth == 0.0) return 1.0;
    float penumbraRatio = PenumbraSize(positionSTS.z, averageDepth+0.001);
    float filterRadiusUV = penumbraRatio * 0.007324; //fixed factor by test.
    return PCF_Filter(positionSTS.xy,positionSTS.z,filterRadiusUV);
#elif defined(DIRECTIONAL_FILTER_SETUP)
	float weights[DIRECTIONAL_FILTER_SAMPLES];
	float2 positions[DIRECTIONAL_FILTER_SAMPLES];
	float4 size = _ShadowAtlasSize.yyxx;
	DIRECTIONAL_FILTER_SETUP(size, positionSTS.xy, weights, positions);
    float filterSizeUV = DIRECTIONAL_FILTER_SIZE * _ShadowAtlasSize.y;
	float shadow = 0;
    shadow = PCF_Filter(positionSTS.xy,positionSTS.z,filterSizeUV);
	return shadow;
#else 
    return SampleDirectionalShadowAtlas(positionSTS);
#endif
}
float GetCascadedShadow(DirectionalShadowData data, ShadowData shadowData, Surface surface)
{
    float3 normalBias = data.normalBias * surface.originNormal * _CascadeData[shadowData.cascadeIndex].y;
    float3 positionSTS = mul(_DirectionalShadowMatrices[data.tileIndex], float4(surface.positionWS + normalBias, 1.0)).xyz;
    float shadow = FilterDirectionalShadow(positionSTS);
    if (shadowData.cascadeBlend < 1.0)
    {
        //in cascade transition zone, blend two cascade shadow result.
        normalBias = data.normalBias * surface.originNormal * _CascadeData[shadowData.cascadeIndex + 1].y;
        positionSTS = mul(_DirectionalShadowMatrices[data.tileIndex], float4(surface.positionWS + normalBias, 1.0)).xyz;
        shadow = lerp(FilterDirectionalShadow(positionSTS), shadow, shadowData.cascadeBlend);
       // return 0.0;
    }
    return shadow;
}

float GetBakedShadow(ShadowMask mask, int channel)
{
    float shadow = 1.0;
    if (mask.always || mask.distance)
    {
        if (channel >= 0)
        {
            shadow = mask.shadows[channel];
        }
    }
    return shadow;
}
float GetBakedShadow(ShadowMask mask, int channel, float strength)
{
    if (mask.always || mask.distance)
    {
        return lerp(1.0, GetBakedShadow(mask,channel), strength);
    }
    return 1.0;
}
float MixBakedAndRealtimeShadows(
	ShadowData global, float shadow, int shadowMaskChannel,float strength)
{
    float baked = GetBakedShadow(global.shadowMask, shadowMaskChannel);
    if (global.shadowMask.distance)
    {
        shadow = lerp(baked, shadow, global.strength);
        return lerp(1.0, shadow, strength);
    }
    if (global.shadowMask.always) {
		shadow = lerp(1.0, shadow, global.strength);
		shadow = min(baked, shadow);
		return lerp(1.0, shadow, strength);
	}
    return lerp(1.0, shadow, global.strength * strength);
}
float GetDirectionalShadowsAttenuation(Surface surface, DirectionalShadowData data, ShadowData shadowData)
{
    #if !defined(_RECEIVE_SHADOWS)
        return 1.0;
    #endif
    float shadow;
    if (data.strength * shadowData.strength <= 0.0)
    {
        return GetBakedShadow(shadowData.shadowMask, data.shadowMaskChannel,
        abs(data.strength));
    }
    else
    {
        shadow = GetCascadedShadow(data, shadowData, surface);
        shadow = MixBakedAndRealtimeShadows(shadowData, shadow,
        data.shadowMaskChannel, data.strength);
    } //shadow = 1 means no shadowed ,otherwise shadow = 0 means fully shadowed. 
    return shadow;
}

float SampleOtherShadowAtlasDepth(float2 uv, bool useLod = false)
{
    if (!useLod)
        return SAMPLE_TEXTURE2D(_OtherShadowAtlas, SHADOW_SAMPLER, uv).r;
    else
        return SAMPLE_TEXTURE2D_LOD(_OtherShadowAtlas, SHADOW_SAMPLER, uv, 0).r;

}
float SampleOtherShadowAtlas(float3 positionSTS, float3 bounds,bool useLod = false)
{
    positionSTS.xy = clamp(positionSTS.xy, bounds.xy, bounds.xy + bounds.z);
    float depth = SampleOtherShadowAtlasDepth(positionSTS.xy, useLod);
    #if defined(UNITY_REVERSED_Z)
            return positionSTS.z < depth ? 0 : 1;
    #else 
        return positionSTS.z < depth ? 1 : 0;
    #endif
}

float FilterOtherShadow(float3 positionSTS, float3 bounds)
{
#if defined(OTHER_FILTER_SETUP)
		real weights[OTHER_FILTER_SAMPLES];
		real2 positions[OTHER_FILTER_SAMPLES];
		float4 size = _ShadowAtlasSize.wwzz;
		OTHER_FILTER_SETUP(size, positionSTS.xy, weights, positions);
		float shadow = 0;
		for (int i = 0; i < OTHER_FILTER_SAMPLES; i++) {
			shadow += weights[i] * SampleOtherShadowAtlas(
				float3(positions[i].xy, positionSTS.z), bounds
			);
		}
		return shadow;
#else
    return SampleOtherShadowAtlas(positionSTS, bounds);
#endif
}

static const float3 pointShadowPlanes[6] =
{
    float3(-1.0, 0.0, 0.0),
	float3(1.0, 0.0, 0.0),
	float3(0.0, -1.0, 0.0),
	float3(0.0, 1.0, 0.0),
	float3(0.0, 0.0, -1.0),
	float3(0.0, 0.0, 1.0)
};

float GetOtherShadow(OtherShadowData other, ShadowData global, Surface surface)
{
    float tileIndex = other.tileIndex;
    float3 lightPlane = other.spotDirectionWS;
    if (other.isPoint)
    {
        float faceOffset = CubeMapFaceID(-other.lightDirectionWS);
        tileIndex += faceOffset;
        lightPlane = pointShadowPlanes[faceOffset];
    }
    float4 tileData = _OtherShadowTiles[tileIndex];
    float3 surfaceToLight = other.lightPositionWS - surface.positionWS;
    float distanceToLightPlane = dot(surfaceToLight, lightPlane);
    float3 normalBias = surface.originNormal * (distanceToLightPlane * tileData.w);
    float4 positionSTS = mul(
		_OtherShadowMatrices[tileIndex],
		float4(surface.positionWS + normalBias, 1.0)
	);
    return FilterOtherShadow(positionSTS.xyz / positionSTS.w, tileData.xyz);
}
float GetOtherShadowsAttenuation(OtherShadowData other, ShadowData global, Surface surface)
{
    #if !defined(_RECEIVE_SHADOWS)
        return 1.0;
    #endif
	
        float shadow;
        if (other.strength *global.strength<= 0.0)
        {
            shadow = GetBakedShadow(
			    global.shadowMask, other.shadowMaskChannel, abs(other.strength)
		    );
        }
        else
        {
            shadow = GetOtherShadow(other,global,surface);
            shadow = MixBakedAndRealtimeShadows(
			    global, shadow, other.shadowMaskChannel, other.strength);
        }
        
        return shadow;
    }
#endif