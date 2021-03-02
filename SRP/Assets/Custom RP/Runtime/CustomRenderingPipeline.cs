using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
public class CustomRenderingPipeline : RenderPipeline
{
    CameraRenderer _renderer = new CameraRenderer();
    protected override void Render(ScriptableRenderContext context, Camera[] cameras)
    {
        foreach(Camera camera in cameras)
        {
            _renderer.Render(context, camera);
        }
    }

}
