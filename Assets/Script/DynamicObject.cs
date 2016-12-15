using UnityEngine;
using System.Collections;

[ExecuteInEditMode]

//DynamicObject will render object info and depth of objects with RenderDepthAndObjectHeight shader, 
//then calculate deformation and elevation with DeformationPostProcess in post process of deformation camera.
public class DynamicObject : MonoBehaviour
{
    public Camera snowDeformationCamera;

    public Shader renderHeightMapShader;
    public Shader normalObjectShader;

    public RenderTexture CurrentDepthTexture;

    private Renderer rend;
    private Material renderHeightMapMat;
    private Material normalObjectMat;

    [Range(0.001f, 0.01f)]
    public float _DeformationScale = 0.003f;
    [Range(1f, 5f)]
    public float _ElevationTrailScale = 2.5f;
    
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
            // setup _ObjectMinHeight to camera space and normalize to [0,1];
            float cameraSpaceHeight = snowDeformationCamera.farClipPlane - snowDeformationCamera.nearClipPlane;
            renderHeightMapMat.SetFloat("_ObjectMinHeight", Mathf.Max(0.5f + (rend.bounds.min.y / cameraSpaceHeight), 0));
            renderHeightMapMat.SetFloat("_DeformationScale", _DeformationScale);
            renderHeightMapMat.SetFloat("_ElevationTrailScale", _ElevationTrailScale);
            // keep object center in world space; it used with position of vertex in world space in shader.
            renderHeightMapMat.SetVector("_ObjectCenter", rend.bounds.center);
            //set render depth material
            rend.material = renderHeightMapMat;
        }
        else
        {
            //set normal material
            rend.material = normalObjectMat;
        }
    }
}
