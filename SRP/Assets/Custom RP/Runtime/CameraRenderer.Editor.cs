using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
partial class CameraRenderer
{
    partial void PrepareBuffer();
    partial void PrepareForSceneWindow();
    partial void DrawUnsupportedShaders();
    partial void DrawGizmos();
#if UNITY_EDITOR
    static ShaderTagId[] legacyShaderTagIds = {
        new ShaderTagId("Always"),
        new ShaderTagId("ForwardBase"),
        new ShaderTagId("PrepassBase"),
        new ShaderTagId("Vertex"),
        new ShaderTagId("VertexLMRGBM"),
        new ShaderTagId("VertexLM")
    };
    static Material errorMaterial;
#endif
#if UNITY_EDITOR
    string SampleName { get; set; }
    partial void PrepareBuffer()
    {
        _buffer.name = SampleName = _cam.name;
    }
#else
    const string SampleName = _bufferName;
#endif

#if UNITY_EDITOR
    partial void DrawGizmos()
    {
        if (Handles.ShouldRenderGizmos())
        {
            _context.DrawGizmos(_cam, GizmoSubset.PreImageEffects);
            _context.DrawGizmos(_cam, GizmoSubset.PostImageEffects);
        }
    }
    partial void PrepareForSceneWindow()
    {
        if (_cam.cameraType == CameraType.SceneView)
        {
            ScriptableRenderContext.EmitWorldGeometryForSceneView(_cam);
        }
    }
    partial void DrawUnsupportedShaders()
    {
        if (errorMaterial == null)
        {
            errorMaterial =
                new Material(Shader.Find("Hidden/InternalErrorShader"));
        }
        var drawingSettings = new DrawingSettings(
            legacyShaderTagIds[0], new SortingSettings(_cam)
        )
        {
            overrideMaterial = errorMaterial
        };
        for (int i = 1; i < legacyShaderTagIds.Length; i++)
        {
            drawingSettings.SetShaderPassName(i, legacyShaderTagIds[i]);
        }
        var filteringSettings = FilteringSettings.defaultValue;
        _context.DrawRenderers(
            _cullingResults, ref drawingSettings, ref filteringSettings
        );
    }
#endif
}
