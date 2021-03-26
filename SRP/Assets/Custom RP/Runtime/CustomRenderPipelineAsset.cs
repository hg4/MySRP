using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[CreateAssetMenu(menuName = "Rendering/My Custom Render Pipeline")]
public class CustomRenderPipelineAsset : RenderPipelineAsset
{
    // Start is called before the first frame update
    public bool useGPUInstancing=true, useSRPBatcher=true;
    public ShadowSettings shadows = default;
    protected override RenderPipeline CreatePipeline()
    {
        return new CustomRenderingPipeline(useGPUInstancing,useSRPBatcher, shadows);
    }
}
