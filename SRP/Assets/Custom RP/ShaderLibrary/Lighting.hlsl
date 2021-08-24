#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED
#define AMBIENT_FACTOR 0.03

//lighting.hlsl is a utils class used for lighting model calculation.
#include "PBRUtils.hlsl"

//get light radiance distribution for surface
float3 IncomingLight(Surface surface, Light light)
{
    return saturate(dot(surface.normal, light.direction) * light.attenuation) * light.color;
}

float3 FresnelSchlickRoughness(float NdotV, float3 F, float roughness)
{
    return F + (max(1 - roughness,F) - F) * pow(1.0 - NdotV, 5.0);
}
float3 FresnelSchlick(float HdotV, float3 F)
{
    return F + (1- F) * pow(1.0 - HdotV, 5.0);
}

//get diffuse and specular base color
BRDF GetBRDF(Surface surface, bool applyAlphaToDiffuse = false)
{
    float3 F = lerp(float3(F0,F0,F0), surface.color, surface.metallic);
    F = FresnelSchlickRoughness(saturate(dot(surface.normal, surface.V)), F,surface.roughness);
    BRDF brdf;
    #ifdef _PREMULTI_ALPHA
        brdf.diffuse = surface.color * (1 - F)  * (1 - surface.metallic) * surface.alpha/M_PI;
    #else
        brdf.diffuse = surface.color * (1 - F) * (1 - surface.metallic)/M_PI;
    #endif
        brdf.specular = F;
    return brdf;
}

BRDF GetBRDFWithLight(Surface surface, Light light, bool applyAlphaToDiffuse = false)
{
    float3 H = SafeNormalize(light.direction + surface.V);
    float HdotV = saturate(dot(H, surface.V));
    float3 F = lerp(float3(0.04,0.04,0.04), surface.color, surface.metallic);
    F = FresnelSchlick(HdotV, F);
    BRDF brdf;
#ifdef _PREMULTI_ALPHA
        brdf.diffuse = surface.color * (1 - F)  * (1 - surface.metallic) * surface.alpha/M_PI ;
#else
    brdf.diffuse = surface.color * (1 - F) * (1 - surface.metallic) /M_PI;
#endif
    brdf.specular = F;
    return brdf;
}

//Minimalist CookTorrance BRDF
float SpecularStrength(Surface surface, BRDF brdf, Light light)
{
    float3 H = SafeNormalize(light.direction + surface.V);
    float nh2 = Square(saturate(dot(surface.normal, H)));
    float lh2 = Square(saturate(dot(light.direction, H)));
    float r2 = Square(surface.roughness);
    float d2 = Square(nh2 * (r2 - 1.0) + 1.00001);
    float normalization = surface.roughness * 4.0 + 2.0;
    return r2 / (d2 * max(0.1, lh2) * normalization);
}

float specularBRDF(Surface surface, BRDF brdf, Light light)
{
    float3 H = SafeNormalize(light.direction + surface.V);
    float3 V = surface.V;
    float3 N = surface.normal;
    float3 L = light.direction;
    float NdotL = saturate(dot(N, L));
    float NdotV = saturate(dot(N, V));
    float NdotH = saturate(dot(N, H));
    float HdotV = saturate(dot(H, V));
    float NDF = D_GTR2(NdotH, surface.roughness);
    float G = GeometrySmith(N, V, L, surface.roughness);
    float F = brdf.specular;
    float denominator = 4.0 * NdotV * NdotL;
    return NDF * G * F / (denominator + 0.001);
    
    
}
// brdf_lit use lambert diffuse BRDF(without pi) and Minimalist CookTorrance specular BRDF
float3 BRDF_Lit(Surface surface, BRDF brdf, Light light)
{
    return specularBRDF(surface, brdf, light) + brdf.diffuse;
}
float3 GetAmbient(Surface surface,BRDF brdf)
{
    //float3 V = surface.V;
    //float3 N = surface.normal;
    //float roughness = surface.roughness;
    //float metallic = surface.metallic;
    //float NdotV = saturate(dot(N, V));
    //float3 R = reflect(-V, N);
    //float3 F = brdf.specular;
    //float3 prefilteredColor = SampleEnvironment(surface);
    //float2 envBRDF = GetBrdfLUT(float2(NdotV, roughness));
    //float3 irradiance = GetIrradianceMap(N);
    //float3 diffuseEnv = (1 - metallic) * (1 - F) * irradiance * surface.color;
    //float3 specularEnv = prefilteredColor * (F * envBRDF.x + envBRDF.y);
    //return surface.ao*(diffuseEnv + specularEnv);
    return surface.ao * AMBIENT_FACTOR * surface.color;

}

float3 GetLighting(Surface surface, Light light)
{
   
    BRDF brdf = GetBRDF(surface);
    return IncomingLight(surface, light) * BRDF_Lit(surface, brdf, light) + GetAmbient(surface,brdf);
}

float3 GetLighting(Surface surface, BRDF brdf,GI gi)
{
    float3 finalColor;
    ShadowData shadowData = GetShadowData(surface);
    shadowData.shadowMask = gi.shadowMask;  
    finalColor = float3(0, 0, 0);
    finalColor = IndirectBRDF(surface, brdf, gi.diffuse, gi.specular);
   
    for (int i = 0; i < _DirectionalLightCount; i++)
    {
        Light light = GetDirectionalLight(i,surface,shadowData);
        finalColor += GetLighting(surface, light);
        
    }
    #if defined(_LIGHTS_PER_OBJECT)
		for (int j = 0; j < unity_LightData.y; j++) {
			int lightIndex = unity_LightIndices[j / 4][j % 4];
			Light light = GetOtherLight(lightIndex, surface, shadowData);
			finalColor += GetLighting(surface, light);
		}
	#else
        for (int j = 0; j < GetOtherLightCount();j++)
        {
            Light light = GetOtherLight(j, surface, shadowData);
            finalColor += GetLighting(surface, light);
        }
   
    #endif
    return finalColor;
}


#endif
