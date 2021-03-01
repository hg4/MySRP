using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
public class CameraRenderer
{
    ScriptableRenderContext _context;
    Camera _cam;
    public void Render(ScriptableRenderContext context,Camera camera)
    {
        _context = context;
        _cam = camera;
        Setup();//init some status in context
        DrawVisibleGeometry();//draw command in context
        Submit();//submit buffered command in context
    }

    private void Setup()
    {
        _context.SetupCameraProperties(_cam);//set camera VP matrix to context status
    }

    private void Submit()
    {
        _context.Submit();
    }

    void DrawVisibleGeometry()
    {
        _context.DrawSkybox(_cam);
    }
}
