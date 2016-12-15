using UnityEngine;
using UnityStandardAssets.ImageEffects;
using System.Collections;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]

//SnowAccumulationCamera will rendering normal and depth of objects in layer with "SnowAccumulatedObject"
//When rendering snow mesh later, its shader will get SnowAccumulatedObject info and calculate correct deformation and accumulation.

public class SnowAccumulationCameraScript : PostEffectsBase
{
    private Shader depthShader = null;
    private Material material = null;

    public Camera accDepthCamera;
    public RenderTexture snowNormalsAndHeightTex;


    //blur script from unity official blur
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

    }

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
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
        if (depthShader == null)
        {
            depthShader = Shader.Find("Snow/RenderNormalAndDepth");
        }

        material = CheckShaderAndCreateMaterial(depthShader, material);
        material.hideFlags = HideFlags.HideAndDontSave;

        accDepthCamera = GetComponent<Camera>();
        accDepthCamera.depthTextureMode = DepthTextureMode.Depth;

        if (snowNormalsAndHeightTex == null)
        {
            //setup render texture
            snowNormalsAndHeightTex = new RenderTexture(1024, 1024, 24, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
            snowNormalsAndHeightTex.name = "SnowNormalsAndHeightTex";
            //accDepthCamera.SetTargetBuffers(snowNormalsAndHeightTex.colorBuffer, snowNormalsAndHeightTex.depthBuffer);
            accDepthCamera.targetTexture = snowNormalsAndHeightTex;
        }
        

        CheckSupport(false);

        if (blurShader == null)
        {
            blurShader = Shader.Find("Hidden/FastBlur");
        }

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

