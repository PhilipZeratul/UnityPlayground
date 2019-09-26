#if !defined(MY_LIGHTING_INCLUDED)
#define MY_LIGHTING_INCLUDED
#include "AutoLight.cginc"
#include "UnityPBSLighting.cginc"

float4 _Tint;
sampler2D _MainTex;
sampler2D _HeightMap;
float4 _HeightMap_TexelSize;
float4 _MainTex_ST;
float _Metallic;
float _Smoothness;

struct VertexData
{
    float4 position : POSITION;
    float3 normal : NORMAL;
    float2 uv : TEXCOORD0;
};

struct Interpolators
{
    float4 position : POSITION;
    float2 uv : TEXCOORD0;
    float3 normal : TEXCOORD1;
    float3 worldPos : TEXCOORD2;

    #ifdef VERTEXLIGHT_ON
        float3 vertexLightColor : TEXCOORD3;
    #endif
};                     

void ComputVertexColor(inout Interpolators i)
{
    #ifdef VERTEXLIGHT_ON
        i.vertexLightColor = unity_LightColor[0].rgb;
    #endif
}

Interpolators MyVertexProgram(VertexData v)
{
    Interpolators i;
    i.position = UnityObjectToClipPos(v.position);
    i.worldPos = mul(unity_ObjectToWorld, v.position);
    i.uv = TRANSFORM_TEX(v.uv, _MainTex);
    i.normal = UnityObjectToWorldNormal(v.normal);
    i.normal = normalize(i.normal);
    ComputVertexColor(i);
    return i;
}

UnityLight CreateLight(Interpolators i)
{
    UnityLight light;
    float3 lightVec = _WorldSpaceLightPos0 - i.worldPos;
    UNITY_LIGHT_ATTENUATION(attenuation, 0, i.worldPos);

    #if defined(POINT) || defined(SPOT) || defined(POINT_COOKIE)
        light.dir = normalize(lightVec);
    #else
        light.dir = _WorldSpaceLightPos0;
    #endif

    light.color = _LightColor0.rgb * attenuation;
    light.ndotl = DotClamped(i.normal, light.dir);
    return light;
}

UnityIndirect CreateIndirecLight(Interpolators i)
{
    UnityIndirect indirectLight;
    indirectLight.diffuse = 0;
    indirectLight.specular = 0;

    #ifdef VERTEXLIGHT_ON
        indirectLight.diffuse = i.vertexLightColor;
    #endif

    return indirectLight;
}

void InitializeFragmentNormal(inout Interpolators i)
{
    float2 du = float2(_HeightMap_TexelSize.x * 0.5, 0);
    float u1 = tex2D(_HeightMap, i.uv - du);
    float u2 = tex2D(_HeightMap, i.uv + du);

    float2 dv = float2(_HeightMap_TexelSize.y * 0.5, 0);
    float v1 = tex2D(_HeightMap, i.uv - dv);
    float v2 = tex2D(_HeightMap, i.uv + dv);
        
    i.normal = float3(u1 - u2, 1, v1 - v2);
    i.normal = normalize(i.normal);    
}

float4 MyFragmentProgram(Interpolators i) : SV_TARGET
{
    InitializeFragmentNormal(i);
    float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
    float3 albedo = tex2D(_MainTex, i.uv).rgb * _Tint.rgb;
    float3 specularTint;
    float oneMinusReflectivity;
    albedo = DiffuseAndSpecularFromMetallic(albedo, _Metallic, specularTint, oneMinusReflectivity);

    return UNITY_BRDF_PBS(
        albedo, specularTint,
        oneMinusReflectivity, _Smoothness,
        i.normal, viewDir,
        CreateLight(i), CreateIndirecLight(i));
}

#endif