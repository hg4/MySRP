using UnityEngine;
using System;
[CreateAssetMenu(menuName = "Rendering/Custom Post FX Settings")]
public class PostFXSettings : ScriptableObject
{
	[SerializeField]
	Shader shader = default;
	[System.NonSerialized]
	Material material;
	[System.Serializable]
	public struct BloomSettings
	{

		[Range(0f, 16f)]
		public int maxIterations;
		public bool bicubicUpsampling;
		[Min(1f)]
		public int downscaleLimit;
		[Min(0f)]
		public float threshold;
		[Range(0f, 1f)]
		public float thresholdKnee;
		[Min(0f)]
		public float intensity;
		public bool fadeFireflies;
		public enum Mode { Additive, Scattering }

		public Mode mode;

		[Range(0.05f, 0.95f)]
		public float scatter;
	}
	[Serializable]
	public struct ToneMappingSettings
	{

		public enum Mode { None, Reinhard, Neutral, ACES }

		public Mode mode;
	}

	[SerializeField]
	ToneMappingSettings toneMapping = default;

	public ToneMappingSettings ToneMapping => toneMapping;
	[SerializeField]
	BloomSettings bloom = new BloomSettings
	{
		scatter = 0.07f
	};
	public BloomSettings Bloom => bloom;
	public Material Material
	{
		get
		{
			if (material == null && shader != null)
			{
				material = new Material(shader);
				material.hideFlags = HideFlags.HideAndDontSave;
			}
			return material;
		}
	}
	[Serializable]
	public struct ColorAdjustmentsSettings
	{
		public float postExposure;

		[Range(-100f, 100f)]
		public float contrast;

		[ColorUsage(false, true)]
		public Color colorFilter;

		[Range(-180f, 180f)]
		public float hueShift;

		[Range(-100f, 100f)]
		public float saturation;
	}

	[SerializeField]
	ColorAdjustmentsSettings colorAdjustments = new ColorAdjustmentsSettings
	{
		colorFilter = Color.white
	};

	public ColorAdjustmentsSettings ColorAdjustments => colorAdjustments;

	[Serializable]
	public struct WhiteBalanceSettings
	{

		[Range(-100f, 100f)]
		public float temperature, tint;
	}

	[SerializeField]
	WhiteBalanceSettings whiteBalance = default;

	public WhiteBalanceSettings WhiteBalance => whiteBalance;

	[Serializable]
	public struct ColorBalanceSettings
	{
		public Vector3 shadows, midtones, highlights;
	}

	[SerializeField]
	ColorBalanceSettings colorBalance = default;
	public ColorBalanceSettings ColorBalance => colorBalance;

	[Serializable]
	public struct SplitToningSettings
	{

		[ColorUsage(false)]
		public Color shadows, highlights;

		[Range(-100f, 100f)]
		public float balance;
	}

	[SerializeField]
	SplitToningSettings splitToning = new SplitToningSettings
	{
		shadows = Color.gray,
		highlights = Color.gray
	};

	public SplitToningSettings SplitToning => splitToning;
}