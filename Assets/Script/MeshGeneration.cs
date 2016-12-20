using UnityEngine;
using System.Collections;
using System.Collections.Generic;

[ExecuteInEditMode]
[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]

public class MeshGeneration : MonoBehaviour {

    public int xSize, ySize;
    [Range(1, 50)]
    public float NoiseScale = 10;
    [Range(0, 4)]
    public float NoiseHeightScale = 0.5f;    

    public Camera snowAccumulationMapCamera;

    private Vector3[] vertices = null;
    private Mesh mesh = null;
    public Texture2D MeshHeightMapCPU = null;
    private RenderTexture MeshHeightMap = null;
    // Use this for initialization
    
    void Start()
    {
        if (snowAccumulationMapCamera == null)
        {
            snowAccumulationMapCamera = GameObject.Find("SnowAccumulationCamera").GetComponent<Camera>();
        }
        if(MeshHeightMap == null)
        {
            MeshHeightMap = snowAccumulationMapCamera.GetComponent<SnowAccumulationCameraScript>().snowNormalsAndHeightTex;
        }
        if (MeshHeightMapCPU == null)
        {
            MeshHeightMapCPU = new Texture2D(MeshHeightMap.width, MeshHeightMap.height, TextureFormat.ARGB32, true);
            MeshHeightMapCPU.name = "MeshHeightMapCPU";
        }
        Generate();
    }

    public void Generate(bool usingHeightMap = false)
    {
        if (xSize <= 0 || ySize <= 0) return;
        //if (mesh != null) return;

        GetComponent<MeshFilter>().mesh = mesh = new Mesh();
        mesh.name = "Procedural Grid";

        int length = (xSize + 1) * (ySize + 1);
        vertices = new Vector3[length];
        Vector2[] uv = new Vector2[length];
        Vector4[] tangents = new Vector4[length];
        Vector4 tangent = new Vector4(1f, 0f, 0f, -1f);
        for (int i = 0, y = 0; y <= ySize; y++)
        {
            for (int x = 0; x <= xSize; x++, i++)
            {
                float heightNoise = 0;
                if (usingHeightMap)
                {
                    heightNoise = 0.5f - GetHeightValue(x, y);
                }
                else
                {
                    heightNoise = Mathf.PerlinNoise((float)y / (xSize) * NoiseScale, (float)x / (ySize) * NoiseScale);
                }
                vertices[i] = new Vector3(x - (xSize/2), heightNoise * NoiseHeightScale, y - (ySize/2));
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

    float GetHeightValue(int x, int y)
    {
        int PixelX = (int)(x * 1.0 / xSize * MeshHeightMap.width);
        int PixelY = (int)(y * 1.0 / ySize * MeshHeightMap.height);
        return MeshHeightMapCPU.GetPixel(PixelX, PixelY).a;
    }
    
    // Update is called once per frame
    void Update () {
        if (MeshHeightMap == null)
        {
            MeshHeightMap = snowAccumulationMapCamera.GetComponent<SnowAccumulationCameraScript>().snowNormalsAndHeightTex;
        }

        RenderTexture OldRT = RenderTexture.active;
        RenderTexture.active = MeshHeightMap;
        MeshHeightMapCPU.ReadPixels(new Rect(0, 0, MeshHeightMap.width, MeshHeightMap.height), 0, 0);
        MeshHeightMapCPU.Apply();
        RenderTexture.active = OldRT;
        //CreateNewMesh();
        //ReGenerateMesh();

    }
}
