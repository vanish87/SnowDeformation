using UnityEngine;
using UnityStandardAssets.ImageEffects;
using System.Collections;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]

public class SnowAccumulationCameraScript : PostEffectsBase
{
    public Shader depthShader;//not used: keep tracking of trails;Scene/Object informal is set by SnowCoveredObject.cs
    public Material material; //not used: depth is setup while rendering objects

    public Camera accDepthCamera;
    public RenderTexture snowNormalsAndHeightTex;

    [Range(0, 2)]
    public int downsample = 1;

    public enum BlurType
    {
        StandardGauss = 0,
        SgxGauss = 1,
    }

    [Range(0.0f, 100.0f)]
    public float blurSize = 3.0f;

    [Range(1, 4)]
    public int blurIterations = 2;

    public BlurType blurType = BlurType.StandardGauss;

    public Shader blurShader = null;
    private Material blurMaterial = null;
    
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

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        //Graphics.Blit(source, destination, );
        //Graphics.Blit(source, destination, material);
        //Debug.Log("OnRenderImage Acc camera");
        if (CheckResources() == false)
        {
            Graphics.Blit(source, destination);
            return;
        }

        float widthMod = 1.0f / (1.0f * (1 << downsample));

        blurMaterial.SetVector("_Parameter", new Vector4(blurSize * widthMod, -blurSize * widthMod, 0.0f, 0.0f));
        source.filterMode = FilterMode.Bilinear;

        int rtW = source.width >> downsample;
        int rtH = source.height >> downsample;

        // downsample
        RenderTexture rt = RenderTexture.GetTemporary(rtW, rtH, 0, source.format);

        rt.filterMode = FilterMode.Bilinear;
        Graphics.Blit(source, rt, blurMaterial, 0);

        var passOffs = blurType == BlurType.StandardGauss ? 0 : 2;

        for (int i = 0; i < blurIterations; i++)
        {
            float iterationOffs = (i * 1.0f);
            blurMaterial.SetVector("_Parameter", new Vector4(blurSize * widthMod + iterationOffs, -blurSize * widthMod - iterationOffs, 0.0f, 0.0f));

            // vertical blur
            RenderTexture rt2 = RenderTexture.GetTemporary(rtW, rtH, 0, source.format);
            rt2.filterMode = FilterMode.Bilinear;
            Graphics.Blit(rt, rt2, blurMaterial, 1 + passOffs);
            RenderTexture.ReleaseTemporary(rt);
            rt = rt2;

            // horizontal blur
            rt2 = RenderTexture.GetTemporary(rtW, rtH, 0, source.format);
            rt2.filterMode = FilterMode.Bilinear;
            Graphics.Blit(rt, rt2, blurMaterial, 2 + passOffs);
            RenderTexture.ReleaseTemporary(rt);
            rt = rt2;
        }

        Graphics.Blit(rt, destination);

        RenderTexture.ReleaseTemporary(rt);
    }

    public override bool CheckResources()
    {

        //PostEffectsBase.Start();
        if (depthShader == null)
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
        

        CheckSupport(false);

        blurMaterial = CheckShaderAndCreateMaterial(blurShader, blurMaterial);

        if (!isSupported)
            ReportAutoDisable();
        return isSupported;
    }

    public void OnDisable()
    {
        if (blurMaterial)
            DestroyImmediate(blurMaterial);
    }
}

