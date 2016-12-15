using UnityEngine;
using System.Collections;

[ExecuteInEditMode]
[RequireComponent(typeof(Renderer))]

//when rendering snow mesh, it reads information from AccumulationTex and DeformationTex, 
//and combine them with snow mesh height position
public class SnowMeshRendering : MonoBehaviour {

    public RenderTexture AccumulationTex;
    public RenderTexture DeformationTex;

    public Material snowMaterial;

    public Camera snowHeighMapCamera;
    public Camera snowAccumulationMapCamera;

    // Use this for initialization
    void Start()
    {
        snowHeighMapCamera = GameObject.Find("SnowDeformationCamera").GetComponent<Camera>();
        snowAccumulationMapCamera = GameObject.Find("SnowAccumulationCamera").GetComponent<Camera>();
        
        AccumulationTex = snowAccumulationMapCamera.GetComponent<SnowAccumulationCameraScript>().snowNormalsAndHeightTex;
        DeformationTex = snowHeighMapCamera.GetComponent<SnowDeformationCameraScript>().snowHeightTex;

        if (snowMaterial == null)
        {
            snowMaterial = new Material(Shader.Find("Snow/SnowMeshSimple"));
        }

        snowMaterial.SetTexture("_SnowAccumulationMap", AccumulationTex);
        snowMaterial.SetTexture("_SnowHeightMap", DeformationTex);

        GetComponent<Renderer>().material = snowMaterial;
    }    
    	
	// Update is called once per frame
	void Update ()
    {
        if (snowHeighMapCamera.orthographic)
        {
            snowMaterial.SetMatrix("_SnowCameraMatrix", snowHeighMapCamera.worldToCameraMatrix);
            snowMaterial.SetMatrix("_SnowAccumulationCameraMatrix", snowAccumulationMapCamera.worldToCameraMatrix);
            snowMaterial.SetFloat("_SnowCameraSize", snowHeighMapCamera.orthographicSize);
            snowMaterial.SetFloat("_SnowCameraZScale", snowHeighMapCamera.farClipPlane - snowHeighMapCamera.nearClipPlane);
        }

    }

    void OnWillRenderObject()
    {
        //Debug.Log("render Snow Mesh");

        AccumulationTex = snowAccumulationMapCamera.GetComponent<SnowAccumulationCameraScript>().snowNormalsAndHeightTex;
        DeformationTex = snowHeighMapCamera.GetComponent<SnowDeformationCameraScript>().snowHeightTex;

        snowMaterial.SetTexture("_SnowAccumulationMap", AccumulationTex);
        snowMaterial.SetTexture("_SnowHeightMap", DeformationTex);
    }
}
