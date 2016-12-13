using UnityEngine;
using System.Collections;

[ExecuteInEditMode]
public class DynamicObject : MonoBehaviour
{
    public Camera snowDeformationCamera;

    public Shader renderHeightMapShader;
    public Shader normalObjectShader;

    public RenderTexture CurrentDepthTexture;

    private Renderer rend;
    private Material renderHeightMapMat;
    private Material normalObjectMat;

    [Range(0, 0.005F)]
    public float _DeformationScale = 0.003f;
    // Use this for initialization
    void Start()
    {
        rend = GetComponent<Renderer>();
        if (renderHeightMapShader == null)
        {
            renderHeightMapShader = Shader.Find("Snow/RenderDepthAndObjectHeight");
        }
        if (normalObjectShader == null)
        {
            normalObjectShader = Shader.Find("Standard");
        }
        renderHeightMapMat = new Material(renderHeightMapShader);
        normalObjectMat = new Material(normalObjectShader);
    }

    // Update is called once per frame
    void Update()
    {

    }
    void OnWillRenderObject()
    {
        if (Camera.current == snowDeformationCamera)
        {
            renderHeightMapMat.SetMatrix("_SnowCameraMatrix", snowDeformationCamera.worldToCameraMatrix);
            renderHeightMapMat.SetFloat("_ObjectMinHeight", (25 + rend.bounds.min.y) / 50 );
            renderHeightMapMat.SetFloat("_DeformationScale", _DeformationScale);
            renderHeightMapMat.SetVector("_ObjectCenter", rend.bounds.center);
            //set render depth material
            rend.material = renderHeightMapMat;
            //Debug.Log(snowDeformationCamera.worldToCameraMatrix);
            //Debug.Log(rend.bounds.min.y);
        }
        else
        {
            //set normal material
            rend.material = normalObjectMat;
        }
    }
}
