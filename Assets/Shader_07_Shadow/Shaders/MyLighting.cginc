#if !defined(MY_LIGHTING_INCLUDED)
#define MY_LIGHTING_INCLUDED
#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"

float4 _Tint;
sampler2D _MainTex, _DetailTex;
float4 _MainTex_ST, _DetailTex_ST;
sampler2D _NormalMap, _DetailNormalMap;
float _BumpScale, _DetailBumpScale;
float _Metallic;
float _Smoothness;

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

UnityIndirect CreateIndirectLight(Interpolators i)
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
    float3 mainNormal = UnpackScaleNormal(tex2D(_NormalMap, i.uv.xy), _BumpScale);
    float3 detailNormal = UnpackScaleNormal(tex2D(_DetailNormalMap, i.uv.zw), _DetailBumpScale);
    float3 tangentSpaceNormal = BlendNormals(mainNormal, detailNormal);
    
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
    InitializeFragmentNormal(i);
    float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
    float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Tint.rgb;
    albedo *= tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;
    float3 specularTint;
    float oneMinusReflectivity;
    albedo = DiffuseAndSpecularFromMetallic(albedo, _Metallic, specularTint, oneMinusReflectivity);

    return UNITY_BRDF_PBS(
        albedo, specularTint,
        oneMinusReflectivity, _Smoothness,
        i.normal, viewDir,
        CreateLight(i), CreateIndirectLight(i));
}

#endif