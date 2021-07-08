using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class CustomGBuffer
{
    const string _bufferName = "CustomGBuffer";
    static ShaderTagId gBufferShaderTagId = new ShaderTagId("CustomGBuffer");
    static int depthNormalTextureId = Shader.PropertyToID("_CameraDepthNormalTexture"),
        depthNormalAttachmentId = Shader.PropertyToID("_CameraDepthNormalAttachment"),
        depthBufferId = Shader.PropertyToID("_CameraDepthBuffer");
    bool _useDepthNormalTexture;
    CommandBuffer _buffer = new CommandBuffer { name = _bufferName };
    ScriptableRenderContext _context;
    CullingResults _cullingResults;
    Camera _cam;
    bool _useHDR, _useGPUInstancing;
    public void Setup(ScriptableRenderContext context, CullingResults result, 
        Camera camera, bool useHDR, bool useGPUInstancing)
    {
        _context = context;
        _cullingResults = result;
        _cam = camera;
        _useHDR = useHDR;
        _useGPUInstancing = useGPUInstancing;
    }
    public void Render()
    {
        _context.SetupCameraProperties(_cam);
        _buffer.GetTemporaryRT(depthNormalTextureId, _cam.pixelWidth, _cam.pixelHeight,
               0, FilterMode.Point, _useHDR ? RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default);
        _buffer.GetTemporaryRT(depthNormalAttachmentId, _cam.pixelWidth, _cam.pixelHeight,
              32, FilterMode.Point, _useHDR ? RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default);
        _buffer.GetTemporaryRT(depthBufferId, _cam.pixelWidth, _cam.pixelHeight, 
            32, FilterMode.Point, RenderTextureFormat.Depth);
        _buffer.SetRenderTarget(depthNormalAttachmentId,
            RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store, 
            depthBufferId,
            RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
        _buffer.ClearRenderTarget(true, true, Color.clear);
        _buffer.BeginSample(_bufferName);
        ExecuteBuffer();
        var sortingSettings = new SortingSettings(_cam)
        {
            criteria = SortingCriteria.CommonOpaque
        };
        var drawingSettings = new DrawingSettings(gBufferShaderTagId, sortingSettings)
        {
            enableInstancing = _useGPUInstancing,
        };
        var filteringSettings = new FilteringSettings(RenderQueueRange.opaque);

        _context.DrawRenderers(_cullingResults, ref drawingSettings, ref filteringSettings);
        _buffer.CopyTexture(depthNormalAttachmentId, depthNormalTextureId);
        _buffer.ReleaseTemporaryRT(depthBufferId);
        _buffer.ReleaseTemporaryRT(depthNormalAttachmentId);
        _buffer.EndSample(_bufferName);
        ExecuteBuffer();
    }
    //void DrawGBuffer(bool useGPUInstancing)
    //{
    //    var sortingSettings = new SortingSettings(_cam)
    //    {
    //        criteria = SortingCriteria.CommonOpaque
    //    };
    //    var drawingSettings = new DrawingSettings(gBufferShaderTagId, sortingSettings)
    //    {
    //        enableInstancing = useGPUInstancing,
    //    };
    //    var filteringSettings = new FilteringSettings(RenderQueueRange.opaque);

    //    _context.DrawRenderers(_cullingResults, ref drawingSettings, ref filteringSettings);
    //    _buffer.ReleaseTemporaryRT(depthNormalTextureId);
    //}
    //private void SetupGBuffer()
    //{
    //    CameraClearFlags flags = _cam.clearFlags;
    //    _context.SetupCameraProperties(_cam);
    //    _buffer.GetTemporaryRT(depthNormalTextureId, _cam.pixelWidth, _cam.pixelHeight,
    //           32, FilterMode.Point, _useHDR ? RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default);
    //    _buffer.SetRenderTarget(depthNormalTextureId, depthAttachmentId);
    //    _buffer.ClearRenderTarget(true, true, Color.clear);//clear render target before sample command group begins
    //    _buffer.BeginSample(SampleName);//This is useful for measuring CPU and GPU time spent by one or more commands in the command buffer.
    //    ExecuteBuffer();
    //}
    void ExecuteBuffer()
    {
        _context.ExecuteCommandBuffer(_buffer);
        _buffer.Clear();
    }
    public void Cleanup()
    {
        _buffer.ReleaseTemporaryRT(depthNormalTextureId);
    }
}
