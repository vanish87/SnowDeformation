using UnityEngine;
using System.Collections;
using UnityEditor;

[CustomEditor(typeof(MeshGeneration))]

public class BuildMesh : Editor {
    bool usingHeightMap = false;
    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();
        MeshGeneration myScript = (MeshGeneration)target;
        usingHeightMap = EditorGUILayout.Toggle("Using HeightMap", usingHeightMap);

        if (GUILayout.Button("Build Mesh"))
        {
            //myScript.CreateNewMesh();
            myScript.Generate(usingHeightMap);
        }

    }
}