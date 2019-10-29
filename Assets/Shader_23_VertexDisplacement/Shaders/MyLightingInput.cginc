// Upgrade NOTE: upgraded instancing buffer 'InstanceProperties' to new syntax.

#ifndef MY_LIGHTING_INPUT_INCLUDED
#define MY_LIGHTING_INPUT_INCLUDED
#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"

#define TESSELLATION_TANGENT 1
#define TESSELLATION_UV1 1
#define TESSELLATION_UV2 1

#if defined(_PARALLAX_MAP) && defined(VERTEX_DISPLACEMENT_INSTEAD_OF_PARALLAX)
    #undef _PARALLAX_MAP
    #define VERTEX_DISPLACEMENT 1
    #define _DisplacementMap _ParallaxMap
    #define _DisplacementStrength _ParallaxStrength
#endif

#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
    #ifndef FOG_DISTANCE
        #define FOG_DEPTH 1
    #endif
    #define FOG_ON 1   
#endif

#if !defined(LIGHTMAP_ON) && defined(SHADOWS_SCREEN)
    #if defined(SHADOWS_SHADOWMASK) && !defined(UNITY_NO_SCREENSPACE_SHADOWS)
        #define ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS 1
    #endif
#endif

#if defined(LIGHTMAP_ON) && defined(SHADOWS_SCREEN)
    #if defined(LIGHTMAP_SHADOW_MIXING) && !defined(SHADOWS_SHADOWMASK)
        #define SUBTRACTIVE_LIGHTING 1
    #endif
#endif

UNITY_INSTANCING_BUFFER_START(InstanceProperties)
    UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
#define _Color_arr InstanceProperties
UNITY_INSTANCING_BUFFER_END(InstanceProperties)

sampler2D _MainTex, _DetailTex;
float4 _MainTex_ST, _DetailTex_ST;
sampler2D _NormalMap, _DetailNormalMap;
float _BumpScale, _DetailBumpScale;
sampler2D _MetallicMap;
float _Metallic;
float _Smoothness;
sampler2D _ParallaxMap;
float _ParallaxStrength;
sampler2D _OcclusionMap;
float _OcclusionStrength;
sampler2D _EmissionMap;
float3 _Emission;
sampler2D _DetailMask;
float _Cutoff;

struct VertexData
{
    UNITY_VERTEX_INPUT_INSTANCE_ID
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float2 uv : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
    float2 uv2 : TEXCOORD2;
};

struct InterpolatorsVertex
{
    UNITY_VERTEX_INPUT_INSTANCE_ID
    float4 pos : SV_POSITION;
    float4 uv : TEXCOORD0;
    float3 normal : TEXCOORD1;

    #ifdef BINORMAL_PER_FRAGMENT
        float4 tangent : TEXCOORD2;
    #else
        float3 tangent : TEXCOORD2;
        float3 binormal : TEXCOORD3;
    #endif
    #if FOG_DEPTH
        float4 worldPos : TEXCOORD4;
    #else
        float3 worldPos : TEXCOORD4;
    #endif
    #ifdef VERTEXLIGHT_ON
        float3 vertexLightColor : TEXCOORD5;
    #endif    
    #if defined(LIGHTMAP_ON) || ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS
        float2 lightmapUV : TEXCOORD5;
    #endif

    UNITY_SHADOW_COORDS(6) 

    #ifdef DYNAMICLIGHTMAP_ON
        float2 dynamicLightmapUV : TEXCOORD7;
    #endif
    #ifdef _PARALLAX_MAP
        float3 tangentViewDir : TEXCOORD8;
    #endif
}; 

struct Interpolators
{
    UNITY_VERTEX_INPUT_INSTANCE_ID
    #ifdef LOD_FADE_CROSSFADE
        UNITY_VPOS_TYPE vpos : VPOS;
    #else
        float4 pos : SV_POSITION;
    #endif
    float4 uv : TEXCOORD0;
    float3 normal : TEXCOORD1;

    #ifdef BINORMAL_PER_FRAGMENT
        float4 tangent : TEXCOORD2;
    #else
        float3 tangent : TEXCOORD2;
        float3 binormal : TEXCOORD3;
    #endif
    #if FOG_DEPTH
        float4 worldPos : TEXCOORD4;
    #else
        float3 worldPos : TEXCOORD4;
    #endif
    #ifdef VERTEXLIGHT_ON
        float3 vertexLightColor : TEXCOORD5;
    #endif    
    #if defined(LIGHTMAP_ON) || ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS
        float2 lightmapUV : TEXCOORD5;
    #endif

    UNITY_SHADOW_COORDS(6) 

    #ifdef DYNAMICLIGHTMAP_ON
        float2 dynamicLightmapUV : TEXCOORD7;
    #endif
    #ifdef _PARALLAX_MAP
        float3 tangentViewDir : TEXCOORD8;
    #endif
    #ifdef CUSTOM_GEOMETRY_INTERPOLATORS
        CUSTOM_GEOMETRY_INTERPOLATORS
    #endif
};                     

float GetAlpha(Interpolators i)
{
    float alpha = UNITY_ACCESS_INSTANCED_PROP(_Color_arr, _Color).a;
    #ifndef _SMOOTHNESS_ALBEDO
        alpha *= tex2D(_MainTex, i.uv.xy).a;
    #endif
    return alpha;
}

float GetMetallic(Interpolators i)
{
    #ifdef _METALLIC_MAP
        return tex2D(_MetallicMap, i.uv).r;
    #else
        return _Metallic;
    #endif
}

float GetSmoothness(Interpolators i)
{
    float smoothness = 1;
    #ifdef _SMOOTHNESS_ALBEDO
        smoothness = tex2D(_MainTex, i.uv).a;
    #elif defined(_SMOOTHNESS_METALLIC) && defined(_METALLIC_MAP)
        smoothness = tex2D(_MetallicMap, i.uv).a;
    #endif

    return smoothness * _Smoothness;
}

float GetOcclusion(Interpolators i)
{
    #ifdef _OCCLUSION_MAP
        return lerp(1, tex2D(_OcclusionMap, i.uv.xy).g, _OcclusionStrength);
    #else
        return 1;
    #endif
}

float3 GetEmission(Interpolators i)
{
    #if defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS)
        #ifdef _EMISSION_MAP
            return tex2D(_EmissionMap, i.uv).rgb * _Emission;
        #else
            return _Emission;
        #endif
    #else
        return 0;
    #endif
}

float GetDetailMask(Interpolators i)
{
    #ifdef _DETAIL_MASK
        return tex2D(_DetailMask, i.uv.xy).a;
    #else
        return 1;
    #endif
}

float3 GetAlbedo(Interpolators i)
{
    float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * UNITY_ACCESS_INSTANCED_PROP(_Color_arr, _Color).rgb;
    #ifdef _DETAIL_ALBEDO_MAP
        float3 detail = tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;
        albedo = lerp(albedo, albedo * detail, GetDetailMask(i));    
    #endif
    return albedo;
}

float3 GetTangentNormal(Interpolators i)
{
    float3 normal = float3(0, 0, 1);
    #ifdef _NORMAL_MAP
        normal = UnpackScaleNormal(tex2D(_NormalMap, i.uv.xy), _BumpScale);
    #endif
    #ifdef _DETAIL_NORMAL_MAP
        float3 detailNormal = UnpackScaleNormal(tex2D(_DetailNormalMap, i.uv.zw), _DetailBumpScale);
        detailNormal = lerp(float3(0, 0, 1), detailNormal, GetDetailMask(i));
        normal = BlendNormals(normal, detailNormal);
    #endif
    return normal;
}

#endif