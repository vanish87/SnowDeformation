using UnityEngine;
using System.Collections;
using System.Collections.Generic;
[ExecuteInEditMode]
[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class MeshGeneration : MonoBehaviour {

    public int xSize, ySize;
    public float NoiseScale = 10;
    public float NoiseHeithtScale = 0.5f;

    private Vector3[] vertices = null;
    private Mesh mesh = null;
    // Use this for initialization
    void Start()
    {
        Generate();
    }
   
    void Generate()
    {
        if (xSize <= 0 || ySize <= 0) return;
        if (mesh != null) return;

        GetComponent<MeshFilter>().mesh = mesh = new Mesh();
        mesh.name = "Procedural Grid";

        vertices = new Vector3[(xSize + 1) * (ySize + 1)];
        Vector2[] uv = new Vector2[vertices.Length];
        Vector4[] tangents = new Vector4[vertices.Length];
        Vector4 tangent = new Vector4(1f, 0f, 0f, -1f);
        for (int i = 0, y = 0; y <= ySize; y++)
        {
            for (int x = 0; x <= xSize; x++, i++)
            {
                float heightNoise = Mathf.PerlinNoise((float)y/(xSize) * NoiseScale, (float)x/(ySize) * NoiseScale);
                vertices[i] = new Vector3(x - (xSize/2), heightNoise * NoiseHeithtScale, y - (ySize/2));
                uv[i] = new Vector2((float)x / xSize, (float)y / ySize);
                tangents[i] = tangent;
            }
        }
        int[] triangles = new int[xSize * ySize * 6];
        for (int ti = 0, vi = 0, y = 0; y < ySize; y++, vi++)
        {
            for (int x = 0; x < xSize; x++, ti += 6, vi++)
            {
                triangles[ti] = vi;
                triangles[ti + 3] = triangles[ti + 2] = vi + 1;
                triangles[ti + 4] = triangles[ti + 1] = vi + xSize + 1;
                triangles[ti + 5] = vi + xSize + 2;
            }
        }

        mesh.vertices = vertices;
        mesh.uv = uv;
        mesh.tangents = tangents;
        mesh.triangles = triangles;
        mesh.RecalculateBounds();
        mesh.RecalculateNormals();
    }
    // Update is called once per frame
    void Update () {
	
	}
}
