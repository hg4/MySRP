#ifndef CUSTOM_COMMON
#define CUSTOM_COMMON

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "UnityInput.hlsl"
#include "ColorBlend.hlsl"
#define UNITY_MATRIX_M unity_ObjectToWorld
#define UNITY_MATRIX_I_M unity_WorldToObject
#define UNITY_MATRIX_V unity_MatrixV
#define UNITY_MATRIX_VP unity_MatrixVP
#define UNITY_MATRIX_P glstate_matrix_projection
#define M_PI 3.1415926 
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"

float Square(float v)
{
    return v * v;
}

float DistanceSquared(float3 pA, float3 pB)
{
    return dot(pA - pB, pA - pB);
}

float3 DecodeNormal(float4 sample, float scale)
{
#if defined(UNITY_NO_DXT5nm)
	return UnpackNormalRGB(sample, scale);
#else
    return UnpackNormalmapRGorAG(sample, scale);
#endif
}
float3 NormalTangentToWorld(float3 normalTS, float3 normalWS, float4 tangentWS)
{
    float3x3 tangentToWorld =
		CreateTangentToWorld(normalWS, tangentWS.xyz, tangentWS.w);
    return TransformTangentToWorld(normalTS, tangentToWorld);
}
bool IsOrthographicCamera()
{
    return unity_OrthoParams.w;
}

float OrthographicDepthBufferToLinear(float rawDepth)
{
#if UNITY_REVERSED_Z
		rawDepth = 1.0 - rawDepth;
#endif
    return (_ProjectionParams.z - _ProjectionParams.y) * rawDepth + _ProjectionParams.y;
}

void ClipLOD(float2 positionSS, float fade)
{
#if defined(LOD_FADE_CROSSFADE)
// Screen-door transparency: Discard pixel if below threshold.
    float4x4 thresholdMatrix =
    {  1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0,
      13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0,
       4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0,
      16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0
    };
    float4x4 _RowAccess = { 1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1 };
    float2 pos = positionSS;
    clip(fade - thresholdMatrix[fmod(pos.x, 4)] * _RowAccess[fmod(pos.y, 4)]);
#endif
}

float3 GetModelScaleMatrix()
{
    //float3x3 local = (float3x3)transpose(unity_ObjectToWorld);
    //local = transpose(local) * local;
    //return float3(sqrt(local[0][0]), sqrt(local[1][1]), sqrt(local[2][2]));
    float3x3 local = (float3x3) (unity_ObjectToWorld);
    float a = sqrt(dot(float3(local[0].x, local[1].x, local[2].x), float3(local[0].x, local[1].x, local[2].x)));
    float b = sqrt(dot(float3(local[0].y, local[1].y, local[2].y), float3(local[0].y, local[1].y, local[2].y)));
    float c = sqrt(dot(float3(local[0].z, local[1].z, local[2].z), float3(local[0].z, local[1].z, local[2].z)));
    return float3(a, b, c);
    //return transpose(unity_ObjectToWorld)[3];
    //return float3(unity_ObjectToWorld[3][3], unity_ObjectToWorld[3][3], unity_ObjectToWorld[3][3]);
}

float ApplyOutlineDistanceFadeOut(float positionVS_Z)
{
#ifdef UNITY_REVERSED_Z
        positionVS_Z = abs(positionVS_Z);
#endif
    positionVS_Z = smoothstep(25.0, 0.5f, positionVS_Z);
    return positionVS_Z * 0.01;
}
float3 DecodeNormal(float2 normalRG)
{
    float3 normal = float3(0, 0, 0);
    normal.xy = normalRG.xy * 2 -1;
    normal.z = sqrt(1 - dot(normal.xy, normal.xy));
    return normal;
}
float4 GetNewClipPosWithZOffset(float4 originalPositionCS, float viewSpaceZOffsetAmount)
{
    if (unity_OrthoParams.w == 0)
    {
        ////////////////////////////////
        //Perspective camera case
        ////////////////////////////////
        float2 ProjM_ZRow_ZW = UNITY_MATRIX_P[2].zw;
        float modifiedPositionVS_Z = -originalPositionCS.w + -viewSpaceZOffsetAmount; // push imaginary vertex
        float modifiedPositionCS_Z = modifiedPositionVS_Z * ProjM_ZRow_ZW[0] + ProjM_ZRow_ZW[1];
        //-modifiedPositionVS_Z = modifiedPositionCS.w, here make modifiedPositionCS_Z value scale to origin.w
        originalPositionCS.z = modifiedPositionCS_Z * originalPositionCS.w / (-modifiedPositionVS_Z);
        
        return originalPositionCS;
    }
    else
    {
        ////////////////////////////////
        //Orthographic camera case
        ////////////////////////////////
        originalPositionCS.z += (-viewSpaceZOffsetAmount) / _ProjectionParams.z; // push imaginary vertex and overwrite positionCS.z
        return originalPositionCS;
    }
}

float DepthAttenuation(float depth)
{
    if (depth > 1.0f)
        return smoothstep(15.0f, 1.0f, depth);
    else
        return (9 / (depth + 2) - 2) * (9 / (depth + 2) - 2);
}
float3 ProjectionVectorToLocalXZ(float3 v)
{
    v = TransformWorldToObjectDir(v);
    float3 front = float3(0, 0, 1);
    float3 right = float3(1, 0, 0);
    float3 up = float3(0, 1, 0);
    float3 projectionToXZ = normalize(v - up * dot(v, up));
    return projectionToXZ;
}
float3 ProjectionVectorToLocalYZ(float3 v)
{
    v = TransformWorldToObjectDir(v);
    float3 front = float3(0, 0, 1);
    float3 right = float3(1, 0, 0);
    float3 up = float3(0, 1, 0);
    float3 projectionToYZ = normalize(v - right * dot(v, right));
    return projectionToYZ;
}
float3 ProjectionVectorToLocalXY(float3 v)
{
    v = TransformWorldToObjectDir(v);
    float3 front = float3(0, 0, 1);
    float3 right = float3(1, 0, 0);
    float3 up = float3(0, 1, 0);
    float3 projectionToXY = normalize(v - front * dot(v, front));
    return projectionToXY;
}
#endif