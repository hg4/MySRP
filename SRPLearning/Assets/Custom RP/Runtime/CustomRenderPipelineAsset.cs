using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[CreateAssetMenu(menuName = "Rendering/My Custom Render Pipeline")]
public class CustomRenderPipelineAsset : RenderPipelineAsset
{
    // Start is called before the first frame update
    protected override RenderPipeline CreatePipeline()
    {
        return new CustomRenderingPipeline();
    }
}
