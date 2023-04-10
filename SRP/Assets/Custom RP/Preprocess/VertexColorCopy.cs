using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class VertexColorCopy : MonoBehaviour
{
    public Mesh originMesh;
    public Mesh colorMesh;

    private void OnEnable()
    {
        if (originMesh == null || colorMesh == null)
            return;
        originMesh.normals = colorMesh.normals;
    }
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
