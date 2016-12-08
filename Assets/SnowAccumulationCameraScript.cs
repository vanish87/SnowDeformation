using UnityEngine;
using System.Collections;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]

public class SnowAccumulationCameraScript : MonoBehaviour
{
    public Shader depthShader;//not used: keep tracking of trails;Scene/Object informal is set by SnowCoveredObject.cs
    public Material material; //not used: depth is setup while rendering objects

    public Camera accDepthCamera;
    public RenderTexture snowNormalsAndHeightTex;

    // Use this for initialization
    void Start()
    {
        depthShader = Shader.Find("Snow/RenderNormalAndDepth");
        material = new Material(depthShader);
        material.hideFlags = HideFlags.HideAndDontSave;
        accDepthCamera = GetComponent<Camera>();
        accDepthCamera.depthTextureMode = DepthTextureMode.Depth;

        //setup render texture
        snowNormalsAndHeightTex = new RenderTexture(512, 512, 24, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
        snowNormalsAndHeightTex.name = "SnowNormalsAndHeightTex";
        //accDepthCamera.SetTargetBuffers(snowNormalsAndHeightTex.colorBuffer, snowNormalsAndHeightTex.depthBuffer);
        accDepthCamera.targetTexture = snowNormalsAndHeightTex;
    }
    // Update is called once per frame
    void Update()
    {
//         RenderTexture currentRT = RenderTexture.active;
//         RenderTexture.active = accDepthCamera.targetTexture;
//         accDepthCamera.Render();
//         RenderTexture.active = currentRT;
    }
    
    void OnPreRender()
    {
        //         //Graphics.SetRenderTarget(snowNormalsAndHeightTex);
        //         GL.Clear(true, true, Color.black);
       //Debug.Log("PreRender Acc camera");
    }
    /*
        void OnRenderImage(RenderTexture source, RenderTexture destination)
        {
            Graphics.Blit(source, destination);
            //Graphics.Blit(source, destination, material);
        }    */
}
