using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[DisallowMultipleComponent]
public class PerObjectMaterialProperties : MonoBehaviour
{
    static int _baseColorId = Shader.PropertyToID("_Color");
    static int _cutOffId = Shader.PropertyToID("_CutOff");
    static int _metallicId = Shader.PropertyToID("_Metallic");
    static int _roughnessId = Shader.PropertyToID("_Roughness");
    static int _EmissionId = Shader.PropertyToID("_EmissionColor");
    [SerializeField]
    Color _baseColor = Color.black;
    [SerializeField,Range(0.0f,1.0f)]
    float _cutOff = 0.5f;
    [SerializeField, Range(0.0f, 1.0f)]
    float _metallic = 0.1f;
    [SerializeField, Range(0.0f, 1.0f)]
    float _roughness = 0.5f;
    [SerializeField, ColorUsage(false, true)]
    Color _emissionColor = Color.black;
    static MaterialPropertyBlock _block;

    private void Awake()
    {
        OnValidate();
    }
    private void OnValidate()
    {
        //invoked when component is loaded or changed.
        if (_block == null)
        {
            _block = new MaterialPropertyBlock();
        }
        _block.SetColor(_baseColorId, _baseColor);
        _block.SetColor(_EmissionId, _emissionColor);
        _block.SetFloat(_cutOffId, _cutOff);
        _block.SetFloat(_metallicId, _metallic);
        _block.SetFloat(_roughnessId, _roughness);
        GetComponent<Renderer>().SetPropertyBlock(_block);
    }
}
