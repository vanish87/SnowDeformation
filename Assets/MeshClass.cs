using UnityEngine;
using System.Collections.Generic;

class SnowMeshClass
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

    public void Create(int XSize, int YSize)
    {
        VertexSize = 2 * ((XSize+1) * (YSize+1));
        TrianglesSize = ((XSize*YSize)+1) * 6;

        vertices    = new Vector3[VertexSize];
        uv          = new Vector2[VertexSize];
        triangles   = new int[TrianglesSize];
    }
}
