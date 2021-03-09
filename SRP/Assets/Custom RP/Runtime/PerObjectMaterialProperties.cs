using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[DisallowMultipleComponent]
public class PerObjectMaterialProperties : MonoBehaviour
{
    static int _baseColorId = Shader.PropertyToID("_BaseColor");
    static int _cutOffId = Shader.PropertyToID("_CutOff");
    [SerializeField]
    Color _baseColor = Color.white;
    [SerializeField,Range(0.0f,1.0f)]
    float _cutOff = 0.5f;
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
        _block.SetFloat(_cutOffId, _cutOff);
        GetComponent<Renderer>().SetPropertyBlock(_block);
    }
}
