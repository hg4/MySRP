using System;
using System.Collections;
using System.Collections.Generic;
using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;
public class Lighting
{
    const string _bufferName = "Lighting";
    const int maxDirLightCount = 4,maxOtherCount = 64;
    static string lightsPerObjectKeyword = "_LIGHTS_PER_OBJECT";
    static int dirLightCountId = Shader.PropertyToID("_DirectionalLightCount"),
                dirLightColorsId = Shader.PropertyToID("_DirectionalLightColors"),
                otherLightCountId = Shader.PropertyToID("_OtherLightCount"),
                otherLightColorsId = Shader.PropertyToID("_OtherLightColors"),
                otherLightPositionsId = Shader.PropertyToID("_OtherLightPositions"),
                otherLightDirectionsId = Shader.PropertyToID("_OtherLightDirections"),
                otherLightSpotAnglesId = Shader.PropertyToID("_OtherLightSpotAngles"),
                otherLightShadowDataId =Shader.PropertyToID("_OtherLightShadowData"),
                dirLightDirectionsId = Shader.PropertyToID("_DirectionalLightDirections"),
                dirLightShadowDataId = Shader.PropertyToID("_DirectionalLightShadowData");
    Vector4[] dirLightColors = new Vector4[maxDirLightCount],
               dirLightDirections = new Vector4[maxDirLightCount],
                otherLightColors = new Vector4[maxOtherCount],
                otherLightPositions = new Vector4[maxOtherCount],
                otherLightSpotAngles = new Vector4[maxOtherCount],
                otherLightShadowData = new Vector4[maxOtherCount],
                otherLightDirections = new Vector4[maxOtherCount];
    Vector4[] dirLightShadowData = new Vector4[maxDirLightCount];
    CommandBuffer _buffer = new CommandBuffer { name=_bufferName };
    ScriptableRenderContext _context;
    CullingResults _cullingResults;
    Shadows shadows= new Shadows();
    public void Setup(ScriptableRenderContext context,CullingResults result, 
        ShadowSettings shadowSettings, bool useLightsPerObject)
    {
        _context = context;
        _cullingResults = result;
        _buffer.BeginSample(_bufferName);
        ExecuteBuffer();
        shadows.Setup(context, result, shadowSettings);//shadows 在调render texture api的时候自己完成了sample？这里源代码的lighting sample少了execute开启采样状态，frame debugger里不会有lighting group
        SetupLights(useLightsPerObject);
        shadows.Render();
        _buffer.EndSample(_bufferName);
        ExecuteBuffer();
    }

    private void SetupLights(bool useLightsPerObject)
    {
        NativeArray<int> indexMap = useLightsPerObject ?
            _cullingResults.GetLightIndexMap(Allocator.Temp) : default;
        NativeArray<VisibleLight> visibleLights = _cullingResults.visibleLights;
        int dirLightCount = 0, otherLightCount = 0;
        int i;
        for ( i = 0; i < visibleLights.Length; i++)
        {
            int newIndex = -1;
            VisibleLight visibleLight = visibleLights[i];
            if (visibleLight.lightType == LightType.Directional)
            {
                SetupDirectionalLight(dirLightCount++, i, ref visibleLight);
                if (dirLightCount >= maxDirLightCount) break;
            }
            else if(visibleLight.lightType == LightType.Point)
            {
                newIndex = otherLightCount;
                SetupPointLight(otherLightCount++, i, ref visibleLight);
                if (otherLightCount >= maxOtherCount) break;
            }
            else if(visibleLight.lightType == LightType.Spot)
            {
                newIndex = otherLightCount;
                SetupSpotLight(otherLightCount++, i, ref visibleLight);
                if (otherLightCount >= maxOtherCount) break;
            }
            if (useLightsPerObject)
            {
                //filter directional light
                indexMap[i] = newIndex;
            }
        }
        //set unvisible light index = -1
        if (useLightsPerObject)
        {
            for (; i < indexMap.Length; i++)
            {
                indexMap[i] = -1;
            }
            _cullingResults.SetLightIndexMap(indexMap);
            indexMap.Dispose();
            Shader.EnableKeyword(lightsPerObjectKeyword);
        }
        else
        {
            Shader.DisableKeyword(lightsPerObjectKeyword);
        }
        _buffer.SetGlobalInt(dirLightCountId, dirLightCount);
        _buffer.SetGlobalInt(otherLightCountId, otherLightCount);
        if (otherLightCount > 0)
        {
            _buffer.SetGlobalVectorArray(otherLightPositionsId, otherLightPositions);
            _buffer.SetGlobalVectorArray(otherLightColorsId, otherLightColors);
            _buffer.SetGlobalVectorArray(otherLightDirectionsId, otherLightDirections);
            _buffer.SetGlobalVectorArray(otherLightShadowDataId, otherLightShadowData);
            _buffer.SetGlobalVectorArray(otherLightSpotAnglesId, otherLightSpotAngles);
        }
        _buffer.SetGlobalVectorArray(dirLightColorsId, dirLightColors);
        _buffer.SetGlobalVectorArray(dirLightDirectionsId, dirLightDirections);
        _buffer.SetGlobalVectorArray(dirLightShadowDataId, dirLightShadowData);
    }
    void SetupPointLight(int index , int visibleIndex, ref VisibleLight visibleLight)
    {
        otherLightColors[index] = visibleLight.finalColor;
        otherLightPositions[index] = visibleLight.localToWorldMatrix.GetColumn(3);
        otherLightPositions[index].w = 1f / Mathf.Max(visibleLight.range * visibleLight.range, 0.0001f); 
        otherLightSpotAngles[index] = new Vector4(0f, 1f);
        Light light = visibleLight.light;
        otherLightShadowData[index] = shadows.ReserveOtherShadow(light, visibleIndex);
    }
    void SetupDirectionalLight(int index , int visibleIndex, ref VisibleLight visibleLight)
    {
        dirLightColors[index] = visibleLight.finalColor;
        dirLightDirections[index] = -visibleLight.localToWorldMatrix.GetColumn(2);
        dirLightShadowData[index] = shadows.ReserveDirectionalShadow(visibleLight.light, visibleIndex);
    }
    void SetupSpotLight(int index, int visibleIndex, ref VisibleLight visibleLight)
    {
        otherLightColors[index] = visibleLight.finalColor;
        otherLightPositions[index] = visibleLight.localToWorldMatrix.GetColumn(3);
        otherLightPositions[index].w = 1f / Mathf.Max(visibleLight.range * visibleLight.range, 0.0001f);
        otherLightDirections[index] = -visibleLight.localToWorldMatrix.GetColumn(2);
        Light light = visibleLight.light;
        float innerCos = Mathf.Cos(Mathf.Deg2Rad * 0.5f * light.innerSpotAngle);
        float outerCos = Mathf.Cos(Mathf.Deg2Rad * 0.5f * visibleLight.spotAngle);
        float angleRangeInv = 1f / Mathf.Max(innerCos - outerCos, 0.001f);
        otherLightSpotAngles[index] = new Vector4(
            angleRangeInv, -outerCos * angleRangeInv
        );
        otherLightShadowData[index] = shadows.ReserveOtherShadow(light, visibleIndex);
    }
    void ExecuteBuffer()
    {
        _context.ExecuteCommandBuffer(_buffer);
        _buffer.Clear();
    }
    public void Cleanup()
    {
        shadows.Cleanup();
    }
}
