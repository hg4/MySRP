using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[System.Serializable]
public struct DegradedRectangle
{
    public int vertex1;// 构成边的顶点1的索引
    public int vertex2;// 构成边的顶点2的索引
    public int triangle1_vertex3;// 边所在三角面1的顶点3索引
    public int triangle2_vertex3;// 边所在三角面2的顶点3索引
}

public class RectangleAsset : ScriptableObject
{
    public Mesh mesh;
    public List<DegradedRectangle> degradedRectangles = new List<DegradedRectangle>();
    public void Cleanup()
    {
        mesh.Clear();
        degradedRectangles.Clear();
    }
}
