Shader "Custom/Deffered Fog"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Cull Off
        ZTest Always
        ZWrite Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #define FOG_DISTANCE
            //#define FOG_SKYBOX
            
            #include "UnityCG.cginc"
            //#include "HLSLSupport.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;

                #ifdef FOG_DISTANCE
                    float3 ray : TEXCOORD1;
                #endif
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            // Depth Buffer!
            sampler2D _CameraDepthTexture;
            float3 _FrustumCorners[4];

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                #ifdef FOG_DISTANCE
                    o.ray = _FrustumCorners[v.uv.x + 2 * v.uv.y];
                #endif
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed3 sourceColor = tex2D(_MainTex, i.uv).rgb;

                #if !defined(FOG_LINEAR) && !defined(FOG_EXP) && !defined(FOG_EXP2)
                    return float4(sourceColor, 1);
                #endif

                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
                depth = Linear01Depth(depth);
                float viewDistance = depth * _ProjectionParams.z - _ProjectionParams.y;
                #ifdef FOG_DISTANCE
                    viewDistance = length(i.ray * depth);
                #endif
                UNITY_CALC_FOG_FACTOR_RAW(viewDistance);
                unityFogFactor = saturate(unityFogFactor);

                #ifndef FOG_SKYBOX
                    if (depth > 0.999)
                        unityFogFactor = 1;
                #endif
                
                fixed3 fogColor = lerp(unity_FogColor.rgb, sourceColor, unityFogFactor);
                return fixed4(fogColor, 1);
            }
            ENDCG
        }
    }
}
