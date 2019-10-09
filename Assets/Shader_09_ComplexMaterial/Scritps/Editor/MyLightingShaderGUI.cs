using UnityEngine;
using UnityEditor;


public class MyLightingShaderGUI : ShaderGUI
{
    private static GUIContent staticLabel = new GUIContent();
    private static ColorPickerHDRConfig emissionConfig = new ColorPickerHDRConfig(0f, 99f, 1f / 99f, 3f);

    private Material target;
    private MaterialEditor materialEditor;
    private MaterialProperty[] properties;

    enum SmoothnessSource
    {
        Uniform, Albedo, Metallic
    }

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        this.target = materialEditor.target as Material;
        this.materialEditor = materialEditor;
        this.properties = properties;

        DoMain();
        DoSecondary();
        
    }

    private void DoMain()
    {
        GUILayout.Label("Main Maps", EditorStyles.boldLabel);
        MaterialProperty mainTex = FindProperty("_MainTex");
        materialEditor.TexturePropertySingleLine(MakeLabel(mainTex, "Albedo (RGB)"), mainTex, FindProperty("_Tint"));
        DoNormals();
        DoEmission();
        DoMetallic();
        DoSmoothness();
        materialEditor.TextureScaleOffsetProperty(mainTex);
    }

    private void DoNormals()
    {
        MaterialProperty normalMap = FindProperty("_NormalMap");        
        materialEditor.TexturePropertySingleLine(MakeLabel(normalMap), normalMap, normalMap.textureValue ? FindProperty("_BumpScale") : null);        
    }

    private void DoEmission()
    {
        MaterialProperty emissionMap = FindProperty("_EmissionMap");
        EditorGUI.BeginChangeCheck();
        materialEditor.TexturePropertyWithHDRColor(MakeLabel(emissionMap, "Emission (RGB)"), emissionMap, FindProperty("_Emission"), emissionConfig, false);
        if (EditorGUI.EndChangeCheck())
            SetKeyword("_EMISSION_MAP", emissionMap.textureValue);

    }

    private void DoMetallic()
    {
        MaterialProperty metallicMap = FindProperty("_MetallicMap");
        EditorGUI.BeginChangeCheck();
        materialEditor.TexturePropertySingleLine(MakeLabel(metallicMap, "Metallic (R)"), metallicMap, metallicMap.textureValue ? null : FindProperty("_Metallic"));
        if (EditorGUI.EndChangeCheck())
            SetKeyword("_METALLIC_MAP", metallicMap.textureValue);
    }

    private void DoSmoothness()
    {
        SmoothnessSource smoothnessSource = SmoothnessSource.Uniform;
        if (IsKeywordEnabled("_SMOOTHNESS_ALBEDO"))
            smoothnessSource = SmoothnessSource.Albedo;
        else if (IsKeywordEnabled("_SMOOTHNESS_METALLIC"))
            smoothnessSource = SmoothnessSource.Metallic;

        EditorGUI.indentLevel += 2;
        MaterialProperty slider = FindProperty("_Smoothness");
        materialEditor.ShaderProperty(slider, MakeLabel(slider));
        EditorGUI.indentLevel += 1;
        EditorGUI.BeginChangeCheck();
        RecordAction("Smoothness Source");
        smoothnessSource = (SmoothnessSource)EditorGUILayout.EnumPopup(MakeLabel("Source"), smoothnessSource);
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyword("_SMOOTHNESS_ALBEDO", smoothnessSource == SmoothnessSource.Albedo);
            SetKeyword("_SMOOTHNESS_METALLIC", smoothnessSource == SmoothnessSource.Metallic);
        }
            
        EditorGUI.indentLevel -= 3;
    }

    private void DoSecondary()
    {
        GUILayout.Label("Secondary Maps", EditorStyles.boldLabel);
        MaterialProperty detailTex = FindProperty("_DetailTex");
        materialEditor.TexturePropertySingleLine(MakeLabel(detailTex, "Albedo (RGB) Multiplied by 2"), detailTex);
        DoSecondaryNormals();
        materialEditor.TextureScaleOffsetProperty(detailTex);
    }

    private void DoSecondaryNormals()
    {
        MaterialProperty detailNormalMap = FindProperty("_DetailNormalMap");
        materialEditor.TexturePropertySingleLine(MakeLabel(detailNormalMap), detailNormalMap, detailNormalMap.textureValue ? FindProperty("_DetailBumpScale") : null);
    }    

    private MaterialProperty FindProperty(string name)
    {
        return FindProperty(name, properties);
    }

    private GUIContent MakeLabel(string name, string toolTip = null)
    {
        staticLabel.text = name;
        staticLabel.tooltip = toolTip;
        return staticLabel;
    }

    private GUIContent MakeLabel(MaterialProperty property, string toolTip = null)
    {
        return MakeLabel(property.displayName, toolTip);
    }

    private void SetKeyword(string keyword, bool state)
    {
        if (state)
            target.EnableKeyword(keyword);
        else
            target.DisableKeyword(keyword);
    }

    private bool IsKeywordEnabled(string keyword)
    {
        return target.IsKeywordEnabled(keyword);
    }

    private void RecordAction(string label)
    {
        materialEditor.RegisterPropertyChangeUndo(label);
    }
}
