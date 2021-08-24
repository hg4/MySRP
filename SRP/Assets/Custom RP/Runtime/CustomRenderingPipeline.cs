using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
public partial class CustomRenderingPipeline : RenderPipeline
{
    ScriptableRenderContext scriptableRenderContext;
    bool _useGPUInstancing;
    bool _useLightsPerObject;
    bool _allowHDR;
    int _colorLUTResolution;
    int _msaaSamples;
    CameraRenderer _renderer = new CameraRenderer();
    ShadowSettings _shadowSettings;
    PostFXSettings _postFXSettings;
    public CustomRenderingPipeline(bool allowHDR, bool useGPUInstancing,bool useSRPBatcher, bool useLightsPerObject,
 ShadowSettings shadowSettings, PostFXSettings postFXSettings, int colorLUTResolution, int msaaSamples)
    {
        _allowHDR = allowHDR;
        _useGPUInstancing = useGPUInstancing;
        _colorLUTResolution = colorLUTResolution;
        _msaaSamples = msaaSamples;
        GraphicsSettings.useScriptableRenderPipelineBatching = useSRPBatcher;
        GraphicsSettings.lightsUseLinearIntensity = true;
        _useLightsPerObject = useLightsPerObject;
        _shadowSettings = shadowSettings;
        _postFXSettings = postFXSettings;
        InitializeForEditor();
    }
    protected override void Render(ScriptableRenderContext context, Camera[] cameras)
    {
        scriptableRenderContext = context;
        BeginFrameRendering(context, cameras);
        foreach(Camera camera in cameras)
        {
            BeginCameraRendering(context, camera);
            _renderer.Render(context, camera,_allowHDR,_useGPUInstancing,
                _useLightsPerObject,_shadowSettings,_postFXSettings, _colorLUTResolution,_msaaSamples);
            EndCameraRendering(context, camera);
        }
        EndFrameRendering(context,cameras);
    }

}
