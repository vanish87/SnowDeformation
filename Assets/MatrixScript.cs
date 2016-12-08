using UnityEngine;
using System.Collections;

public class MatrixScript : MonoBehaviour {

    public Camera snowHeighMapCamera;
    public Camera snowAccumulationMapCamera;
    public Material snowMaterial;
	// Use this for initialization
	void Start () {
	
	}
	
	// Update is called once per frame
	void Update ()
    {
        if (snowHeighMapCamera.orthographic)
        {
            snowMaterial.SetMatrix("_SnowCameraMatrix", snowHeighMapCamera.worldToCameraMatrix);
            snowMaterial.SetMatrix("_SnowAccumulationCameraMatrix", snowAccumulationMapCamera.worldToCameraMatrix);
            snowMaterial.SetFloat("_SnowCameraSize", snowHeighMapCamera.orthographicSize);
            snowMaterial.SetFloat("_SnowCameraZScale", snowHeighMapCamera.farClipPlane-snowHeighMapCamera.nearClipPlane);
        }
    }
}
