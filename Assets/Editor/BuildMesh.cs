using UnityEngine;
using System.Collections;
using UnityEditor;

[CustomEditor(typeof(MeshGeneration))]

public class BuildMesh : Editor {
    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();
        MeshGeneration myScript = (MeshGeneration)target;
        if (GUILayout.Button("Build Mesh"))
        {
            //myScript.CreateNewMesh();
            myScript.Generate();
        }
    }
}