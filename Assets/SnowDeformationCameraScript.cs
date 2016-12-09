using UnityEngine;
using System.Collections;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]

public class SnowDeformationCameraScript : MonoBehaviour
{
    public Shader depthShader;//keep tracking of deformation

    public Camera depthCamera;
    public Material material;

    public RenderTexture snowHeightTex;
    //public RenderTexture DeformationTex { get { return snowHeightTex; } }
    //additional depth buffer required for keep tracking of trails
    public RenderTexture currentSnowHeight;

    public RenderTexture[] mrtTex = new RenderTexture[2];
    private RenderBuffer[] mrtRB = new RenderBuffer[2];

    // Use this for initialization
    void Start()
    {
        depthShader = Shader.Find("Snow/RenderDepth");
        material = new Material(depthShader);
        material.hideFlags = HideFlags.HideAndDontSave;
        depthCamera = GetComponent<Camera>();
        depthCamera.depthTextureMode = DepthTextureMode.Depth;

        //setup render texture
        snowHeightTex = new RenderTexture(1024, 1024, 24, RenderTextureFormat.RInt, RenderTextureReadWrite.Linear);
        snowHeightTex.name = "SnowDeformationHeightTex";
        currentSnowHeight = new RenderTexture(1024, 1024, 24, RenderTextureFormat.RInt, RenderTextureReadWrite.Linear);
        currentSnowHeight.name = "CurrentSnowDeformationHeightTex";
        //OnRenderImage called when depthCamera.targetTexture is set
        //depthCamera.SetTargetBuffers(snowHeightTex.colorBuffer, snowHeightTex.depthBuffer);
        depthCamera.targetTexture = snowHeightTex;

        ClearDepth();

        //MRT----------------------------------------------------------------------------
        /*mrtTex[0] = snowHeightTex;//new RenderTexture(512, 512, 24, RenderTextureFormat.ARGB32);
        mrtTex[0].name = "RT0";
        mrtTex[1] = new RenderTexture(512, 512, 24, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
        mrtTex[1].name = "RT1";
        //mrtTex[2] = new RenderTexture(Screen.width, Screen.height, 24, RenderTextureFormat.ARGB32);
        mrtRB[0] = mrtTex[0].colorBuffer;
        mrtRB[1] = mrtTex[1].colorBuffer;

        GetComponent<Camera>().SetTargetBuffers(mrtRB, mrtTex[0].depthBuffer);
        depthCamera.targetTexture = mrtTex[0];*/
    }

    void ClearDepth()
    {
        RenderTexture oldRT = RenderTexture.active;
        Graphics.SetRenderTarget(currentSnowHeight.colorBuffer, currentSnowHeight.depthBuffer);
        GL.Clear(true, true, Color.white);
        RenderTexture.active = oldRT;
    }
    // Update is called once per frame
    void Update()
    {
        //depthCamera.Render();
//         RenderTexture currentRT = RenderTexture.active;
//         RenderTexture.active = depthCamera.targetTexture;
//         depthCamera.Render();
//         RenderTexture.active = currentRT;
    }
    void OnPreRender()
    {
        //Graphics.SetRenderTarget(snowHeightTex);
        //GL.Clear(true, true, Color.black);
        //Debug.Log("render Defor camera");
    }
    void OnPostRender()
    {

    }
    
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        material.SetTexture("_CurrentDepthTexture", currentSnowHeight);
        material.SetFloat("_DeltaTime", Time.deltaTime);
        //called when depthCamera.targetTexture is set
        Graphics.Blit(source, destination, material, 0);

        //currentSnowHeight
        Graphics.Blit(destination, currentSnowHeight);

        //Debug.Log("end Defor camera");
    }
}
