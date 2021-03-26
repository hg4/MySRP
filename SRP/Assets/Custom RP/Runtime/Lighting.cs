using System;
using System.Collections;
using System.Collections.Generic;
using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;
public class Lighting
{
    const string _bufferName = "Lighting";
    const int maxDirLightCount = 4;

    static int dirLightCountId = Shader.PropertyToID("_DirectionalLightCount"),
                dirLightColorsId = Shader.PropertyToID("_DirectionalLightColors"),
                dirLightDirectionsId = Shader.PropertyToID("_DirectionalLightDirections"),
                dirLightShadowDataId = Shader.PropertyToID("_DirectionalLightShadowData");
    Vector4[] dirLightColors = new Vector4[maxDirLightCount],
               dirLightDirections = new Vector4[maxDirLightCount];
    Vector4[] dirLightShadowData = new Vector4[maxDirLightCount];
    CommandBuffer _buffer = new CommandBuffer { name=_bufferName };
    ScriptableRenderContext _context;
    CullingResults _cullingResults;
    Shadows shadows= new Shadows();
    public void Setup(ScriptableRenderContext context,CullingResults result, ShadowSettings shadowSettings)
    {
        _context = context;
        _cullingResults = result;
        _buffer.BeginSample(_bufferName);
        ExecuteBuffer();
        shadows.Setup(context, result, shadowSettings);//shadows 在调render texture api的时候自己完成了sample？这里源代码的lighting sample少了execute开启采样状态，frame debugger里不会有lighting group
        SetupLights();
        shadows.Render();
        _buffer.EndSample(_bufferName);
        ExecuteBuffer();
    }

    private void SetupLights()
    {
        NativeArray<VisibleLight> visibleLights = _cullingResults.visibleLights;
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
        _buffer.SetGlobalVectorArray(dirLightShadowDataId, dirLightShadowData);
    }

    void SetupDirectionalLight(int index ,ref VisibleLight visibleLight)
    {
        dirLightColors[index] = visibleLight.finalColor;
        dirLightDirections[index] = -visibleLight.localToWorldMatrix.GetColumn(2);
        dirLightShadowData[index] = shadows.ReserveDirectionalShadow(visibleLight.light, index);
    }
    void ExecuteBuffer()
    {
        _context.ExecuteCommandBuffer(_buffer);
        _buffer.Clear();
    }
    public void CleanUp()
    {
        shadows.CleanUp();
    }
}
