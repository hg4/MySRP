#ifndef TOON_LIGHTING_INCLUDED
#define TOON_LIGHTING_INCLUDED

sampler2D _CameraDepthNormalTexture;
float _HairShadowLength;
//float _DirectionScale;
float SampleSelfShadow(Surface surface,Light light)
{
    float3 L = light.direction;
    float2 L_view = normalize(TransformWorldToViewDir(L).xy);
    //float NdotL = dot(N_view, L_view);
    //float scale = (NdotL + 1) / 2;
    float originDepth = tex2D(_CameraDepthNormalTexture, surface.screenUV).w;
    float linearDepth = LinearEyeDepth(originDepth, _ZBufferParams);
    float2 uv = clamp(surface.screenUV +  _HairShadowLength * L_view / _ScreenParams.xy * DepthAttenuation(linearDepth),
        0, _ScreenParams.xy / _ScreenParams.y);

    bool isHair = tex2D(_CameraDepthNormalTexture, uv).b == 1;
    float hairOriginDepth = tex2D(_CameraDepthNormalTexture, uv).w;
    float depth = Linear01Depth(originDepth, _ZBufferParams);
    float hairDepth = Linear01Depth(hairOriginDepth, _ZBufferParams);
    float intensity = (hairDepth - depth) > 0.00001 ? 1 : 0;
    //return intensity;
    intensity = isHair ? intensity : 1;
    return intensity;
}
float SampleFaceLightmap(float3 lightDir,float2 uv)
{
    //float3 front = unity_ObjectToWorld._m02_m12_m22;
    //float3 right = unity_ObjectToWorld._m00_m10_m20;
    //float3 up = unity_ObjectToWorld._m01_m11_m21;
                  
    //float3 ProjectionToXZ = normalize(lightDir - up * dot(lightDir, up)); //projection to XZ plane in object space
    //lightDir = TransformWorldToObjectDir(lightDir);
    float3 front = float3(0, 0, 1);
    float3 right = float3(1, 0, 0);
    float3 up = float3(0, 1, 0);
    float3 ProjectionToXZ = normalize(lightDir - up * dot(lightDir, up));
    //float3 ProjectionToXZ = ProjectionVectorToLocalXY(lightDir);
    //float FrontLight = dot(normalize(up), ProjectionToXZ);
    //float RightLight = dot(normalize(right), ProjectionToXZ);
                    
    float FrontLight = dot(normalize(front), ProjectionToXZ);
    float RightLight = dot(normalize(right), ProjectionToXZ);
                    
    //uv.y += _OffsetY;
    float3 lightMap = RightLight < 0 ? GetFaceLightmap(uv) : GetFaceLightmap(float2(1.0 - uv.x, uv.y));
    float shadowMask = (lightMap.r > 0.5 - 0.5 * FrontLight); //math derived
    //return lightDir *0.5 +0.5;
    return shadowMask;
}

void PbrToonBRDF(float3 N, float3 L, Surface surface,
            inout float3 diffuse, inout float3 specular)
{
    float3 V = surface.V;
    float roughness = surface.roughness;
    float metallic = surface.metallic;
    float3 albedo = surface.color;
    float NdotL = saturate(dot(N, L));
    float NdotV = saturate(dot(N, V));

    
    float3 H = normalize(L + V);
    float NdotH = saturate(dot(N, H));
    float3 R = reflect(-V, N);
    float HdotV = saturate(dot(H, V));
    float NDF = D_GTR2(NdotH, roughness);
    float G = GeometrySmith(N, V, L, roughness);
    float3 F = float3(0.04, 0.04, 0.04);
    F = lerp(F, albedo, metallic);
    F = Fresnel_Schlick(HdotV, F);
    float3 ks = F;
    float3 kd = (1 - metallic) * (1 - F);
    float denominator = 4.0 * NdotV * NdotL;
    float3 spec = NDF * G * F / (denominator + 0.001);
    float3 prefilteredColor = GetPrefilterMap(R);
    float2 envBRDF = GetBrdfLUT(float2(NdotV, roughness));
    float3 irradiance = GetIrradianceMap(N);
    float3 diffuseEnv = GetDiffuseEnvScale() * kd * irradiance * 3.1415926;
    float3 specularEnv = metallic * prefilteredColor * (F * envBRDF.x + envBRDF.y);
    diffuse = diffuseEnv;
    specular = (spec + specularEnv) * GetSpecularEnvScale();
    specular = specular / (specular + 1);

}

float3 GetToonLighting(Surface surface, Light light,float4 col)
{
    light.attenuation = 1.0;
    #ifdef _FACE_LIGHT_MAP
        light.attenuation = SampleSelfShadow(surface,light);
    #endif

    #ifdef _PROJECTION_LIGHT           
    light.direction = (TransformObjectToWorldDir(ProjectionVectorToLocalXZ(light.direction)));
    //return light.direction*0.5 + 0.5;
    #endif
    float halfLambert = (0.5 * dot(surface.normal, light.direction) + 0.5);
    float NdotL = dot(surface.normal, light.direction);
    float NdotV = dot(surface.normal, surface.V);
    float3 color = float3(0,0,0);
    float3 baseColor = float3(0, 0, 0);
    float3 shadowColor = float3(0, 0, 0);
    float3 midColor = float3(0, 0, 0);
    float shadow = 1.0;
    #ifndef _RECEIVE_SHADOWS
        return GetBaseColor().rgb * surface.color;
    #endif

    #ifdef _FACE_LIGHT_MAP
        baseColor = GetBaseColor().rgb * surface.color * light.color.rgb;
        shadowColor = GetShadowColor().rgb * surface.color * light.color.rgb;

        color = lerp(shadowColor,baseColor,surface.lightmapMask*shadow*light.attenuation);
        //color = float3(surface.lightmapMask,0,0);
    #elif defined (_RAMP_SHADOW)
        float ramp = smoothstep(0, GetShadowSmooth(), shadow*(halfLambert - GetShadowThreshold()));
        baseColor = GetBaseColor().rgb * surface.color * GetRampTex(ramp).rgb * light.color;
        shadowColor = GetShadowColor().rgb * surface.color * GetRampTex(ramp).rgb * light.color;
        color = lerp(shadowColor, baseColor, ramp);
    #else
        float smooth = GetShadowSmooth();
        float v = halfLambert - GetShadowThreshold();
        v *= shadow;
        float rampA = smoothstep(0,  smooth/ 2, v);
        float rampB = smoothstep( smooth / 2,smooth, v);
        float ramp = rampA - rampB;
        baseColor = GetBaseColor().rgb * surface.color * light.color.rgb;
        midColor = GetMidColor().rgb * surface.color * light.color.rgb;
        shadowColor = GetShadowColor().rgb * surface.color * light.color.rgb;
        if (v < smooth / 2)
            color = lerp(shadowColor, midColor, ramp);
        else
            color = lerp(baseColor, midColor, ramp);
        //color = v > 0 & v<= 0.01 ? float3(1, 1, 1) : float3(0, 0, 0);
    #endif
    #ifdef _AO_LIGHT_MAP
     //float3 darkColor = RgbToHsv(shadowColor);
     //   darkColor.z = max(darkColor.z-0.1,0.0);
     //   darkColor = HsvToRgb(darkColor);
     //   color = surface.aoMask == 1 ? color == shadowColor ? darkColor : shadowColor : color;
        color = surface.aoMask == 1 ? shadowColor : color;
    #endif
    #ifdef _USE_PBR
        float3 diffuse = float3(0,0,0);
        float3 specular = float3(0,0,0);
        PbrToonBRDF(surface.normal,light.direction,surface,
        diffuse,specular);
        //color = diffuse + specular;
        color = SoftLight(color,diffuse) + specular;
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