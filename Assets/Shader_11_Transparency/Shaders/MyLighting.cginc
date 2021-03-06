﻿#if !defined(MY_LIGHTING_INCLUDED)
#define MY_LIGHTING_INCLUDED
#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"

float4 _Tint;
sampler2D _MainTex, _DetailTex;
float4 _MainTex_ST, _DetailTex_ST;
sampler2D _NormalMap, _DetailNormalMap;
float _BumpScale, _DetailBumpScale;
sampler2D _MetallicMap;
float _Metallic;
float _Smoothness;
sampler2D _OcclusionMap;
float _OcclusionStrength;
sampler2D _EmissionMap;
float3 _Emission;
sampler2D _DetailMask;
float _AlphaCutoff;

struct VertexData
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float2 uv : TEXCOORD0;
};

struct Interpolators
{
    float4 pos : SV_POSITION;
    float4 uv : TEXCOORD0;
    float3 normal : TEXCOORD1;

    #ifdef BINORMAL_PER_FRAGMENT
        float4 tangent : TEXCOORD2;
    #else
        float3 tangent : TEXCOORD2;
        float3 binormal : TEXCOORD3;
    #endif

    float3 worldPos : TEXCOORD4;

    #ifdef VERTEXLIGHT_ON
        float3 vertexLightColor : TEXCOORD5;
    #endif

    SHADOW_COORDS(5)
};                     

void ComputVertexColor(inout Interpolators i)
{
    #ifdef VERTEXLIGHT_ON
        i.vertexLightColor = unity_LightColor[0].rgb;
    #endif
}

float3 CreateBinormal(float3 normal, float3 tangent, float binormalSign)
{
    return cross(normal, tangent.xyz) * binormalSign * unity_WorldTransformParams.w;
}

Interpolators MyVertexProgram(VertexData v)
{
    Interpolators i;
    i.pos = UnityObjectToClipPos(v.vertex);
    i.worldPos = mul(unity_ObjectToWorld, v.vertex);
    i.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
    i.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);
    i.normal = UnityObjectToWorldNormal(v.normal);
    i.normal = normalize(i.normal);
    
    #ifdef BINORMAL_PER_FRAGMENT
        i.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
    #else
        i.tangent = UnityObjectToWorldDir(v.tangent.xyz);
        i.binormal = CreateBinormal(i.normal, i.tangent, v.tangent.w);
    #endif
    
    TRANSFER_SHADOW(i);

    ComputVertexColor(i);
    return i;
}

float GetAlpha(Interpolators i)
{
    float alpha = _Tint.a;
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
    #ifdef FORWARD_BASE_PASS
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
    float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Tint.rgb;
    #ifdef _DETAIL_ALBEDO_MAP
        float3 detail = tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;
        albedo = lerp(albedo, albedo * detail, GetDetailMask(i));    
    #endif
    return albedo;
}

UnityLight CreateLight(Interpolators i)
{
    UnityLight light;
    float3 lightVec = _WorldSpaceLightPos0 - i.worldPos;
    
    #if defined(POINT) || defined(SPOT) || defined(POINT_COOKIE)
        light.dir = normalize(lightVec);
    #else
        light.dir = _WorldSpaceLightPos0;
    #endif
    
    UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos);        
    light.color = _LightColor0.rgb * attenuation;
    light.ndotl = DotClamped(i.normal, light.dir);
    return light;
}

float3 BoxProjection(float3 direction, float3 position, float4 cubemapPosition, float3 boxMin, float3 boxMax)
{
    #if UNITY_SPECCUBE_BOX_PROJECTION
        UNITY_BRANCH
        if (cubemapPosition.w > 0)
        {
            boxMin -= position;
            boxMax -= position;
            float x = (direction.x > 0 ? boxMax.x : boxMin.x) / direction.x;
            float y = (direction.y > 0 ? boxMax.y : boxMin.y) / direction.y;
            float z = (direction.z > 0 ? boxMax.z : boxMin.z) / direction.z;
            float scalar = min(min(x, y), z);

            direction = direction * scalar + position - cubemapPosition;
        }
    #endif
    return direction;
}

UnityIndirect CreateIndirectLight(Interpolators i, float3 viewDir)
{
    UnityIndirect indirectLight;
    indirectLight.diffuse = 0;
    indirectLight.specular = 0;

    #ifdef VERTEXLIGHT_ON
        indirectLight.diffuse = i.vertexLightColor;
    #endif

    #ifdef FORWARD_BASE_PASS
        indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));
        float3 reflectionDir = reflect(-viewDir, i.normal);        
        Unity_GlossyEnvironmentData envData;
        envData.roughness = 1 - GetSmoothness(i);
                              
        envData.reflUVW = BoxProjection(reflectionDir, i.worldPos, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
        float3 probe0 = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData);
        
        #if UNITY_SPECCUBE_BLENDING
            float interpolator = unity_SpecCube0_BoxMin.w;
            UNITY_BRANCH
            if (interpolator < 0.99999)
            {
                envData.reflUVW = BoxProjection(reflectionDir, i.worldPos, unity_SpecCube1_ProbePosition, unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax);
                float3 probe1 = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1, unity_SpecCube0), unity_SpecCube1_HDR, envData);
            
                indirectLight.specular = lerp(probe1, probe0, unity_SpecCube0_BoxMin.w);
            }
            else
            {
                indirectLight.specular = probe0;
            }
        #else
            indirectLight.specular = probe0;
        #endif

        float occlusion = GetOcclusion(i);
        indirectLight.specular *= occlusion;
        indirectLight.diffuse *= occlusion;
    #endif
    
    return indirectLight;
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

void InitializeFragmentNormal(inout Interpolators i)
{
    float3 tangentSpaceNormal = GetTangentNormal(i);
    
    #ifdef BINORMAL_PER_FRAGMENT
        float3 binormal = CreateBinormal(i.normal, i.tangent.xyz, i.tangent.w);
    #else
        float3 binormal = i.binormal;
    #endif

    i.normal = normalize(
        tangentSpaceNormal.x * i.tangent +
        tangentSpaceNormal.y * binormal +
        tangentSpaceNormal.z * i.normal
    );
}

float4 MyFragmentProgram(Interpolators i) : SV_TARGET
{
    float alpha = GetAlpha(i);
    #ifdef _RENDERING_CUTOUT
        clip(alpha - _AlphaCutoff);
    #endif
    InitializeFragmentNormal(i);
    float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);    
    float3 specularTint;
    float oneMinusReflectivity;
    float3 albedo = DiffuseAndSpecularFromMetallic(GetAlbedo(i), GetMetallic(i), specularTint, oneMinusReflectivity);

    #ifdef _RENDERING_TRANSPARENT
        albedo *= alpha;
        alpha = 1 - oneMinusReflectivity + alpha * oneMinusReflectivity;
    #endif

    float4 color = UNITY_BRDF_PBS(
        albedo, specularTint,
        oneMinusReflectivity, GetSmoothness(i),
        i.normal, viewDir,
        CreateLight(i), CreateIndirectLight(i, viewDir));

    color.rgb += GetEmission(i);
    #if defined(_RENDERING_FADE) || defined(_RENDERING_TRANSPARENT)
        color.a = alpha;
    #endif
    return color;
}

#endif