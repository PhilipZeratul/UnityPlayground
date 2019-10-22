Shader "Custom/DeferredShading"
{
    Properties
    {
    }
    SubShader
    {       
        Pass
        {
            ZWrite Off
            Blend [_SrcBlend] [_DstBlend]
                      
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #pragma exclude_renderers nomrt

            #pragma multi_compile_lightpass
            #pragma multi_compile _ UNITY_HDR_ON
            
            #include "MyDeferredShading.cginc"
                                   
            ENDCG
        }

        Pass
        {
            Cull Off
            ZTest Always
            ZWrite Off

            Stencil
            {
                Ref [_StencilNonBackground]
                ReadMask [_StencilNonBackground]
                CompBack Equal
                CompFront Equal
            }

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #pragma exclude_renderers nomrt

            #include "UnityCG.cginc"                                 

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };
            
            sampler2D _LightBuffer;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 color = -log2(tex2D(_LightBuffer, i.uv));
                return color;
            }
            ENDCG
        }               
    }
}
