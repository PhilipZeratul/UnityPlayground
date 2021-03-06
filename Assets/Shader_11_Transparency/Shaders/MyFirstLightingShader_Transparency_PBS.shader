﻿Shader "Custom/My First Lighting Shader Transparency PBS"
{    
    Properties
    {
        _Tint ("Tint", color) = (1, 1, 1, 1)
        _MainTex ("Albedo", 2D) = "white" {}
        //[NoScaleOffset] _HeightMap ("Height Map", 2D) = "gray" {}
        [NoScaleOffset] _NormalMap ("Normal Map", 2D) = "bump" {}
        _BumpScale ("Bump Scale", Float) = 1
        [NoScaleOffset] _MetallicMap ("Metallic Map", 2D) = "white" {}
        [Gamma] _Metallic ("Metallic", Range(0, 1)) = 1
        _Smoothness ("Smoothness", Range(0, 1)) = 0.5
        _DetailTex ("Detail Texture", 2D) = "gray" {}
        [NoScaleOffset] _DetailNormalMap ("Detail Normal Map", 2D) = "bump" {}
        [NoScaleOffset] _DetailMask ("Detail Mask", 2D) = "white" {}
        _DetailBumpScale ("Detail Bump Scale", Float) = 1
        [NoScaleOffset] _OcclusionMap ("Occlusion", 2D) = "white" {}
        _OcclusionStrength ("Occlussion Strength", Range(0, 1)) = 1
        [NoScaleOffset] _EmissionMap ("Emission Map", 2D) = "black" {}
        _Emission ("Emission", Color) = (0, 0, 0)  
        _AlphaCutoff ("Alpha Cutoff", Range(0, 1)) = 0.5
        [HideInInspector] _SrcBlend ("SrcBlend", Float) = 1
        [HideInInspector] _DstBlend ("DstBlend", Float) = 0   
        [HideInInspector] _ZWrite ("Zwrite", Float) = 1
    }

    CGINCLUDE

    #define BINORMAL_PER_FRAGMENT

    ENDCG

	SubShader
    {
        Pass
        {
            Tags 
            {
                "LightMode" = "ForwardBase"
            }
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]

            CGPROGRAM

            #pragma target 3.0

            #pragma multi_compile _ SHADOWS_SCREEN
            #pragma multi_compile _ VERTEXLIGHT_ON
            #pragma shader_feature _NORMAL_MAP
            #pragma shader_feature _METALLIC_MAP
            #pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
            #pragma shader_feature _OCCLUSION_MAP
            #pragma shader_feature _EMISSION_MAP     
            #pragma shader_feature _DETAIL_MASK 
            #pragma shader_feature _DETAIL_ALBEDO_MAP
            #pragma shader_feature _DETAIL_NORMAL_MAP  
            #pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT

            #define FORWARD_BASE_PASS

            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram

            #include "MyLighting.cginc"
            

            ENDCG
        }

        Pass
        {
            Tags 
            {
                "LightMode" = "ForwardAdd"
            }

            Blend [SrcBlend] One
            ZWrite Off

            CGPROGRAM

            #pragma target 3.0

            #pragma multi_compile_fwdadd_fullshadows
            #pragma shader_feature _NORMAL_MAP
            #pragma shader_feature _METALLIC_MAP
            #pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
            #pragma shader_feature _DETAIL_MASK
            #pragma shader_feature _DETAIL_ALBEDO_MAP
            #pragma shader_feature _DETAIL_NORMAL_MAP  
            #pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE

            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram           

            #include "MyLighting.cginc"

            ENDCG
        }

        Pass
        {
            Tags
            {  
                "LightMode" = "ShadowCaster"
            }

            CGPROGRAM

            #pragma target 3.0

            #pragma multi_compile_shadowcaster

            #pragma vertex MyShadowVertexProgram
            #pragma fragment MyShadowFragmentProgram

            #include "MyShadows.cginc"

            ENDCG
        }
    }

    CustomEditor "MyLightingShaderGUI"
}
