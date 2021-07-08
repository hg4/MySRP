using UnityEngine;
using UnityEngine.Rendering;
using static PostFXSettings;
public partial class PostFXStack
{

	const string bufferName = "Post FX";

	CommandBuffer buffer = new CommandBuffer
	{
		name = bufferName
	};

	ScriptableRenderContext context;

	Camera camera;
    int colorLUTResolution;
    bool useHDR;
	PostFXSettings settings;
	public bool IsActive => settings != null;
	enum Pass
	{
		BloomHorizontal,
		BloomVertical,
		BloomAdd,
		BloomScatter,
		BloomScatterFinal,
		BloomPrefilter,
		BloomPrefilterFireflies,
		ColorGradingNone,
		ColorGradingReinhard,
		ColorGradingNeutral,
		ColorGradingACES,
		RimLight,
		Final,
		Copy,
		FXAA
	}
	const int maxBloomPyramidLevels = 16;
	int bloomPyramidId;
	int bloomBucibicUpsamplingId = Shader.PropertyToID("_BloomBicubicUpsampling"),
		fxSourceId = Shader.PropertyToID("_PostFXSource"),
		fxSource2Id = Shader.PropertyToID("_PostFXSource2"),
		cameraDepthNormalTextureId = Shader.PropertyToID("_CameraDepthNormalTexture0"),
		bloomThresholdId = Shader.PropertyToID("_BloomThreshold"),
		bloomPrefilterId = Shader.PropertyToID("_BloomPrefilter"),
        bloomResultId = Shader.PropertyToID("_BloomResult"),
        bloomIntensityId = Shader.PropertyToID("_BloomIntensity"),
		colorAdjustmentsId = Shader.PropertyToID("_ColorAdjustments"),
		colorFilterId = Shader.PropertyToID("_ColorFilter"),
		whiteBalanceId = Shader.PropertyToID("_WhiteBalance"),
		colorBalanceShadowsId = Shader.PropertyToID("_ColorBalanceShadows"),
		colorBalanceMidtonesId = Shader.PropertyToID("_ColorBalanceMidtones"),
		colorBalanceHighlightsId = Shader.PropertyToID("_ColorBalanceHighlights"),
		splitToningShadowsId = Shader.PropertyToID("_SplitToningShadows"),
		splitToningHighlightsId = Shader.PropertyToID("_SplitToningHighlights"),
		colorGradingLUTId = Shader.PropertyToID("_ColorGradingLUT"),
		colorGradingLUTParametersId = Shader.PropertyToID("_ColorGradingLUTParameters"),
		colorGradingLUTInLogId = Shader.PropertyToID("_ColorGradingLUTInLogC"),
		rimColorId = Shader.PropertyToID("_RimColor"),
		rimLengthId = Shader.PropertyToID("_RimLength"),
		rimWidthId = Shader.PropertyToID("_RimWidth"),
		rimFeatherId = Shader.PropertyToID("_RimFeather"),
		rimBlendId = Shader.PropertyToID("_RimBlend"),
		rimLightResultId = Shader.PropertyToID("_RimLightResult"),
		colorGradingResultId = Shader.PropertyToID("_ColorGradingResult"),
		fxaaConfigId = Shader.PropertyToID("_FXAAConfig"),
		fxaaResultId = Shader.PropertyToID("_FXAAResult");
	const string
	fxaaQualityLowKeyword = "FXAA_QUALITY_LOW",
	fxaaQualityMediumKeyword = "FXAA_QUALITY_MEDIUM";
	public PostFXStack()
	{
		bloomPyramidId = Shader.PropertyToID("_BloomPyramid0");
		for (int i = 1; i < maxBloomPyramidLevels * 2; i++)
		{
			Shader.PropertyToID("_BloomPyramid" + i);
		}
	}
	void DrawFinal(RenderTargetIdentifier from)
	{
		buffer.SetGlobalTexture(fxSourceId, from);
		buffer.SetRenderTarget(
			BuiltinRenderTextureType.CameraTarget,
			RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store
		);
		buffer.SetViewport(camera.pixelRect);
		buffer.Blit(from, BuiltinRenderTextureType.CameraTarget,
		settings.Material, (int)Pass.Final);
	}
	bool DoBloom(int sourceId)
	{
		PostFXSettings.BloomSettings bloom = settings.Bloom;
		int width = camera.pixelWidth / 2, height = camera.pixelHeight / 2;
		if (
			bloom.maxIterations == 0 || bloom.intensity <= 0f ||
			height < bloom.downscaleLimit || width < bloom.downscaleLimit
		)
		{
			return false;
		}
		buffer.BeginSample("Bloom");
		Vector4 threshold;
		threshold.x = Mathf.GammaToLinearSpace(bloom.threshold);
		threshold.y = threshold.x * bloom.thresholdKnee;
		threshold.z = 2f * threshold.y;
		threshold.w = 0.25f / (threshold.y + 0.00001f);
		threshold.y -= threshold.x;
		buffer.SetGlobalVector(bloomThresholdId, threshold);
		RenderTextureFormat format = useHDR ? RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default;
		buffer.GetTemporaryRT(
			bloomPrefilterId, width, height, 0, FilterMode.Bilinear, format
		);
		buffer.SetGlobalTexture(fxSourceId, sourceId);
		buffer.Blit(sourceId, bloomPrefilterId, settings.Material, bloom.fadeFireflies ?
				(int)Pass.BloomPrefilterFireflies : (int)Pass.BloomPrefilter);
		int fromId = bloomPrefilterId, toId = bloomPyramidId + 1;
		int i;
		for (i = 0; i < bloom.maxIterations; i++)
		{

			if (height < bloom.downscaleLimit || width < bloom.downscaleLimit)
			{
				break;
			}
			int midId = toId - 1;
			buffer.GetTemporaryRT(
				midId, width, height, 0, FilterMode.Bilinear, format
			);
			buffer.GetTemporaryRT(
				toId, width, height, 0, FilterMode.Bilinear, format
			);
			buffer.SetGlobalTexture(fxSourceId, fromId);
			buffer.Blit(fromId, midId,settings.Material,(int)Pass.BloomHorizontal);
			buffer.SetGlobalTexture(fxSourceId, midId);
			buffer.Blit(midId, toId, settings.Material, (int)Pass.BloomVertical);
			fromId = toId;
			toId += 2;
			width /= 2;
			height /= 2;
		}
		buffer.SetGlobalFloat(
			bloomBucibicUpsamplingId, bloom.bicubicUpsampling ? 1f : 0f
		);
		float finalIntensity;
		Pass combinePass, finalPass;
		if(bloom.mode == PostFXSettings.BloomSettings.Mode.Additive)
        {
			combinePass = finalPass = Pass.BloomAdd;
			buffer.SetGlobalFloat(bloomIntensityId, 1f);
			finalIntensity = bloom.intensity;
		}
		else
        {
			combinePass = Pass.BloomScatter;
			finalPass = Pass.BloomScatterFinal;
			buffer.SetGlobalFloat(bloomIntensityId, bloom.scatter);
			finalIntensity = Mathf.Min(bloom.intensity, 0.95f);
		}
		if (i > 1)
		{
			buffer.ReleaseTemporaryRT(fromId - 1);
			toId -= 5;
			for (i -= 1; i > 0; i--)
			{
				buffer.SetGlobalTexture(fxSource2Id, toId + 1);
				buffer.Blit(fromId, toId, settings.Material, (int)combinePass);
				buffer.ReleaseTemporaryRT(fromId);
				buffer.ReleaseTemporaryRT(toId + 1);
				fromId = toId;
				toId -= 2;
			}
		}
		else buffer.ReleaseTemporaryRT(bloomPyramidId);
		buffer.SetGlobalFloat(bloomIntensityId, finalIntensity);
		buffer.SetGlobalTexture(fxSource2Id, sourceId);
		buffer.GetTemporaryRT(
			bloomResultId, camera.pixelWidth, camera.pixelHeight, 0,
			FilterMode.Bilinear, format
		);
		buffer.Blit(fromId, bloomResultId,
			settings.Material, (int)finalPass);
		buffer.ReleaseTemporaryRT(fromId);
		buffer.EndSample("Bloom");
		return true;
	}
	void ConfigureWhiteBalance()
	{
		WhiteBalanceSettings whiteBalance = settings.ColorGrading.whiteBalanceSettings;
		buffer.SetGlobalVector(whiteBalanceId, ColorUtils.ColorBalanceToLMSCoeffs(
			whiteBalance.temperature, whiteBalance.tint
		));
	}
	void ConfigureColorBalance()
	{
		ColorBalanceSettings colorBalance = settings.ColorGrading.colorBalanceSettings;
		buffer.SetGlobalVector(colorBalanceShadowsId, colorBalance.shadows / 100.0f);
		buffer.SetGlobalVector(colorBalanceMidtonesId, colorBalance.midtones / 100.0f);
		buffer.SetGlobalVector(colorBalanceHighlightsId, colorBalance.highlights / 100.0f);
	}
	void ConfigureColorAdjustments()
	{
		ColorAdjustmentsSettings colorAdjustments = settings.ColorGrading.colorAdjustmentsSettings;
		buffer.SetGlobalVector(colorAdjustmentsId, new Vector4(
			Mathf.Pow(2f, colorAdjustments.postExposure),
			colorAdjustments.contrast * 0.01f + 1f,
			colorAdjustments.hueShift * (1f / 360f),
			colorAdjustments.saturation * 0.01f + 1f
		));
		buffer.SetGlobalColor(colorFilterId, colorAdjustments.colorFilter.linear);
	}
	void ConfigureRimLight()
    {
		RimLightSettings rimLight = settings.RimLight;
		buffer.SetGlobalColor(rimColorId,rimLight.rimColor);
		buffer.SetGlobalFloat(rimLengthId, rimLight.rimLength);
		buffer.SetGlobalFloat(rimWidthId, rimLight.rimWidth);
		buffer.SetGlobalFloat(rimFeatherId, rimLight.rimFeather);
		buffer.SetGlobalFloat(rimBlendId, rimLight.rimBlend);
	}
	void ConfigureFXAA()
	{
		if (settings.fxaa.quality == FXAA.Quality.Low)
		{
			buffer.EnableShaderKeyword(fxaaQualityLowKeyword);
			buffer.DisableShaderKeyword(fxaaQualityMediumKeyword);
		}
		else if (settings.fxaa.quality == FXAA.Quality.Medium)
		{
			buffer.DisableShaderKeyword(fxaaQualityLowKeyword);
			buffer.EnableShaderKeyword(fxaaQualityMediumKeyword);
		}
		else
		{
			buffer.DisableShaderKeyword(fxaaQualityLowKeyword);
			buffer.DisableShaderKeyword(fxaaQualityMediumKeyword);
		}
		buffer.SetGlobalVector(fxaaConfigId, new Vector4(
			settings.fxaa.fixedThreshold, settings.fxaa.relativeThreshold, 
			settings.fxaa.subpixelBlending
		));
	}

	void DoColorGradingAndToneMapping(int sourceId)
	{
		ConfigureColorAdjustments();
		ConfigureWhiteBalance();
		ConfigureColorBalance();
		ConfigureSplitToning();
		int lutHeight = colorLUTResolution;
		int lutWidth = lutHeight * lutHeight;
		buffer.GetTemporaryRT(
			colorGradingLUTId, lutWidth, lutHeight, 0,
			FilterMode.Bilinear, RenderTextureFormat.DefaultHDR
		);
		buffer.SetGlobalVector(colorGradingLUTParametersId, new Vector4(
			lutHeight, 0.5f / lutWidth, 0.5f / lutHeight, lutHeight / (lutHeight - 1f)
		));
		ToneMappingSettings.Mode mode = settings.ColorGrading.toneMappingSettings.mode;
		Pass pass = Pass.ColorGradingNone + (int)mode;
		buffer.SetGlobalFloat(
			colorGradingLUTInLogId, useHDR && pass != Pass.ColorGradingNone ? 1f : 0f
		);
		buffer.SetGlobalTexture(fxSourceId, sourceId);
		buffer.Blit(sourceId, colorGradingLUTId,
		settings.Material, (int)pass);
		buffer.SetGlobalVector(colorGradingLUTParametersId,
			new Vector4(1f / lutWidth, 1f / lutHeight, lutHeight - 1f)
		);
		buffer.SetGlobalTexture(fxSourceId, sourceId);
        RenderTextureFormat format = useHDR ? RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default;
        buffer.GetTemporaryRT(
		colorGradingResultId, camera.pixelWidth, camera.pixelHeight, 0,
		FilterMode.Bilinear, format,RenderTextureReadWrite.Default, 4
		);
		buffer.Blit(sourceId, colorGradingResultId, settings.Material, (int)Pass.Final);
        //buffer.Blit(sourceId, BuiltinRenderTextureType.CameraTarget,settings.Material, (int)Pass.Final);
        buffer.ReleaseTemporaryRT(colorGradingLUTId);
	}
	void DoRimLight(int sourceId)
    {
		ConfigureRimLight();
		buffer.SetGlobalTexture(cameraDepthNormalTextureId, BuiltinRenderTextureType.Depth);
		buffer.SetGlobalTexture(fxSourceId, sourceId);
		RenderTextureFormat format = useHDR ? RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default;
		buffer.GetTemporaryRT(
		rimLightResultId, camera.pixelWidth, camera.pixelHeight, 0,
		FilterMode.Bilinear, format, RenderTextureReadWrite.Default, 4);
		buffer.Blit(sourceId, rimLightResultId, settings.Material, (int)Pass.RimLight);

	}
	void DoFXAA(int sourceId)
    {
		ConfigureFXAA();
		RenderTextureFormat format = useHDR ? RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default;
		buffer.SetGlobalTexture(fxSourceId, sourceId);
		buffer.GetTemporaryRT(
			fxaaResultId, camera.pixelWidth, camera.pixelHeight, 0,
			FilterMode.Bilinear, format,RenderTextureReadWrite.Default,4
		);
		buffer.Blit(sourceId, fxaaResultId, settings.Material, (int)Pass.FXAA);
	}
	void ConfigureSplitToning()
	{
		SplitToningSettings splitToning = settings.ColorGrading.splitToningSettings;
		Color splitColor = splitToning.shadows;
		splitColor.a = splitToning.balance * 0.01f;
		buffer.SetGlobalColor(splitToningShadowsId, splitColor);
		buffer.SetGlobalColor(splitToningHighlightsId, splitToning.highlights);
	}

	public void Setup(
		ScriptableRenderContext context, Camera camera, PostFXSettings settings,
		bool useHDR, int colorLUTResolution)
	{
		this.useHDR = useHDR;
		this.context = context;
		this.camera = camera;
		this.colorLUTResolution = colorLUTResolution;
		this.settings = camera.cameraType <= CameraType.SceneView ? settings : null;
		ApplySceneViewState();
	}
	public void Render(int sourceId)
	{
		//buffer.Blit(sourceId, BuiltinRenderTextureType.CameraTarget,
		//	settings.Material,(int)Pass.Copy);
		int temp = sourceId;
		if (settings.rimLight.enableRim)
		{
			DoRimLight(temp);
			temp = rimLightResultId;
		}
		if (settings.Bloom.enableBloom)
        {
			DoBloom(temp);
			temp = bloomResultId;
		}
		if(settings.ColorGrading.enableColorGrading)
        {
			DoColorGradingAndToneMapping(temp);
			temp = colorGradingResultId;
		}
		if(settings.fxaa.enabled)
        {
			DoFXAA(temp);
			temp = fxaaResultId;
        }
		buffer.SetGlobalTexture(fxSourceId, temp);
		buffer.Blit(temp, BuiltinRenderTextureType.CameraTarget,settings.Material,(int)Pass.Copy);
		Cleanup();
        //buffer.ReleaseTemporaryRT(midResultId);
		context.ExecuteCommandBuffer(buffer);
		buffer.Clear();
	}
	public void Cleanup()
    {
		if (settings.Bloom.enableBloom)
			buffer.ReleaseTemporaryRT(bloomResultId);
		if (settings.ColorGrading.enableColorGrading)
			buffer.ReleaseTemporaryRT(colorGradingLUTId);
		if (settings.rimLight.enableRim)
			buffer.ReleaseTemporaryRT(rimLightResultId);
		if (settings.fxaa.enabled)
			buffer.ReleaseTemporaryRT(fxaaResultId);
	}

}