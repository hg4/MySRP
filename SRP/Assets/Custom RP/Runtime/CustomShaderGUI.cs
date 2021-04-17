using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;
public class CustomShaderGUI : ShaderGUI
{
	MaterialEditor editor;
	Object[] materials;
	MaterialProperty[] properties;
	bool showPresets;
	enum ShadowMode
	{
		On, Clip, Dither, Off
	}

	ShadowMode Shadows
	{
		set
		{
			if (SetProperty("_Shadows", (float)value))
			{
				SetKeyword("_SHADOWS_CLIP", value == ShadowMode.Clip);
				SetKeyword("_SHADOWS_DITHER", value == ShadowMode.Dither);
			}
		}
	}
	public override void OnGUI(
		MaterialEditor materialEditor, MaterialProperty[] properties
	)
	{
		EditorGUI.BeginChangeCheck();
		base.OnGUI(materialEditor, properties);
		editor = materialEditor;
		materials = materialEditor.targets;
		this.properties = properties;
		BakedEmission();
		EditorGUILayout.Space();
		showPresets = EditorGUILayout.Foldout(showPresets, "Presets", true);
		if (showPresets)
		{
			OpaquePreset();
			ClipPreset();
			FadePreset();
			TransparentPreset();
		}
		if (EditorGUI.EndChangeCheck())
		{
			SetShadowCasterPass();
		}
	}
	void BakedEmission()
	{
		EditorGUI.BeginChangeCheck();
		editor.LightmapEmissionProperty();
		if (EditorGUI.EndChangeCheck())
		{
			foreach (Material m in editor.targets)
			{
				m.globalIlluminationFlags &=
					~MaterialGlobalIlluminationFlags.EmissiveIsBlack;
			}
		}
	}
	private void SetShadowCasterPass()
    {
		MaterialProperty shadows = FindProperty("_Shadows", properties, false);
		if (shadows == null || shadows.hasMixedValue)
		{
			return;
		}
		bool enabled = shadows.floatValue < (float)ShadowMode.Off;
		foreach (Material m in materials)
		{
			m.SetShaderPassEnabled("ShadowCaster", enabled);
		}
	}

    bool SetProperty(string name, float value)
	{
		MaterialProperty property = FindProperty(name, properties, false);
		if (property != null)
		{
			property.floatValue = value;
			return true;
		}
		return false;
	}
	void SetProperty(string name, string keyword, bool value)
	{
		if(SetProperty(name, value ? 1f : 0f))
			SetKeyword(keyword, value);
	}

	void SetKeyword(string keyword, bool enabled)
	{
		if (enabled)
		{
			foreach (Material m in materials)
			{
				m.EnableKeyword(keyword);
			}
		}
		else
		{
			foreach (Material m in materials)
			{
				m.DisableKeyword(keyword);
			}
		}
	}

	bool Clipping
	{
		set => SetProperty("_Clipping", "_CLIPPING", value);
	}

	bool PremultiplyAlpha
	{
		set => SetProperty("_PremultiAlpha", "_PREMULTI_ALPHA", value);
	}

	BlendMode SrcBlend
	{
		set => SetProperty("_SrcBlend", (float)value);
	}

	BlendMode DstBlend
	{
		set => SetProperty("_DstBlend", (float)value);
	}

	bool ZWrite
	{
		set => SetProperty("_ZWrite", value ? 1f : 0f);
	}
	RenderQueue RenderQueue
	{
		set
		{
			foreach (Material m in materials)
			{
				m.renderQueue = (int)value;
			}
		}
	}
	bool PresetButton(string name)
	{
		if (GUILayout.Button(name))
		{
			editor.RegisterPropertyChangeUndo(name);
			return true;
		}
		return false;
	}

	void OpaquePreset()
	{
		if (PresetButton("Opaque"))
		{
			Clipping = false;
			PremultiplyAlpha = false;
			SrcBlend = BlendMode.One;
			DstBlend = BlendMode.Zero;
			Shadows = ShadowMode.On;
			ZWrite = true;
			RenderQueue = RenderQueue.Geometry;
		}
	}
	void ClipPreset()
	{
		if (PresetButton("Clip"))
		{
			Clipping = true;
			PremultiplyAlpha = false;
			SrcBlend = BlendMode.One;
			DstBlend = BlendMode.Zero;
			ZWrite = true;
			Shadows = ShadowMode.Clip;
			RenderQueue = RenderQueue.AlphaTest;
		}
	}
	void FadePreset()
	{
		if (PresetButton("Fade"))
		{
			Clipping = false;
			PremultiplyAlpha = false;
			SrcBlend = BlendMode.SrcAlpha;
			DstBlend = BlendMode.OneMinusSrcAlpha;
			ZWrite = false;
			Shadows = ShadowMode.Dither;
			RenderQueue = RenderQueue.Transparent;
		}
	}
	void TransparentPreset()
	{
		if (PresetButton("Transparent"))
		{
			Clipping = false;
			PremultiplyAlpha = true;
			SrcBlend = BlendMode.One;
			DstBlend = BlendMode.OneMinusSrcAlpha;
			Shadows = ShadowMode.Dither;
			ZWrite = false;
			RenderQueue = RenderQueue.Transparent;
		}
	}
}
