using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;


[ExecuteInEditMode]
public class VisualizeTangentSpace : MonoBehaviour
{
    public float offset = 0.01f;
    public float scale = 0.1f;

    private Mesh mesh;


    private void Start()
    {
        mesh = GetComponent<MeshFilter>()?.sharedMesh;
    }

    private void OnDrawGizmos()
    {
        if (mesh)
        {
            ShowTangentSpace();
        }        
    }

    private void ShowTangentSpace()
    {
        Vector3[] vertices = mesh.vertices;
        Vector3[] normals = mesh.normals;
        Vector4[] tangents = mesh.tangents;

        for (int i = 0; i < vertices.Length; i++)
        {
            ShowTangentSpace(
                transform.TransformPoint(vertices[i]),
                transform.TransformDirection(normals[i]),
                transform.TransformDirection(tangents[i]),
                tangents[i].w
            );
        }
    }

    private void ShowTangentSpace(Vector3 vertex, Vector3 normal, Vector3 tangent, float binormalSign)
    {
        vertex += normal * offset;
        // Normal
        Gizmos.color = Color.green;
        Gizmos.DrawLine(vertex, vertex + normal * scale);
        // Tangent
        Gizmos.color = Color.red;
        Gizmos.DrawLine(vertex, vertex + tangent * scale);
        // Binormal
        Vector3 binormal = Vector3.Cross(normal, tangent) * binormalSign;
        Gizmos.color = Color.blue;
        Gizmos.DrawLine(vertex, vertex + binormal * scale);
    }
}
