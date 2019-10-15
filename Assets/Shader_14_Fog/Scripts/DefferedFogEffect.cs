using System;
using UnityEngine;

[ExecuteInEditMode]
public class DefferedFogEffect : MonoBehaviour
{
    public Shader defferedFogShader;

    [NonSerialized]
    private Material fogMaterial;
    [NonSerialized]
    private Camera defferedCamera;
    [NonSerialized]
    private Vector3[] frustumCorners;
    [NonSerialized]
    private Vector4[] vector4s;


    [ImageEffectOpaque]
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (fogMaterial == null)
            Init();       

        defferedCamera.CalculateFrustumCorners(
            new Rect(0, 0, 1, 1), defferedCamera.farClipPlane, defferedCamera.stereoActiveEye, frustumCorners);

        vector4s[0] = frustumCorners[0];
        vector4s[1] = frustumCorners[3];
        vector4s[2] = frustumCorners[1];
        vector4s[3] = frustumCorners[2];

        fogMaterial.SetVectorArray("_FrustumCorners", vector4s);

        Graphics.Blit(source, destination, fogMaterial);
    }

    private void Init()
    {
        fogMaterial = new Material(defferedFogShader);
        defferedCamera = GetComponent<Camera>();
        frustumCorners = new Vector3[4];
        vector4s = new Vector4[4];
    }
}
