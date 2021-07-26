using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu]
public class CustomGradientForEditor : ScriptableObject
{
    public CustomGradient gradient;
    public static CustomGradientForEditor CreateAsset()
    {
        CustomGradientForEditor asset = ScriptableObject.CreateInstance<CustomGradientForEditor>();

        UnityEditor.AssetDatabase.CreateAsset(asset, "Assets/CustomData.asset");
        UnityEditor.AssetDatabase.SaveAssets();
        return asset;
    }

}
