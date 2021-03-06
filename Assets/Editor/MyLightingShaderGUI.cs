﻿using UnityEngine;
using UnityEditor;
using UnityEngine.Rendering;


public class MyLightingShaderGUI : ShaderGUI
{
    private static GUIContent staticLabel = new GUIContent();
    private static ColorPickerHDRConfig emissionConfig = new ColorPickerHDRConfig(0f, 99f, 1f / 99f, 3f);

    private Material target;
    private MaterialEditor materialEditor;
    private MaterialProperty[] properties;

    private bool shouldShowAlphaCutout;

    enum SmoothnessSource
    {
        Uniform, Albedo, Metallic
    }

    enum RenderingMode
    {
        Opaque, Cutout, Fade, Transparent
    }

    enum TessellationMode
    {
        Uniform, Edge
    }

    struct RenderingSettings
    {
        public RenderQueue queue;
        public string renderType;
        public BlendMode srcBlend, dstBlend;
        public bool zWrite;

        public static RenderingSettings[] modes =
        {
            new RenderingSettings()
            {
                queue = RenderQueue.Geometry,
                renderType = "",
                srcBlend = BlendMode.One,
                dstBlend = BlendMode.Zero,
                zWrite = true
            },
            new RenderingSettings()
            {
                queue = RenderQueue.AlphaTest,
                renderType = "TransparentCutout",
                srcBlend = BlendMode.One,
                dstBlend = BlendMode.Zero,
                zWrite = true
            },
            new RenderingSettings()
            {
                queue = RenderQueue.Transparent,
                renderType = "Transparent",
                srcBlend = BlendMode.SrcAlpha,
                dstBlend = BlendMode.OneMinusSrcAlpha,
                zWrite = false
            },
            new RenderingSettings()
            {
                queue = RenderQueue.Transparent,
                renderType = "Transparent",
                srcBlend = BlendMode.One,
                dstBlend = BlendMode.OneMinusSrcAlpha,
                zWrite = false
            }
        };
    }


    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        this.target = materialEditor.target as Material;
        this.materialEditor = materialEditor;
        this.properties = properties;

        DoRenderingMode();
        if (target.HasProperty("_TessellationUniform"))
            DoTessellation();
        if (target.HasProperty("_WireframeColor"))
            DoWireframe();
        DoMain();
        DoSecondary();
        DoAdvanced();
    }

    private void DoRenderingMode()
    {
        RenderingMode mode = RenderingMode.Opaque;
        shouldShowAlphaCutout = false;
        if (IsKeywordEnabled("_RENDERING_CUTOUT"))
        {
            mode = RenderingMode.Cutout;
            shouldShowAlphaCutout = true;
        }
        else if (IsKeywordEnabled("_RENDERING_FADE"))
        {
            mode = RenderingMode.Fade;
        }
        else if (IsKeywordEnabled("_RENDERING_TRANSPARENT"))
        {
            mode = RenderingMode.Transparent;
        }        

        EditorGUI.BeginChangeCheck();
        mode = (RenderingMode)EditorGUILayout.EnumPopup(MakeLabel("Rendering Mode"), mode);
        if (EditorGUI.EndChangeCheck())
        {
            RecordAction("Rendering Mode");
            SetKeyword("_RENDERING_CUTOUT", mode == RenderingMode.Cutout);
            SetKeyword("_RENDERING_FADE", mode == RenderingMode.Fade);
            SetKeyword("_RENDERING_TRANSPARENT", mode == RenderingMode.Transparent);

            RenderingSettings settings = RenderingSettings.modes[(int)mode];
            foreach (Material mat in materialEditor.targets)
            {
                mat.renderQueue = (int)settings.queue;
                mat.SetOverrideTag("RenderType", settings.renderType);
                mat.SetInt("_SrcBlend", (int)settings.srcBlend);
                mat.SetInt("_DstBlend", (int)settings.dstBlend);
                mat.SetInt("_ZWrite", settings.zWrite ? 1 : 0);
            }            
        }

        if (mode == RenderingMode.Fade || mode == RenderingMode.Transparent)
            DoSemitransparentShadows();
    }

    private void DoSemitransparentShadows()
    {
        EditorGUI.BeginChangeCheck();
        bool isSemiTransparentShadows = EditorGUILayout.Toggle(
            MakeLabel("SemiTransp. Shadows", "Semitransparent Shadows"), IsKeywordEnabled("_SEMITRANSPARENT_SHADOWS"));
        if (EditorGUI.EndChangeCheck())
            SetKeyword("_SEMITRANSPARENT_SHADOWS", isSemiTransparentShadows);

        if (!isSemiTransparentShadows)
            shouldShowAlphaCutout = true;
    }

    private void DoTessellation()
    {
        GUILayout.Label("Tessellation", EditorStyles.boldLabel);
        EditorGUI.indentLevel += 2;

        TessellationMode mode = TessellationMode.Uniform;
        if (IsKeywordEnabled("_TESSELLATION_EDGE"))
            mode = TessellationMode.Edge;
        EditorGUI.BeginChangeCheck();
        mode = (TessellationMode)EditorGUILayout.EnumPopup(MakeLabel("Mode"), mode);
        if (EditorGUI.EndChangeCheck())
        {
            RecordAction("Tessellation Mode");
            SetKeyword("_TESSELLATION_EDGE", mode == TessellationMode.Edge);
        }
        if (mode == TessellationMode.Uniform)
            materialEditor.ShaderProperty(FindProperty("_TessellationUniform"), MakeLabel("Uniform"));
        else
            materialEditor.ShaderProperty(FindProperty("_TessellationEdgeLength"), MakeLabel("Edge Length"));
        EditorGUI.indentLevel -= 2;
    }

    private void DoWireframe()
    {
        GUILayout.Label("Wireframe", EditorStyles.boldLabel);
        EditorGUI.indentLevel += 2;
        materialEditor.ShaderProperty(FindProperty("_WireframeColor"), MakeLabel("Color"));
        materialEditor.ShaderProperty(FindProperty("_WireframeSmoothing"), MakeLabel("Smoothing", "In screen space."));
        materialEditor.ShaderProperty(FindProperty("_WireframeThickness"), MakeLabel("Thickness", "In screen space."));
        EditorGUI.indentLevel -= 2;
    }

    private void DoMain()
    {
        GUILayout.Label("Main Maps", EditorStyles.boldLabel);
        MaterialProperty mainTex = FindProperty("_MainTex");
        materialEditor.TexturePropertySingleLine(MakeLabel(mainTex, "Albedo (RGB)"), mainTex, FindProperty("_Color"));
        materialEditor.TextureScaleOffsetProperty(mainTex);
        DoMetallic();
        DoSmoothness();
        DoNormals();
        DoParallax();
        DoOcclusion();
		DoEmission();
        if (shouldShowAlphaCutout)
            DoAlphaCutoff();
        DoDetailMask();
    }

    private void DoNormals()
    {
        MaterialProperty normalMap = FindProperty("_NormalMap");
        Texture textureValue = normalMap.textureValue;
        EditorGUI.BeginChangeCheck();
        materialEditor.TexturePropertySingleLine(MakeLabel(normalMap), normalMap, textureValue ? FindProperty("_BumpScale") : null);
        if (EditorGUI.EndChangeCheck() && normalMap.textureValue != textureValue)
            SetKeyword("_NORMAL_MAP", normalMap.textureValue);
    }

    private void DoParallax()
    {
        MaterialProperty ParallaxMap = FindProperty("_ParallaxMap");
        Texture textureValue = ParallaxMap.textureValue;
        EditorGUI.BeginChangeCheck();
        materialEditor.TexturePropertySingleLine(MakeLabel(ParallaxMap, "Parallax (G)"), ParallaxMap, textureValue ? FindProperty("_ParallaxStrength") : null);
        if (EditorGUI.EndChangeCheck() && ParallaxMap.textureValue != textureValue)
            SetKeyword("_PARALLAX_MAP", ParallaxMap.textureValue);
    }

    private void DoOcclusion()
    {
        MaterialProperty occlusionMap = FindProperty("_OcclusionMap");
        Texture textureValue = occlusionMap.textureValue;
        EditorGUI.BeginChangeCheck();
        materialEditor.TexturePropertySingleLine(MakeLabel(occlusionMap, "Occlusion (G)"), occlusionMap, textureValue ? FindProperty("_OcclusionStrength") : null);
        if (EditorGUI.EndChangeCheck() && occlusionMap.textureValue != textureValue)
            SetKeyword("_OCCLUSION_MAP", occlusionMap.textureValue);
    }

    private void DoEmission()
    {
        MaterialProperty emissionMap = FindProperty("_EmissionMap");
        Texture textureValue = emissionMap.textureValue;
        EditorGUI.BeginChangeCheck();
        materialEditor.TexturePropertyWithHDRColor(MakeLabel(emissionMap, "Emission (RGB)"), emissionMap, FindProperty("_Emission"), emissionConfig, false);
        materialEditor.LightmapEmissionProperty(2);
        if (EditorGUI.EndChangeCheck())
        {
            if (emissionMap.textureValue != textureValue)
                SetKeyword("_EMISSION_MAP", emissionMap.textureValue);
            foreach (Material mat in materialEditor.targets)            
                mat.globalIlluminationFlags &= ~MaterialGlobalIlluminationFlags.EmissiveIsBlack;            
        }

    }

    private void DoAlphaCutoff()
    {
        MaterialProperty alphaCutoff = FindProperty("_Cutoff");
        EditorGUI.indentLevel += 2;
        materialEditor.ShaderProperty(alphaCutoff, MakeLabel(alphaCutoff));
        EditorGUI.indentLevel -= 2;
    }

    private void DoMetallic()
    {
        MaterialProperty metallicMap = FindProperty("_MetallicMap");
        Texture textureValue = metallicMap.textureValue;
        EditorGUI.BeginChangeCheck();
        materialEditor.TexturePropertySingleLine(MakeLabel(metallicMap, "Metallic (R)"), metallicMap, textureValue ? null : FindProperty("_Metallic"));
        if (EditorGUI.EndChangeCheck() && metallicMap.textureValue != textureValue)
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

    private void DoDetailMask()
    {
        MaterialProperty detailMask = FindProperty("_DetailMask");
        EditorGUI.BeginChangeCheck();
        materialEditor.TexturePropertySingleLine(MakeLabel(detailMask, "Detail Mask (A)"), detailMask);
        if (EditorGUI.EndChangeCheck())
            SetKeyword("_DETAIL_MASK", detailMask.textureValue);
    }

    private void DoSecondary()
    {
        GUILayout.Label("Secondary Maps", EditorStyles.boldLabel);
        MaterialProperty detailTex = FindProperty("_DetailTex");
        EditorGUI.BeginChangeCheck();
        materialEditor.TexturePropertySingleLine(MakeLabel(detailTex, "Albedo (RGB) Multiplied by 2"), detailTex);
        if (EditorGUI.EndChangeCheck())
            SetKeyword("_DETAIL_ALBEDO_MAP", detailTex.textureValue);
        DoSecondaryNormals();
        materialEditor.TextureScaleOffsetProperty(detailTex);
    }

    private void DoSecondaryNormals()
    {
        MaterialProperty detailNormalMap = FindProperty("_DetailNormalMap");
        Texture textureValue = detailNormalMap.textureValue;
        EditorGUI.BeginChangeCheck();
        materialEditor.TexturePropertySingleLine(MakeLabel(detailNormalMap), detailNormalMap, textureValue ? FindProperty("_DetailBumpScale") : null);
        if (EditorGUI.EndChangeCheck() && detailNormalMap.textureValue != textureValue)
            SetKeyword("_DETAIL_NORMAL_MAP", detailNormalMap.textureValue);
    }    

    private void DoAdvanced()
    {
        GUILayout.Label("Advanced Options", EditorStyles.boldLabel);
        materialEditor.EnableInstancingField();
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
            foreach (Material m in materialEditor.targets)
                m.EnableKeyword(keyword);
        else
            foreach (Material m in materialEditor.targets)
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
