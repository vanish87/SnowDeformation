using UnityEngine;
using System.Collections;

[ExecuteInEditMode]
public class SnowCoveredObject : MonoBehaviour {

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
        renderHeightMapMat = new Material(renderHeightMapShader);
        normalObjectMat = new Material(normalObjectShader);
    }
	
	// Update is called once per frame
	void Update ()
    {
	
	}
    void OnWillRenderObject()
    {
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
