Shader "Custom/Texture Splatting"
{
    Properties
    {
        _MainTex("Splat Map", 2D) = "white"
        [NoScaleOffset]_Texture_1("Texture 1", 2D) = "white"
        [NoScaleOffset]_Texture_2("Texture 2", 2D) = "white"
        [NoScaleOffset]_Texture_3("Texture 3", 2D) = "white"
        [NoScaleOffset]_Texture_4("Texture 4", 2D) = "white"
    }

	SubShader
    {
        Pass
        {
            CGPROGRAM

            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram

            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;

            sampler2D _Texture_1, _Texture_2, _Texture_3, _Texture_4;

            struct Interpolators
            {
                float4 position : POSITION;
                float2 uv : TEXCOORD0;
                float2 uvSplat : TEXCOORD1;
            };

            struct VertexData
            {
                float4 position : POSITION;
                float2 uv : TEXCOORD0;
            };

            Interpolators MyVertexProgram(VertexData v)
            {
                Interpolators i;
                i.position = UnityObjectToClipPos(v.position);
                i.uv = TRANSFORM_TEX(v.uv, _MainTex);
                i.uvSplat = v.uv;
                return i;
            }

            float4 MyFragmentProgram(Interpolators i) : SV_TARGET
            {
                float4 splat = tex2D(_MainTex, i.uvSplat);
                return tex2D(_Texture_1, i.uv) * splat.r + 
                       tex2D(_Texture_2, i.uv) * splat.g +
                       tex2D(_Texture_3, i.uv) * splat.b +
                       tex2D(_Texture_4, i.uv) * (1 - splat.r - splat.g - splat.b);
            }

            ENDCG
        }
    }
}
