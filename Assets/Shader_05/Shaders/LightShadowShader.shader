Shader "Custom/Light Shadow Shader"
{
    Properties
    {
        _Tint("Tint", color) = (1, 1, 1, 1)
        _MainTex("Albedo", 2D) = "white" {}
        [Gamma] _Metallic("Metalic", Range(0, 1)) = 0
        _Smoothness("Smoothness", Range(0, 1)) = 0.5
    }

	SubShader
    {
        Pass
        {
            Tags 
            {
                "LightMode" = "ForwardBase"
            }

            CGPROGRAM

            #pragma target 3.0

            #pragma multi_compile _ SHADOWS_SCREEN
            #pragma multi_compile _ VERTEXLIGHT_ON

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

            Blend One One
            ZWrite Off

            CGPROGRAM

            #pragma target 3.0

            #pragma multi_compile_fwdadd

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

            #pragma vertex MyShadowVertexProgram
            #pragma fragment MyShadowFragmentProgram

            #include "MyShadow.cginc"

            ENDCG
        }
    }
}
