using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System;

public class DegradedRectanglesGenerator : MonoBehaviour
{
    private class MeshLine
    {
        public Vector3 v1;
        public Vector3 v2;
        public DegradedRectangle belongRectangle;
        public MeshLine(int index1, int index2,Vector3 v1,Vector3 v2)
        {
            this.v1 = v1;
            this.v2 = v2;
            belongRectangle = new DegradedRectangle();
            belongRectangle.vertex1 = index1;
            belongRectangle.vertex2 = index2;
        }
        public override bool Equals(object obj)
        {
            if (obj == null || obj.GetType() != GetType())
            {
                return false;
            }
            MeshLine line = (MeshLine)obj;
            if (line.v1 == v1 && line.v2 == v2)
            {
                return true;
            }
            if (line.v2 == v1 && line.v1 == v2)
            {
                return true;
            }
            return false;
        }
        public override int GetHashCode()
        {
            return base.GetHashCode();
        }
        public static bool operator ==(MeshLine line1,MeshLine line2)
        {
            return line1.Equals(line2);
        }
        public static bool operator !=(MeshLine line1, MeshLine line2)
        {
            return !line1.Equals(line2);
        }
    }
    //private static RectangleAsset m_rectangleAsset = new RectangleAsset();
    //private static List<MeshLine> m_lines = new List<MeshLine>();
    private static GameObject go;
    [MenuItem("Tools/预处理Mesh")]
    public static void GenerateMeshDegradedRectanglesTool()
    {
        go = Selection.activeGameObject;
        MeshFilter[] meshFilters = go.GetComponentsInChildren<MeshFilter>();
        
        foreach (var meshFilter in meshFilters)
        {
            RectangleAsset rectangleAsset = new RectangleAsset();
            Mesh mesh = meshFilter.sharedMesh;
            rectangleAsset.mesh = mesh;
            GenerateMeshDegradedRectangles(mesh,ref rectangleAsset);
        }

        SkinnedMeshRenderer[] skinMeshRenders = go.GetComponentsInChildren<SkinnedMeshRenderer>();
        foreach (var skinMeshRender in skinMeshRenders)
        {
            RectangleAsset rectangleAsset = new RectangleAsset();
            Mesh mesh = skinMeshRender.sharedMesh;
            rectangleAsset.mesh = mesh;
            GenerateMeshDegradedRectangles(mesh,ref rectangleAsset);
        }
    }
    public static void GenerateMeshDegradedRectangles(Mesh mesh, ref RectangleAsset rectangleAsset)
    {
        int[] triangles = mesh.triangles;
        Vector3[] vertices = mesh.vertices;
        int length = triangles.Length / 3;
        List<MeshLine> lineList = new List<MeshLine>();
        for(int i = 0; i < length; i++)
        {
            int index1 = triangles[i * 3 + 0];
            int index2 = triangles[i * 3 + 1];
            int index3 = triangles[i * 3 + 2];
            AddMeshLine(index1, index2, index3, vertices[index1], vertices[index2], ref lineList);
            AddMeshLine(index2, index3, index1, vertices[index2], vertices[index3], ref lineList);
            AddMeshLine(index3, index1, index2, vertices[index3], vertices[index1], ref lineList);
        }
        foreach (MeshLine line in lineList)
        {
            rectangleAsset.degradedRectangles.Add(line.belongRectangle);
        }
        SaveRectangleAsset(ref rectangleAsset,mesh.name);
    }

    private static void SaveRectangleAsset(ref RectangleAsset rectangleAsset,string name)
    {
        string path =  "Assets/Custom RP/Preprocess/" + name + ".asset";
        AssetDatabase.CreateAsset(rectangleAsset,path);
      
    }

    private static void AddMeshLine(int index1, int index2, int index3,
        Vector3 v1, Vector3 v2, ref List<MeshLine> lineList)
    {
        MeshLine line = new MeshLine(index1, index2, v1, v2);
        if (!lineList.Contains(line))
        {
            line.belongRectangle.triangle1_vertex3 = index3;
            line.belongRectangle.triangle2_vertex3 = -1;
            lineList.Add(line);
        }
        else
        {
            int i = lineList.IndexOf(line);
            DegradedRectangle rectangle = lineList[i].belongRectangle;
            if (rectangle.triangle2_vertex3 == -1)
            {
                rectangle.triangle2_vertex3 = index3;
                lineList[i].belongRectangle = rectangle;
            }
        }
    }
}




