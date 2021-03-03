using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
public partial class CameraRenderer
{
    ScriptableRenderContext _context;
    Camera _cam;
    const string _bufferName = "Render camera";
    CommandBuffer _buffer = new CommandBuffer { name = _bufferName };
    CullingResults _cullingResults;
    static ShaderTagId unlitShaderTagId = new ShaderTagId("SRPDefaultUnlit");
  
    public void Render(ScriptableRenderContext context,Camera camera)
    {
        _context = context;
        _cam = camera;
        PrepareBuffer();
        PrepareForSceneWindow();
        if (!TryCull()) return;
        Setup();//init some status in context
        DrawVisibleGeometry();//draw command in context
        DrawGizmos();//draw Gizmos when actived after everything else
        Submit();//submit buffered command in context
    }

    private void Setup()
    {
        CameraClearFlags flags = _cam.clearFlags;
        _context.SetupCameraProperties(_cam);//set camera VP matrix to context status,we should setup camera before
                                             //renderTarget clear because renderTarget is bind with camera
        //to use secondary camera only to show legacy shader object, we determines whether clear renderTarget by camera's clear flag,which get different mixed effect by two camera.
        _buffer.ClearRenderTarget(flags <= CameraClearFlags.Depth, flags == CameraClearFlags.Color,
                flags == CameraClearFlags.Color ? _cam.backgroundColor.linear : Color.clear);//clear render target before sample command group begins
        _buffer.BeginSample(SampleName);//a function adding command to buffer,which named a sample command group
        ExecuteBuffer();
        
    }
    void DrawVisibleGeometry()
    {
        var filteringSettings = new FilteringSettings(RenderQueueRange.opaque);
        var sortingSettings = new SortingSettings(_cam)
        {
            criteria = SortingCriteria.CommonOpaque
        };
        var drawingSettings = new DrawingSettings(
            unlitShaderTagId, sortingSettings
        );
        _context.DrawRenderers(_cullingResults,ref drawingSettings, ref filteringSettings);
        DrawUnsupportedShaders();
        _context.DrawSkybox(_cam);
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

   

    bool TryCull()
    {
        //try to get parameter and culling, Returns false if camera is invalid to render (empty viewport rectangle, invalid clip plane setup etc.).
        if (_cam.TryGetCullingParameters(out ScriptableCullingParameters p))
        {
            _cullingResults = _context.Cull(ref p);
            //ref keyword can treat as pointer in C++,which pass parameter's reference,
            //here parameter p is a reference type(treat as pointer),so ref p means pointer's pointer classtype** p.
            //out keyword is similar to ref keyword,which means input a uninit parameter's reference,you can init this parameter
            //and modify in function.
            return true;
        }
        return false;
    }
}
