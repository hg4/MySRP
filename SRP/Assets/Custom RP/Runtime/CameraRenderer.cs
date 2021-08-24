using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
public partial class CameraRenderer
{
    ScriptableRenderContext _context;
    Camera _cam;
    bool _useHDR;
    int _colorLUTResolution;
    int _msaaSamples;
    const string _bufferName = "Render camera";
    CommandBuffer _buffer = new CommandBuffer { name = _bufferName };
    CullingResults _cullingResults;
    static ShaderTagId unlitShaderTagId = new ShaderTagId("SRPDefaultUnlit"),
                       litShaderTagId = new ShaderTagId("CustomLit"),
                       toonShaderTagId =  new ShaderTagId("CustomToon"),
                       outlineShaderTagId =  new ShaderTagId("CustomOutline"),
                        silhouetteShaderTagId = new ShaderTagId("CustomSilhouette");
    Lighting lighting = new Lighting();
    PostFXStack postFXStack = new PostFXStack();
    CustomGBuffer customGBuffer = new CustomGBuffer();
    public static int colorAttachmentId = Shader.PropertyToID("_CameraColorAttachment"),
    depthAttachmentId = Shader.PropertyToID("_CameraDepthAttachment"),
    depthTextureId = Shader.PropertyToID("_CameraDepthTexture"),
    colorTextureId = Shader.PropertyToID("_CameraColorTexture");
    bool _useDepthTexture, _useColorTexture;
    public void Render(ScriptableRenderContext context,Camera camera,
        bool allowHDR , bool useGPUInstancing,
        bool useLightsPerObject, ShadowSettings shadowSettings, 
        PostFXSettings postFXSettings, int colorLUTResolution, int msaaSamples)
    {
        _context = context;
        _cam = camera;  
        _useHDR = allowHDR && camera.allowHDR;
        _colorLUTResolution = colorLUTResolution;
        _msaaSamples = camera.allowMSAA ? msaaSamples : 1;
        //PrepareBuffer();
        //PrepareForSceneWindow();
        if (!TryCull(shadowSettings)) return;
        _buffer.BeginSample(SampleName);//add sample cmd to buffer
        ExecuteBuffer();//execute sample cmd. 只有在BeginSample函数被命令缓冲送去执行后会开启采样状态，在他执行后被送去执行的函数命令才会被sample记录
        lighting.Setup(context, _cullingResults, shadowSettings, useLightsPerObject);//sampled by 'render camera' buffer.
        postFXStack.Setup(context, camera, postFXSettings,_useHDR,colorLUTResolution);
        customGBuffer.Setup(context, _cullingResults, camera, _useHDR, useGPUInstancing);
        customGBuffer.Render();
        _buffer.EndSample(SampleName);//add end sample cmd to buffer
        Setup();//init some status in context
        DrawVisibleGeometry(useGPUInstancing,useLightsPerObject);//draw command in context
        DrawGizmosBeforeFX();
        if (postFXStack.IsActive)
        {

            postFXStack.Render(colorAttachmentId);
        }
        DrawGizmosAfterFX();
        Cleanup();
        Submit();//submit buffered command in context
    }
    void CopyAttachments()
    {
        if (postFXStack.IsActive || _msaaSamples > 1)
        {
            _buffer.GetTemporaryRT(
               colorTextureId, _cam.pixelWidth, _cam.pixelHeight,
               0, FilterMode.Bilinear, _useHDR ? RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default,
               RenderTextureReadWrite.Default,_msaaSamples
           );

            _buffer.CopyTexture(colorAttachmentId, colorTextureId);
            ExecuteBuffer();
            _buffer.GetTemporaryRT(
                depthTextureId, _cam.pixelWidth, _cam.pixelHeight,
                32, FilterMode.Point, RenderTextureFormat.Depth
            );
            _buffer.CopyTexture(depthAttachmentId, depthTextureId);
            ExecuteBuffer();
        }
        
    }

   
    private void Setup()
    {
        CameraClearFlags flags = _cam.clearFlags;
        _context.SetupCameraProperties(_cam);//set camera VP matrix to context status,we should setup camera before
                                             //renderTarget clear because renderTarget is bind with camera
                                             //to use secondary camera only to show legacy shader object, we determines whether clear renderTarget by camera's clear flag,which get different mixed effect by two camera.

        if (postFXStack.IsActive)
        {
            _buffer.GetTemporaryRT(
                colorAttachmentId, _cam.pixelWidth, _cam.pixelHeight,
                32, FilterMode.Bilinear, _useHDR ? RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default
            );
            _buffer.GetTemporaryRT(
                depthAttachmentId, _cam.pixelWidth, _cam.pixelHeight,
                32, FilterMode.Point, RenderTextureFormat.Depth
            );
            _buffer.SetRenderTarget(
                colorAttachmentId,
                RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store,
                depthAttachmentId,
                RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store
            );
        }
        _buffer.ClearRenderTarget(flags <= CameraClearFlags.Depth, flags == CameraClearFlags.Color,
                flags == CameraClearFlags.Color ? _cam.backgroundColor.linear : Color.clear);//clear render target before sample command group begins
        _buffer.BeginSample(SampleName);//This is useful for measuring CPU and GPU time spent by one or more commands in the command buffer.
        ExecuteBuffer();
        
    }
    void DrawVisibleGeometry(bool useGPUInstancing, bool useLightsPerObject)
    {
        PerObjectData lightsPerObjectFlags = useLightsPerObject ?
            PerObjectData.LightData | PerObjectData.LightIndices :
            PerObjectData.None;
        var filteringSettings = new FilteringSettings(RenderQueueRange.opaque);
        var sortingSettings = new SortingSettings(_cam)
        {
            criteria = SortingCriteria.CommonOpaque
        };
        var drawingSettings = new DrawingSettings(
             unlitShaderTagId, sortingSettings
         )
        {
            enableInstancing = useGPUInstancing,
            perObjectData = PerObjectData.Lightmaps | PerObjectData.ShadowMask |
            PerObjectData.ReflectionProbes|
            PerObjectData.OcclusionProbe | PerObjectData.OcclusionProbeProxyVolume |
            PerObjectData.LightProbe | PerObjectData.LightProbeProxyVolume |
            lightsPerObjectFlags
        };
       
        drawingSettings.SetShaderPassName(1, litShaderTagId);//add shader lightmode which this draw call can render
        drawingSettings.SetShaderPassName(2, toonShaderTagId);
        drawingSettings.SetShaderPassName(3, outlineShaderTagId);
        //drawingSettings.SetShaderPassName(4, silhouetteShaderTagId);
        _context.DrawRenderers(_cullingResults,ref drawingSettings, ref filteringSettings);
        DrawUnsupportedShaders();
        _context.DrawSkybox(_cam);
        CopyAttachments();
        //Debug.Log(_cam.worldToCameraMatrix);
        sortingSettings.criteria = SortingCriteria.CommonTransparent;
        drawingSettings.sortingSettings = sortingSettings;
        filteringSettings.renderQueueRange = RenderQueueRange.transparent;
        _context.DrawRenderers(_cullingResults, ref drawingSettings, ref filteringSettings);

    }
    private void Submit()
    {
        _buffer.EndSample(SampleName);
        ExecuteBuffer();
        _context.Submit();
    }

 
    void ExecuteBuffer()
    {
        _context.ExecuteCommandBuffer(_buffer);//copy buffer command to gpu but not clear
        _buffer.Clear();
    }

   

    bool TryCull(ShadowSettings shadowSettings)
    {
        //try to get parameter and culling, Returns false if camera is invalid to render (empty viewport rectangle, invalid clip plane setup etc.).
        if (_cam.TryGetCullingParameters(out ScriptableCullingParameters p))
        {
            p.shadowDistance = Math.Min(shadowSettings.maxDistance,_cam.farClipPlane);
            _cullingResults = _context.Cull(ref p);
            //ref keyword can treat as pointer in C++,which pass parameter's reference,
            //here parameter p is a reference type(treat as pointer),so ref p means pointer's pointer classtype** p.
            //out keyword is similar to ref keyword,which means input a uninit parameter's reference,you can init this parameter
            //and modify in function.
            return true;
        }
        return false;
    }

    void Cleanup()
    {
        lighting.Cleanup();
        customGBuffer.Cleanup();
        if (postFXStack.IsActive)
        {
            _buffer.ReleaseTemporaryRT(colorAttachmentId);
            _buffer.ReleaseTemporaryRT(depthAttachmentId);
            //_buffer.ReleaseTemporaryRT(depthNormalTextureId);
            if (_useDepthTexture)
            {
                _buffer.ReleaseTemporaryRT(depthTextureId);
            }
        }
    }
}
