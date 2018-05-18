﻿// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

#if !defined(MY_SHADOW_INCLUDED)
#define MY_SHADOW_INCLUDED

#include "UnityCG.cginc"

struct VertexData
{
    float4 position : POSITION;
    float3 normal : NORMAL;
};

float4 MyShadowVertexProgram(VertexData v) : SV_POSITION
{
    float4 position = UnityClipSpaceShadowCasterPos(v.position.xyz, v.normal);
    return UnityApplyLinearShadowBias(position);
}

half4 MyShadowFragmentProgram() : SV_TARGET
{
    return 0;
}

#endif
