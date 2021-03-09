using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MeshBall : MonoBehaviour
{
    static int baseColorId = Shader.PropertyToID("_BaseColor");

    public Mesh mesh = default;
    public Material material = default;
    Matrix4x4[] _matrices = new Matrix4x4[1023];
    Vector4[] _basicColors = new Vector4[1023];
    MaterialPropertyBlock _block;

    private void Awake()
    {
        for(int i = 0; i < _matrices.Length; i++)
        {
            _matrices[i] = Matrix4x4.TRS(Random.insideUnitSphere*10.0f, Quaternion.identity, Vector3.one);
            _basicColors[i] = new Vector4(Random.value, Random.value, Random.value,Random.value);
        }
    }
    private void Update()
    {
        if (_block == null)
        {
            _block = new MaterialPropertyBlock();
            _block.SetVectorArray(baseColorId, _basicColors);
        }
        Graphics.DrawMeshInstanced(mesh, 0, material, _matrices,1023,_block);
    }
}
