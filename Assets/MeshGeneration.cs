using UnityEngine;
using System.Collections;
using System.Collections.Generic;
[ExecuteInEditMode]
[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class MeshGeneration : MonoBehaviour {

    public int xSize, ySize;
    public float NoiseScale = 10;
    public float NoiseHeithtScale = 0.5f;
    public Camera snowAccumulationMapCamera;

    private Vector3[] vertices = null;
    private Mesh mesh = null;
    public Texture2D MeshHeightMapCPU;
    private RenderTexture MeshHeightMap;
    // Use this for initialization

    SnowMeshClass newmesh;
    void Start()
    {
        Generate();
        //CreateNewMesh();
    }
   
    public void Generate()
    {
        if (xSize <= 0 || ySize <= 0) return;
        if (mesh != null) return;

        GetComponent<MeshFilter>().mesh = mesh = new Mesh();
        mesh.name = "Procedural Grid";

        int Leight = (xSize + 1) * (ySize + 1);
        vertices = new Vector3[Leight];
        Vector2[] uv = new Vector2[Leight];
        Vector4[] tangents = new Vector4[Leight];
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

    void ReGenerateMesh()
    {
        
        Vector3[] Temp = vertices;
        for (int i = 0, y = 0; y <= ySize; y++)
        {
            for (int x = 0; x <= xSize; x++, i++)
            {
                int PixelX = (int)(x * 1.0 / xSize * MeshHeightMap.width);
                int PixelY = (int)(y * 1.0 / xSize * MeshHeightMap.width);
                float PixelValue = MeshHeightMapCPU.GetPixel(PixelX, PixelY).a;
                if(PixelValue > 0)
                {
                    float height = (1 - PixelValue) * 25;
                    Temp[i].x = x - (xSize / 2);
                    Temp[i].y = height;
                    Temp[i].z = y - (ySize / 2);
                }
                else
                {
                    float heightNoise = Mathf.PerlinNoise((float)y / (xSize) * NoiseScale, (float)x / (ySize) * NoiseScale);
                    Temp[i].y = heightNoise * NoiseHeithtScale;
                }
            }
        }
        mesh.vertices = Temp;
        mesh.RecalculateBounds();
        mesh.RecalculateNormals();
    }

    int GetHeightLevel(float Height)
    {
        int Ret = -1;
        if (Height > 0)
        {
            Ret = (int)(Height * 25);
        }
        return Ret;
    }

    float GetHeightValue(int x, int y)
    {
        int PixelX = (int)(x * 1.0 / xSize * MeshHeightMap.width);
        int PixelY = (int)(y * 1.0 / ySize * MeshHeightMap.width);
        return MeshHeightMapCPU.GetPixel(PixelX, PixelY).a;
    }

    void IsContinuous(Vector3 VertexIndex, Vector2 Direction)
    {
        //float OrgValue = GetHeightValue(VertexIndex);
        for (int i = 1; i < 3; ++i)
        {
            
        }
    }

    void FillValueWithDFS(int[,] Grid, int[] Index, int Value)
    {
        //if(Index[0] >=0 && Index[1] >=0 && Index[0]< xSize && Index[1] < ySize)
        if (Grid[Index[0], Index[1]] < 100 && Grid[Index[0], Index[1]] > -1)
        {
            Grid[Index[0], Index[1]] = Value;
            int[] NewIndex = { Index[0] + 1, Index[1] };
            if(NewIndex[0] < xSize - 1)
            {
                FillValueWithDFS(Grid, NewIndex, Value);
            }

            if (Index[1] < ySize - 1)
            {
                NewIndex[0] = Index[0];
                NewIndex[1] = Index[1] + 1;
                FillValueWithDFS(Grid, NewIndex, Value);
            }

            if (Index[0] > 0)
            {
                NewIndex[0] = Index[0] - 1;
                NewIndex[1] = Index[1];
                FillValueWithDFS(Grid, NewIndex, Value);
            }
        }
    }
    int[,] HeighGrid;
    void FillHeightGrid()
    {
        int[] Index = { 0, 0 };
        int BaseObjectID = 100;
        int CurrentMeshID = BaseObjectID;
        HeighGrid = new int[xSize, ySize];

        for (int y = 0; y < ySize; y++)
        {
            for (int x = 0; x < xSize; x++)
            {
                HeighGrid[x, y] = GetHeightLevel(GetHeightValue(x, y));
            }
        }

        for (int y = 0; y < ySize; y++)
        {
            for (int x = 0; x < xSize; x++)
            {
                if (HeighGrid[x,y] != -1 && HeighGrid[x, y] < BaseObjectID)
                {
                    int[] NewIndex = { x, y };
                    FillValueWithDFS(HeighGrid, NewIndex, CurrentMeshID++);
                }
            }
        }
    }

    public void CreateNewMesh()
    {
        GetComponent<MeshFilter>().mesh = mesh = new Mesh();
        SnowMeshClass NewMesh = new SnowMeshClass();
        NewMesh.Create(xSize, ySize);

        FillHeightGrid();

        for (int i = 0, y = 0; y <= ySize; y++)
        {
            for (int x = 0; x <= xSize; x++, i++)
            {
                float heightNoise = Mathf.PerlinNoise((float)y / (xSize) * NoiseScale, (float)x / (ySize) * NoiseScale);

                if(x < xSize && y < ySize) heightNoise = HeighGrid[x,y]==-1?0:(HeighGrid[x, y]-100) * 2;
                //heightNoise = Random.Range(0, 20) /20;
                NewMesh.Vextex[i] = new Vector3(x - (xSize / 2), heightNoise, y - (ySize / 2));
                NewMesh.UV[i] = new Vector2((float)x / xSize, (float)y / ySize);
                //tangents[i] = tangent;
            }
        }

        for (int ti = 0, vi = 0, y = 0; y < ySize; y++, vi++)
        {
            for (int x = 0; x < xSize; x++, ti += 6, vi++)
            {
                NewMesh.Triangle[ti] = vi;
                NewMesh.Triangle[ti + 3] = NewMesh.Triangle[ti + 2] = vi + 1;
                NewMesh.Triangle[ti + 4] = NewMesh.Triangle[ti + 1] = vi + xSize + 1;
                NewMesh.Triangle[ti + 5] = vi + xSize + 2;
            }
        }

        mesh.vertices = NewMesh.Vextex;
        mesh.uv = NewMesh.UV;
        //mesh.tangents = tangents;
        mesh.triangles = NewMesh.Triangle;
        mesh.RecalculateBounds();
        mesh.RecalculateNormals();
    }
    // Update is called once per frame
    void Update () {
        if (MeshHeightMap == null)
        {
            MeshHeightMap = snowAccumulationMapCamera.GetComponent<SnowAccumulationCameraScript>().snowNormalsAndHeightTex;
            MeshHeightMapCPU = new Texture2D(MeshHeightMap.width, MeshHeightMap.height, TextureFormat.ARGB32,true);
            MeshHeightMapCPU.name = "MeshHeightMapCPU";
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
