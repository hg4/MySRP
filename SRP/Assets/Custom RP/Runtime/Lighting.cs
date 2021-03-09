using System;
using System.Collections;
using System.Collections.Generic;
using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;
public class Lighting
{
    const string bufferName = "Lighting";
    const int maxDirLightCount = 4;

    static int dirLightCountId =Shader.PropertyToID("_DirectionalLightCount"),
                dirLightColorsId = Shader.PropertyToID("_DirectionalLightColors"),
                dirLightDirectionsId = Shader.PropertyToID("_DirectionalLightDirections");
    Vector4[] dirLightColors = new Vector4[maxDirLightCount],
               dirLightDirections = new Vector4[maxDirLightCount];
    CommandBuffer _buffer = new CommandBuffer { name=bufferName };
    CullingResults cullingResults;
    public void Setup(ScriptableRenderContext context,CullingResults result)
    {
        cullingResults = result;
        _buffer.BeginSample(bufferName);
        SetupLights();
        context.ExecuteCommandBuffer(_buffer);
        _buffer.EndSample(bufferName);
        _buffer.Clear();
    }

    private void SetupLights()
    {
        NativeArray<VisibleLight> visibleLights = cullingResults.visibleLights;
        int cnt = 0;
        for(int i = 0; i < visibleLights.Length; i++)
        {
            VisibleLight visibleLight = visibleLights[i];
            if (visibleLight.lightType == LightType.Directional)
            {
                SetupDirectionalLight(cnt++,ref visibleLight);
                if (cnt >= maxDirLightCount) break;
            }
        }
        _buffer.SetGlobalInt(dirLightCountId, cnt);
        _buffer.SetGlobalVectorArray(dirLightColorsId, dirLightColors);
        _buffer.SetGlobalVectorArray(dirLightDirectionsId, dirLightDirections);
    }

    void SetupDirectionalLight(int index ,ref VisibleLight visibleLight)
    {
        dirLightColors[index] = visibleLight.finalColor;
        dirLightDirections[index] = -visibleLight.localToWorldMatrix.GetColumn(2);
    }

}
