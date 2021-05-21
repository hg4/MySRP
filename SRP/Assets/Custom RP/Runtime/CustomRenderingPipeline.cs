using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
public partial class CustomRenderingPipeline : RenderPipeline
{
    bool _useGPUInstancing;
    bool _useLightsPerObject;
    bool _allowHDR;
    int _colorLUTResolution;
    CameraRenderer _renderer = new CameraRenderer();
    ShadowSettings _shadowSettings;
    PostFXSettings _postFXSettings;
    public CustomRenderingPipeline(bool allowHDR, bool useGPUInstancing,bool useSRPBatcher, bool useLightsPerObject,
 ShadowSettings shadowSettings, PostFXSettings postFXSettings, int colorLUTResolution)
    {
        _allowHDR = allowHDR;
        _useGPUInstancing = useGPUInstancing;
        _colorLUTResolution = colorLUTResolution;
        GraphicsSettings.useScriptableRenderPipelineBatching = useSRPBatcher;
        GraphicsSettings.lightsUseLinearIntensity = true;
        _useLightsPerObject = useLightsPerObject;
        _shadowSettings = shadowSettings;
        _postFXSettings = postFXSettings;
        InitializeForEditor();
    }
    protected override void Render(ScriptableRenderContext context, Camera[] cameras)
    {
        foreach(Camera camera in cameras)
        {
            _renderer.Render(context, camera,_allowHDR,_useGPUInstancing,
                _useLightsPerObject,_shadowSettings,_postFXSettings, _colorLUTResolution);
        }
    }

}
