using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[CreateAssetMenu(menuName = "Rendering/My Custom Render Pipeline")]
public class CustomRenderPipelineAsset : RenderPipelineAsset
{
    // Start is called before the first frame update
    public bool useGPUInstancing = true, useSRPBatcher=true,
        useLightsPerObject = false;
    public ShadowSettings shadows = default;
    [SerializeField]
    PostFXSettings postFXSettings = default;
    [SerializeField]
    bool allowHDR = true;
    public enum ColorLUTResolution { _16 = 16, _32 = 32, _64 = 64 }
    [SerializeField]
    MSAASamples MSAA = MSAASamples.None;
    [SerializeField]
    ColorLUTResolution colorLUTResolution = ColorLUTResolution._32;
    protected override RenderPipeline CreatePipeline()  
    {               
        return new CustomRenderingPipeline(allowHDR, useGPUInstancing,useSRPBatcher,
            useLightsPerObject, shadows, postFXSettings, (int)colorLUTResolution,(int)MSAA);
    }
}
