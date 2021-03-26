using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
public class CustomRenderingPipeline : RenderPipeline
{
    bool _useGPUInstancing;
    CameraRenderer _renderer = new CameraRenderer();
    ShadowSettings _shadowSettings;
    public CustomRenderingPipeline(bool useGPUInstancing,bool useSRPBatcher, ShadowSettings shadowSettings)
    {
        this._useGPUInstancing = useGPUInstancing;
        GraphicsSettings.useScriptableRenderPipelineBatching = useSRPBatcher;
        GraphicsSettings.lightsUseLinearIntensity = true;
        _shadowSettings = shadowSettings;
    }
    protected override void Render(ScriptableRenderContext context, Camera[] cameras)
    {
        foreach(Camera camera in cameras)
        {
            _renderer.Render(context, camera,_useGPUInstancing,_shadowSettings);
        }
    }

}
