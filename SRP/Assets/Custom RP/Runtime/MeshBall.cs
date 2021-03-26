using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MeshBall : MonoBehaviour
{
    static int baseColorId = Shader.PropertyToID("_BaseColor");
    static int metallicId = Shader.PropertyToID("_Metallic");
    static int roughnessId = Shader.PropertyToID("_Roughness");
    public Mesh mesh = default;
    public Material material = default;
    Matrix4x4[] _matrices = new Matrix4x4[1023];
    Vector4[] _basicColors = new Vector4[1023];
    float[] _metallics = new float[1023];
    float[] _roughness = new float[1023];
    MaterialPropertyBlock _block;

    private void Awake()
    {
        for(int i = 0; i < _matrices.Length; i++)
        {
            _matrices[i] = Matrix4x4.TRS(Random.insideUnitSphere*10.0f, Quaternion.identity, Vector3.one);
            _basicColors[i] = new Vector4(Random.value, Random.value, Random.value,Random.value);
            _metallics[i] = Random.value < 0.25f ? 1f : 0f;
            _roughness[i] = Random.Range(0.05f, 0.95f);
        }
    }
    private void Update()
    {
        if (_block == null)
        {
            _block = new MaterialPropertyBlock();
            _block.SetVectorArray(baseColorId, _basicColors);
            _block.SetFloatArray(metallicId, _metallics);
            _block.SetFloatArray(roughnessId, _roughness);
        }
        Graphics.DrawMeshInstanced(mesh, 0, material, _matrices,1023,_block);
    }
}
