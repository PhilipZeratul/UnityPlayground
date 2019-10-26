// Upgrade NOTE: upgraded instancing buffer 'InstanceProperties' to new syntax.

#if !defined(MY_LIGHTING_INCLUDED)
#define MY_LIGHTING_INCLUDED
#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"

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

InterpolatorsVertex MyVertexProgram(VertexData v)
{
    InterpolatorsVertex i;
    UNITY_INITIALIZE_OUTPUT(Interpolators, i);
    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_TRANSFER_INSTANCE_ID(v, i);
    i.pos = UnityObjectToClipPos(v.vertex);
    i.worldPos.xyz = mul(unity_ObjectToWorld, v.vertex);
    #if FOG_DEPTH
        i.worldPos.w = i.pos.z;
    #endif
    i.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
    i.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);
    #if defined(LIGHTMAP_ON) || ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS
        i.lightmapUV = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
    #endif
    i.normal = UnityObjectToWorldNormal(v.normal);
    i.normal = normalize(i.normal);
    
    #ifdef BINORMAL_PER_FRAGMENT
        i.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
    #else
        i.tangent = UnityObjectToWorldDir(v.tangent.xyz);
        i.binormal = CreateBinormal(i.normal, i.tangent, v.tangent.w);
    #endif
    
    UNITY_TRANSFER_SHADOW(i, v.uv1);

    #ifdef DYNAMICLIGHTMAP_ON
        i.dynamicLightmapUV = v.uv2 * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    #endif

    ComputVertexColor(i);

    #ifdef _PARALLAX_MAP
        #ifdef PARALLAX_SUPPORT_SCALED_DYNAMIC_BATCHING
            v.tangent.xyz = normalize(v.tangent.xyz);
            v.normal = normalize(v.normal);
        #endif
        float3x3 objectToTangent = float3x3(v.tangent.xyz, cross(v.normal, v.tangent.xyz) * v.tangent.w, v.normal);
        i.tangentViewDir = mul(objectToTangent, ObjSpaceViewDir(v.vertex));
    #endif
    return i;
}

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

float FadeShadow(Interpolators i, float attenuation)
{
    #if defined(HANDLE_SHADOWS_BLENDING_IN_GI) || ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS
        #if ADDITIONAL_MASKED_DIRECTIONAL_SHADOWS
            attenuation = SHADOW_ATTENUATION(i);
        #endif
        float viewZ = dot(_WorldSpaceCameraPos - i.worldPos, UNITY_MATRIX_V[2].xyz);
        float shadowFadeDistance = UnityComputeShadowFadeDistance(i.worldPos, viewZ);
        float shadowFade = UnityComputeShadowFade(shadowFadeDistance);
        float bakedAttenuation = UnitySampleBakedOcclusion(i.lightmapUV, i.worldPos);
        attenuation = UnityMixRealtimeAndBakedShadows(attenuation, bakedAttenuation, shadowFade);
    #endif
    return attenuation;
}

UnityLight CreateLight(Interpolators i)
{
    UnityLight light;

    #if defined(DEFERRED_PASS) || SUBTRACTIVE_LIGHTING
        light.dir = float3(0, 1, 0);
        light.color = 0;
    #else
        float3 lightVec = _WorldSpaceLightPos0 - i.worldPos.xyz;
        
        #if defined(POINT) || defined(SPOT) || defined(POINT_COOKIE)
            light.dir = normalize(lightVec);
        #else
            light.dir = _WorldSpaceLightPos0;
        #endif
        
        UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos.xyz);    
        attenuation = FadeShadow(i, attenuation);    
        light.color = _LightColor0.rgb * attenuation;
    #endif      
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

void ApplySubtractiveLighting(Interpolators i, inout UnityIndirect indirectLight)
{
    #if SUBTRACTIVE_LIGHTING
        UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos.xyz);
        attenuation = FadeShadow(i, attenuation);
        float ndotl = saturate(dot(i.normal, _WorldSpaceLightPos0.xyz));
        float3 shadowedLightEstimate = ndotl * (1 - attenuation) * _LightColor0.rgb;
        float3 subtractedLight = indirectLight.diffuse - shadowedLightEstimate;
        subtractedLight = max(subtractedLight, unity_ShadowColor.rgb);
        subtractedLight = lerp(subtractedLight, indirectLight.diffuse.rgb, _LightShadowData.x);
        indirectLight.diffuse = subtractedLight;
        indirectLight.diffuse = min(indirectLight.diffuse, subtractedLight);
    #endif
}

UnityIndirect CreateIndirectLight(Interpolators i, float3 viewDir)
{
    UnityIndirect indirectLight;
    indirectLight.diffuse = 0;
    indirectLight.specular = 0;

    #ifdef VERTEXLIGHT_ON
        indirectLight.diffuse = i.vertexLightColor;
    #endif

    #if defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS)
        #ifdef LIGHTMAP_ON
            indirectLight.diffuse = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.lightmapUV));
            #ifdef DIRLIGHTMAP_COMBINED
                float4 lightmapDirection = UNITY_SAMPLE_TEX2D_SAMPLER(unity_LightmapInd, unity_Lightmap, i.lightmapUV);
                indirectLight.diffuse = DecodeDirectionalLightmap(indirectLight.diffuse, lightmapDirection, i.normal);
            #endif
            ApplySubtractiveLighting(i, indirectLight);
        #endif        
        #ifdef DYNAMICLIGHTMAP_ON
            float3 dynamicLightDiffuse = DecodeRealtimeLightmap(UNITY_SAMPLE_TEX2D(unity_DynamicLightmap, i.dynamicLightmapUV));
            #ifdef DIRLIGHTMAP_COMBINED
                float4 dynamicLightmapDirection = UNITY_SAMPLE_TEX2D_SAMPLER(unity_DynamicDirectionality, unity_DynamicLightmap, i.dynamicLightmapUV);
                indirectLight.diffuse += DecodeDirectionalLightmap(dynamicLightDiffuse, dynamicLightmapDirection, i.normal);
            #else
                indirectLight.diffuse += dynamicLightDiffuse;
            #endif           
        #endif
        #if !defined(LIGHTMAP_ON) && !defined(DYNAMICLIGHTMAP_ON)  
            #if UNITY_LIGHT_PROBE_PROXY_VOLUME
                if (unity_ProbeVolumeParams.x == 1)
                {
                    indirectLight.diffuse = SHEvalLinearL0L1_SampleProbeVolume(float4(i.normal, 1), i.worldPos);
                    indirectLight.diffuse = max(0, indirectLight.diffuse);
                    #ifdef UNITY_COLORSPACE_GAMMA
                        indirectLight.diffuse = LinearToGammaSpace(indirectLight.diffuse);
                    #endif
                }
                else
                {
                    indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));
                }
            #else 
                indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));
            #endif
        #endif
        float3 reflectionDir = reflect(-viewDir, i.normal);        
        Unity_GlossyEnvironmentData envData;
        envData.roughness = 1 - GetSmoothness(i);
                              
        envData.reflUVW = BoxProjection(reflectionDir, i.worldPos.xyz, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
        float3 probe0 = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData);
        
        #if UNITY_SPECCUBE_BLENDING
            float interpolator = unity_SpecCube0_BoxMin.w;
            UNITY_BRANCH
            if (interpolator < 0.99999)
            {
                envData.reflUVW = BoxProjection(reflectionDir, i.worldPos.xyz, unity_SpecCube1_ProbePosition, unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax);
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

        #if defined(DEFERRED_PASS) || UNITY_ENABLE_REFLECTION_BUFFERS
            indirectLight.specular = 0;
        #endif
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

float4 ApplyFog(float4 color, Interpolators i)
{
    #if FOG_ON        
        float viewDistance = length(_WorldSpaceCameraPos - i.worldPos.xyz);
        #if FOG_DEPTH
            viewDistance = UNITY_Z_0_FAR_FROM_CLIPSPACE(i.worldPos.w);
        #endif
        UNITY_CALC_FOG_FACTOR_RAW(viewDistance);
        float3 fogColor = 0;
        #ifdef FORWARD_BASE_PASS
            fogColor = unity_FogColor.rgb;
        #endif
        color.rgb = lerp(fogColor, color.rgb, saturate(unityFogFactor));   
    #endif
    return color; 
} 

float GetParallaxHeight(float2 uv)
{
    return tex2D(_ParallaxMap, uv).g;
}

float2 ParallaxOffset(float2 uv, float2 viewDir)
{
    float height = GetParallaxHeight(uv) - 0.5;
    height *= _ParallaxStrength;        
    return viewDir * height;
}

float2 ParallaxRaymarching(float2 uv, float2 viewDir)
{
    #ifndef PARALLAX_RAYMARCHING_STEPS
        #define PARALLAX_RAYMARCHING_STEPS 10
    #endif
    float2 uvOffset = 0;
    float stepSize = 1.0 / PARALLAX_RAYMARCHING_STEPS;
    float2 uvDelta = viewDir * stepSize * _ParallaxStrength;   
    float stepHeight = 1;
    float surfaceHeight = GetParallaxHeight(uv);

    float2 prevUVOffset = uvOffset;
    float prevStepHeight = stepHeight;
    float prevSurfaceHeight = surfaceHeight;

    for (int i = 1; i < PARALLAX_RAYMARCHING_STEPS && stepHeight > surfaceHeight; i++)
    {
        prevUVOffset = uvOffset;
        prevStepHeight = stepHeight;
        prevSurfaceHeight = surfaceHeight;

        uvOffset -= uvDelta;
        stepHeight -= stepSize;
        surfaceHeight = GetParallaxHeight(uv + uvOffset);       
    }

    #ifndef PARALLAX_RAYMARCHING_SEARCH_STEP
        #define PARALLAX_RAYMARCHING_SEARCH_STEP 0
    #endif
    #if PARALLAX_RAYMARCHING_SEARCH_STEP > 0
        for (int i = 0; i < PARALLAX_RAYMARCHING_SEARCH_STEP; i++)
        {
            uvDelta *= 0.5;
            stepSize *= 0.5;
            if (stepHeight < surfaceHeight)
            {
                uvOffset += uvDelta;
                stepHeight += stepSize;
            }
            else
            {
                uvOffset -= uvDelta;
                stepHeight -= stepSize;
            }
            surfaceHeight = GetParallaxHeight(uv + uvOffset); 
        }   
    #elif defined(PARALLAX_RAYMARCHING_INTERPOLATE)
        float prevDifference = prevStepHeight - prevSurfaceHeight;
        float difference = stepHeight - surfaceHeight;
        float t = prevDifference / (prevDifference - difference);
        uvOffset = prevUVOffset - uvDelta * t;
    #endif

    return uvOffset;
}

void ApplyParallax(inout Interpolators i)
{
    #ifdef _PARALLAX_MAP
        i.tangentViewDir = normalize(i.tangentViewDir);
        #ifndef PARALLAX_OFFSET_LIMITING
            #ifndef PARALLAX_BIAS
                #define PARALLAX_BIAS 0.42
            #endif
            i.tangentViewDir.xy /= (i.tangentViewDir.z + PARALLAX_BIAS);
        #endif   
        #ifndef PARALLAX_FUNCTION
            #define PARALLAX_FUNCTION ParallaxOffset
        #endif   
        float2 uvOffset = PARALLAX_FUNCTION(i.uv.xy, i.tangentViewDir.xy);
        i.uv.xy += uvOffset;
        i.uv.zw += uvOffset * (_DetailTex_ST.xy / _MainTex_ST.xy);
    #endif
}

struct FragmentOutput
{
    #ifdef DEFERRED_PASS
        float4 gBuffer0 : SV_TARGET0;
        float4 gBuffer1 : SV_TARGET1;
        float4 gBuffer2 : SV_TARGET2;
        float4 gBuffer3 : SV_TARGET3;
        #if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
            float4 gBuffer4 : SV_TARGET4;
        #endif
    #else
        float4 color : SV_TARGET;        
    #endif
    
};

FragmentOutput MyFragmentProgram(Interpolators i) : SV_TARGET
{
    UNITY_SETUP_INSTANCE_ID(i);
    #ifdef LOD_FADE_CROSSFADE
        UnityApplyDitherCrossFade(i.vpos);
    #endif
    ApplyParallax(i);
    float alpha = GetAlpha(i);
    #ifdef _RENDERING_CUTOUT
        clip(alpha - _Cutoff);
    #endif
    InitializeFragmentNormal(i);
    float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos.xyz);    
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

    FragmentOutput output;
    #ifdef DEFERRED_PASS
        #ifndef UNITY_HDR_ON
            color.rgb = exp2(-color.rgb);
        #endif
        output.gBuffer0.rgb = albedo;
        output.gBuffer0.a = GetOcclusion(i);
        output.gBuffer1.rgb = specularTint;
        output.gBuffer1.a = GetSmoothness(i);
        output.gBuffer2 = float4(i.normal * 0.5 + 0.5, 1);
        output.gBuffer3 = color;
        #if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
            float2 shadowUV = 0;
            #ifdef LIGHTMAP_ON
                shadowUV = i.lightmapUV;
            #endif
            output.gBuffer4 = UnityGetRawBakedOcclusions(i.lightmapUV, i.worldPos.xyz);
        #endif
    #else
        output.color = ApplyFog(color, i);
    #endif
    
    return output;
}

#endif