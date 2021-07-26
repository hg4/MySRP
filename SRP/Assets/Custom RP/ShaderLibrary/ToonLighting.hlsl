#ifndef TOON_LIGHTING_INCLUDED
#define TOON_LIGHTING_INCLUDED

float SampleFaceLightmap(float3 lightDir,float2 uv)
{
    //float3 front = unity_ObjectToWorld._m02_m12_m22;
    //float3 right = unity_ObjectToWorld._m00_m10_m20;
    //float3 up = unity_ObjectToWorld._m01_m11_m21;
                  
    //float3 ProjectionToXZ = normalize(lightDir - up * dot(lightDir, up)); //projection to XZ plane in object space
    lightDir = TransformWorldToObjectDir(lightDir);
    float3 front = float3(0, 0, 1);
    float3 right = float3(1, 0, 0);
    float3 up = float3(0, 1, 0);
    float3 ProjectionToXZ = normalize(lightDir - up * dot(lightDir, up));
    float FrontLight = dot(normalize(front), ProjectionToXZ);
    float RightLight = dot(normalize(right), ProjectionToXZ);
                    
    //uv.y += _OffsetY;
    float3 lightMap = RightLight < 0 ? GetFaceLightmap(uv) : GetFaceLightmap(float2(1.0 - uv.x, uv.y));
                    
    float shadowMask = (lightMap.r > 0.5 - 0.5 * FrontLight); //math derived
    //return lightDir *0.5 +0.5;
    return shadowMask;
}

float3 GetToonLighting(Surface surface, Light light,float4 col)
{
    float halfLambert = (0.5 * dot(surface.normal, light.direction) + 0.5);
    float NdotL = dot(surface.normal, light.direction);
    float NdotV = dot(surface.normal, surface.V);
    float3 color = float3(0,0,0);
    #ifdef _FACE_LIGHT_MAP
        float3 base_color = GetBaseColor().rgb * surface.color * light.color.rgb;
        float3 shadow_color = GetShadowColor().rgb * surface.color * light.color.rgb;
        //color=surface.lightmapMask;
        //return color;
        color = lerp(shadow_color,base_color,surface.lightmapMask);
        //color = float3(surface.lightmapMask,0,0);
    #elif defined (_RAMP_SHADOW)
        float ramp = smoothstep(0, GetShadowSmooth(), halfLambert - GetShadowThreshold());
        float3 baseColor = GetBaseColor().rgb * surface.color * GetRampTex(ramp).rgb * light.color;
        float3 shadowColor = GetShadowColor().rgb * surface.color * GetRampTex(ramp).rgb * light.color;
        color = lerp(shadowColor, baseColor, ramp);
    #else
        float smooth = GetShadowSmooth();
        float v = halfLambert - GetShadowThreshold() - (col.g - 0.5);
        float rampA = smoothstep(0,  smooth/ 2, v);
        float rampB = smoothstep( smooth / 2,smooth, v);
        float ramp = rampA - rampB;
        float3 baseColor = GetBaseColor().rgb * surface.color * light.color.rgb;
        float3 midColor = GetMidColor().rgb * surface.color * light.color.rgb;
        float3 shadowColor = GetShadowColor().rgb * surface.color * light.color.rgb;
        if (v < smooth / 2)
            color = lerp(shadowColor, midColor, ramp);
        else
            color = lerp(baseColor, midColor, ramp);
      
    #endif
    #ifdef _USE_PBR
        float3 diffuse = float3(0,0,0);
        float3 specular = float3(0,0,0);
        PbrBRDF(surface.normal,light.direction,surface,
        diffuse,specular);
        //color = diffuse + specular;
        color = SoftLight(color,diffuse) + GetSpecularEnvScale()*specular;
    #endif
    return color;
}

float3 GetToonLighting(Surface surface, GI gi ,float4 color)
{
    float3 finalColor = 0.0;
    ShadowData shadowData = GetShadowData(surface);
    shadowData.shadowMask = gi.shadowMask;
    for (int i = 0; i < _DirectionalLightCount; i++)
    {
        Light light = GetDirectionalLight(i, surface, shadowData);
        finalColor += GetToonLighting(surface, light,color);
    }
    return finalColor;
}
#endif