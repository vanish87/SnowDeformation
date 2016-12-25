using UnityEngine;
using System.Collections;

[ExecuteInEditMode]

//SnowCoveredObject will render normal and depth of objects with RenderNormalAndDepth shader, 
//then render object for main camera with SnowObject shader

public class SnowAccumulatedObject : MonoBehaviour {

    public Camera snowAccumulationCamera;

    public Shader renderHeightMapShader;
    public Shader normalObjectShader;

    private Renderer rend;
    private Material renderHeightMapMat;
    private Material normalObjectMat;
    // Use this for initialization
    void Start ()
    {
        rend = GetComponent<Renderer>();
        if (renderHeightMapShader == null)
        {
            renderHeightMapShader = Shader.Find("Snow/RenderNormalAndDepth");
        }
        if (normalObjectShader == null)
        {
            normalObjectShader = Shader.Find("Snow/SnowObject");
        }
        renderHeightMapMat = new Material(renderHeightMapShader);
        normalObjectMat = new Material(normalObjectShader);

        if(snowAccumulationCamera == null)
        {
            snowAccumulationCamera = GameObject.Find("SnowAccumulationCamera").GetComponent<Camera>();
        }
    }
	
	// Update is called once per frame
	void Update ()
    {
	
	}
    void OnWillRenderObject()
    {
        //switch between AccumulationCamera and normal main camera
        if (Camera.current == snowAccumulationCamera)
        {
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
