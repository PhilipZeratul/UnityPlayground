#ifndef MY_TESSELLATION_INCLUDED
#define MY_TESSELLATION_INCLUDED

#define MY_DOMAIN_PROGRAM_INTERPOLATE(fieldName) data.fieldName = \
    patch[0].fieldName * barycentricCoordinates.x + \
    patch[1].fieldName * barycentricCoordinates.y + \
    patch[2].fieldName * barycentricCoordinates.z;

float _TessellationUniform;
float _TessellationEdgeLength;

struct TessellationControlPoint
{
    float4 vertex : INTERNALTESSPOS;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float2 uv : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
    float2 uv2 : TEXCOORD2;
};

TessellationControlPoint MyTessellationVertexProgram(VertexData data)
{
    TessellationControlPoint p;
    p.vertex = data.vertex;
    p.normal = data.normal;
    p.tangent = data.tangent;
    p.uv = data.uv;
    p.uv1 = data.uv1;
    p.uv2 = data.uv2;
    return p;
}

[UNITY_domain("tri")]
[UNITY_outputcontrolpoints(3)]
[UNITY_outputtopology("triangle_cw")]
[UNITY_partitioning("fractional_odd")]
[UNITY_patchconstantfunc("MyPatchConstantFunction")]
TessellationControlPoint MyHullProgram(InputPatch<TessellationControlPoint, 3> patch,
                                       uint id : SV_OutputControlPointID)
{
    return patch[id];
}

struct TessellationFactors
{
    float edge[3] : SV_TessFactor;
    float inside : SV_InsideTessFactor;
};

float TessellationEdgeFactor(float3 p0, float3 p1)
{
    #ifdef _TESSELLATION_EDGE        
        float edgeLength = distance(p0, p1);
        float3 edgeCenter = (p0 + p1) * 0.5;
        float viewDistance = distance(edgeCenter, _WorldSpaceCameraPos);
        return edgeLength * _ScreenParams.y / _TessellationEdgeLength / viewDistance;
    #else
        return _TessellationUniform;
    #endif
}

TessellationFactors MyPatchConstantFunction(InputPatch<TessellationControlPoint, 3> patch)
{
    TessellationFactors f;
    float3 p0 = mul(unity_ObjectToWorld, patch[0].vertex.xyz).xyz;
    float3 p1 = mul(unity_ObjectToWorld, patch[1].vertex.xyz).xyz;
    float3 p2 = mul(unity_ObjectToWorld, patch[2].vertex.xyz).xyz;
    f.edge[0] = TessellationEdgeFactor(p1, p2);
    f.edge[1] = TessellationEdgeFactor(p2, p0);
    f.edge[2] = TessellationEdgeFactor(p0, p1);
    f.inside = (TessellationEdgeFactor(p1, p2) +
                TessellationEdgeFactor(p2, p0) +
                TessellationEdgeFactor(p0, p1)) / 3.0;
    return f;
}

[UNITY_domain("tri")]
InterpolatorsVertex MyDomainProgram(TessellationFactors factors, 
                     OutputPatch<TessellationControlPoint, 3> patch,
                     float3 barycentricCoordinates : SV_DomainLocation)
{
    VertexData data;
    MY_DOMAIN_PROGRAM_INTERPOLATE(vertex)
    MY_DOMAIN_PROGRAM_INTERPOLATE(normal)
    MY_DOMAIN_PROGRAM_INTERPOLATE(tangent)
    MY_DOMAIN_PROGRAM_INTERPOLATE(uv)
    MY_DOMAIN_PROGRAM_INTERPOLATE(uv1)
    MY_DOMAIN_PROGRAM_INTERPOLATE(uv2)

    return MyVertexProgram(data);
}

#endif