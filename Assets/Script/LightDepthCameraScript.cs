using UnityEngine;
using System.Collections;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]

public class LightlightDepthCameraScript : MonoBehaviour
{
    public Shader lightDepthShader;

    public Camera lightDepthCamera;
    public Material material;

    public RenderTexture lightDepthTex;        

    // Use this for initialization
    void Start()
    {
        lightDepthShader = Shader.Find("Snow/RenderDepth");
        if (material == null)
        {
            material = new Material(lightDepthShader);
            material.hideFlags = HideFlags.HideAndDontSave;
        }
        lightDepthCamera = GetComponent<Camera>();
        lightDepthCamera.depthTextureMode = DepthTextureMode.Depth;

        //setup render texture
        if(lightDepthTex == null)
        {
            lightDepthTex = new RenderTexture(1024, 1024, 24, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
            lightDepthTex.name = "LightDepthTex";
        }
        lightDepthCamera.targetTexture = lightDepthTex;
    }
    
    // Update is called once per frame
    void Update()
    {

    }
}
