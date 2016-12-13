using UnityEngine;
using System.Collections.Generic;

class SnowMesh
{
    public uint ID { get { return MeshID; } set { MeshID = ID; } }
    private uint MeshID;
    private int VertexSize;
    private int TrianglesSize;
    private Vector3[] vertices = null;
    public Vector3[] Vextex { get { return vertices; } set { vertices = Vextex; } }

    private Vector2[] uv = null;
    public Vector2[] UV { get { return uv; } set { uv = UV; } }

    private Vector4[] tangents = null;

    private int[] triangles = null;
    public int[] Triangle { get { return triangles; } set { triangles = Triangle; } }

    private List<Vector3> CurrentVertices = null;
    private List<int> CurrentIndices= null;
    int CurrentCount = 0;
    public Mesh Mesh { get; set; }

    public SnowMesh()
    {
        CurrentVertices = new List<Vector3>();
        CurrentIndices = new List<int>();
        CurrentCount = 0;
    }

    public void Create(int XSize, int YSize)
    {
        VertexSize = 2 * ((XSize+1) * (YSize+1));
        TrianglesSize = ((XSize*YSize)+1) * 6;

        vertices    = new Vector3[VertexSize];
        uv          = new Vector2[VertexSize];
        triangles   = new int[TrianglesSize];
    }

    public void GenerateNewMesh()
    {
        Mesh = new Mesh();
        Mesh.vertices = CurrentVertices.ToArray();

        Mesh.SetIndices(CurrentIndices.ToArray(), MeshTopology.Points, 0);
        Mesh.RecalculateBounds();
    }

    public void AddVertex(Vector3 VertexToAdd)
    {
        CurrentIndices.Add(CurrentCount++);
        CurrentVertices.Add(VertexToAdd);
    }
}
