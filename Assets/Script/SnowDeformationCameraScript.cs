using UnityEngine;
using System.Collections;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]

//DynamicObject will render object info and depth of objects with RenderDepthAndObjectHeight shader, 
//then calculate deformation and elevation with DeformationPostProcess in post process of deformation camera.

public class SnowDeformationCameraScript : MonoBehaviour
{
    public Shader depthShader;

    public Camera depthCamera;
    public Material material;

    public RenderTexture snowHeightTex;

    //additional depth buffer required for keep tracking of trails
    public RenderTexture currentSnowHeight;
    public Texture2D currentSnowHeightCPU;

    public Camera snowAccumulationMapCamera;
    public RenderTexture AccumulationTex;

    [Range(0, 25f)]
    public float artistScale = 1.0f;

    // Use this for initialization
    void Start()
    {
        depthShader = Shader.Find("Snow/DeformationPostProcess");
        if (material == null)
        {
            material = new Material(depthShader);
            material.hideFlags = HideFlags.HideAndDontSave;
        }
        depthCamera = GetComponent<Camera>();
        depthCamera.depthTextureMode = DepthTextureMode.Depth;

        //setup render texture
        if(snowHeightTex == null)
        {
            snowHeightTex = new RenderTexture(1024, 1024, 24, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
            snowHeightTex.name = "SnowDeformationHeightTex";
        }
        if(currentSnowHeight == null)
        {
            currentSnowHeight = new RenderTexture(1024, 1024, 24, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
            currentSnowHeight.name = "CurrentSnowDeformationHeightTex";
        }
        //OnRenderImage called when depthCamera.targetTexture is set
        //depthCamera.SetTargetBuffers(snowHeightTex.colorBuffer, snowHeightTex.depthBuffer);
        depthCamera.targetTexture = snowHeightTex;

        snowAccumulationMapCamera = GameObject.Find("SnowAccumulationCamera").GetComponent<Camera>();
        if(AccumulationTex == null)
        {
            AccumulationTex = snowAccumulationMapCamera.GetComponent<SnowAccumulationCameraScript>().snowNormalsAndHeightTex;
        }

        currentSnowHeightCPU = new Texture2D(currentSnowHeight.width, currentSnowHeight.height, TextureFormat.ARGB32, true);

        ClearDepth();
        
    }

    public void ClearDepth()
    {
        RenderTexture oldRT = RenderTexture.active;
        Graphics.SetRenderTarget(currentSnowHeight);
        GL.Clear(true, true, Color.white);
        RenderTexture.active = oldRT;
    }
    // Update is called once per frame
    void Update()
    {

    }
    
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        material.SetTexture("_CurrentDepthTexture", currentSnowHeight);
        material.SetTexture("_CurrentAccumulationTexture", AccumulationTex);
        material.SetTexture("_NewDepthTex", source);
        material.SetFloat("_DeltaTime", Time.deltaTime);
        material.SetFloat("_ArtistElevationScale", artistScale);
        
        //called when depthCamera.targetTexture is set
        Graphics.Blit(source, destination, material, 0);

        //keep tracking currentSnowHeight info
        Graphics.Blit(destination, currentSnowHeight);

        //debug texture
        RenderTexture oldRT = RenderTexture.active;
        RenderTexture.active = source;
        currentSnowHeightCPU.ReadPixels(new Rect(0, 0, currentSnowHeight.width, currentSnowHeight.height), 0, 0);
        currentSnowHeightCPU.Apply();
        RenderTexture.active = oldRT;
        //Debug.Log("OnRenderImage Defor camera");
    }
}
