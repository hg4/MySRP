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
		Final
	}
	const int maxBloomPyramidLevels = 16;
	int bloomPyramidId;
	int bloomBucibicUpsamplingId = Shader.PropertyToID("_BloomBicubicUpsampling"),
		fxSourceId = Shader.PropertyToID("_PostFXSource"),
		fxSource2Id = Shader.PropertyToID("_PostFXSource2"),
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
		colorGradingLUTInLogId = Shader.PropertyToID("_ColorGradingLUTInLogC");
		
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
		WhiteBalanceSettings whiteBalance = settings.WhiteBalance;
		buffer.SetGlobalVector(whiteBalanceId, ColorUtils.ColorBalanceToLMSCoeffs(
			whiteBalance.temperature, whiteBalance.tint
		));
	}
	void ConfigureColorBalance()
	{
		ColorBalanceSettings colorBalance = settings.ColorBalance;
		buffer.SetGlobalVector(colorBalanceShadowsId, colorBalance.shadows / 100.0f);
		buffer.SetGlobalVector(colorBalanceMidtonesId, colorBalance.midtones / 100.0f);
		buffer.SetGlobalVector(colorBalanceHighlightsId, colorBalance.highlights / 100.0f);
	}
	void ConfigureColorAdjustments()
	{
		ColorAdjustmentsSettings colorAdjustments = settings.ColorAdjustments;
		buffer.SetGlobalVector(colorAdjustmentsId, new Vector4(
			Mathf.Pow(2f, colorAdjustments.postExposure),
			colorAdjustments.contrast * 0.01f + 1f,
			colorAdjustments.hueShift * (1f / 360f),
			colorAdjustments.saturation * 0.01f + 1f
		));
		buffer.SetGlobalColor(colorFilterId, colorAdjustments.colorFilter.linear);
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
		ToneMappingSettings.Mode mode = settings.ToneMapping.mode;
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
		buffer.Blit(sourceId, BuiltinRenderTextureType.CameraTarget,settings.Material, (int)Pass.Final);
		buffer.ReleaseTemporaryRT(colorGradingLUTId);
	}
	void ConfigureSplitToning()
	{
		SplitToningSettings splitToning = settings.SplitToning;
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
		if (DoBloom(sourceId))
		{
			DoColorGradingAndToneMapping(bloomResultId);
			buffer.ReleaseTemporaryRT(bloomResultId);
		}
		else
		{
			DoColorGradingAndToneMapping(sourceId);
		}
		context.ExecuteCommandBuffer(buffer);
		buffer.Clear();
	}

}