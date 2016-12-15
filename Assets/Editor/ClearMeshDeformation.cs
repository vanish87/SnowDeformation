using UnityEngine;
using System.Collections;
using UnityEditor;

[CustomEditor(typeof(SnowDeformationCameraScript))]
public class ClearMeshDeformation : Editor
{
    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();

        SnowDeformationCameraScript myScript = (SnowDeformationCameraScript)target;
        if (GUILayout.Button("Clear deformation"))
        {
            myScript.ClearDepth();
        }
    }
}