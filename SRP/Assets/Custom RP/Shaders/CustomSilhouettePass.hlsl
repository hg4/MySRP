#ifndef CUSTOM_SILHOUETTE_PASS_INCLUDED
#define CUSTOM_SILHOUETTE_PASS_INCLUDED
//#include "OutlinePass.hlsl"
struct Attributes
{
    float4 positionOS : POSITION; // vertex position input
    //UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Geometrys
{
    float4 vertex1 : TEXCOORD0;
    float4 vertex2 : TEXCOORD1;
    float2 lineControl : TEXCOORD2;
    //float3 positionOS1 : TEXCOORD2;
    //float3 positionOS2 : TEXCOORD3;
    //UNITY_VERTEX_INPUT_INSTANCE_ID
    
};
struct Varyings
{
    float4 positionCS : SV_POSITION;
    float zoffset : TEXCOORD0;
};

struct DegradedRectangles
{
    int index1;
    int index2;
    int triangle1_index3;
    int triangle2_index3;
};

StructuredBuffer<float3> _Vertices;
StructuredBuffer<float3> _Normals;
StructuredBuffer<float2> _UVs;
StructuredBuffer<DegradedRectangles> _AdjInfos;
StructuredBuffer<float4> _Colors;
float _CreaseThreshold;
float _NormalExtent;
float _LineWidth;
float4 _VertexColorScale;
float4 _LineColor;
sampler2D _LineTexture;
sampler2D _CameraDepthTexture;
sampler2D _FXAAResult;

Geometrys SilhouettePassVertex(Attributes input, uint vid : SV_VertexID)
{
    Geometrys output;
    //UNITY_SETUP_INSTANCE_ID(input);
    //UNITY_TRANSFER_INSTANCE_ID(input, output);
    DegradedRectangles rect = _AdjInfos[vid];
    float3 v1 = _Vertices[rect.index1];
    float3 v2 = _Vertices[rect.index2];
    float3 n1 = _Normals[rect.index1];
    float3 n2 = _Normals[rect.index2];
    float4 c1 = _Colors[rect.index1];
    float4 c2 = _Colors[rect.index2];
    float3 adj1 = _Vertices[rect.triangle1_index3];
    bool isEdge = true;
    bool isBorder = false;
    bool isCrease = false;
    bool isSilhouette = false;
    isBorder = rect.triangle2_index3 == -1 ? true : false;
    float3 adj2 = !isBorder ? _Vertices[rect.triangle2_index3] : adj1;
    float3 l1 = v1 - v2;
    float3 l2 = adj1 - v1;
    float3 l3 = adj2 - v1;
    float3 fn1 = normalize(cross(l1, l2));
    float3 fn2 = normalize(cross(l3, l1));
    float3 v = normalize(TransformWorldToObject(_WorldSpaceCameraPos) - v1);
    isSilhouette = dot(fn1, v) * dot(fn2, v) < 0 ? 1 : 0;
    isCrease = dot(fn1, -fn2) > cos(_CreaseThreshold) ? 1 : 0;
    isEdge = isBorder || isCrease || isSilhouette;
    float val = isEdge ? 1 : 0;
    output.vertex1 = TransformObjectToHClip(v1 + n1 * _NormalExtent) * val;
    output.vertex2 = TransformObjectToHClip(v2 + n2 * _NormalExtent) * val;
    output.lineControl = c1.rg * 0.5 + c2.rg * 0.5;
    
    //output.positionOS1 = v1;
    //output.positionOS2 = v2;
    //output.positionCS = TransformObjectToHClip(input.positionOS);
    return output;
}

[maxvertexcount(6)]
void SilhouettePassGeometry(point Geometrys input[1], inout TriangleStream<Varyings> stream)
{
    Varyings o;
    //output.positionCS = input[0].vertex1;
    //stream.Append(output);
    //output.positionCS = input[0].vertex2;
    //stream.Append(output);
    //stream.RestartStrip();

    float PctExtend = 0.01;

    float3 e0 = input[0].vertex1.xyz / input[0].vertex1.w;
    float3 e1 = input[0].vertex2.xyz / input[0].vertex2.w;
    float2 ext = PctExtend * (e1.xy - e0.xy);
    float2 v = normalize(float3(e1.xy - e0.xy, 0)).xy;
    float depth_vs = LinearEyeDepth(input[0].vertex1, _ZBufferParams);
    float factor = ApplyOutlineDistanceFadeOut(depth_vs)*50;
    float2 n = float2(-v.y, v.x) * _LineWidth * factor * (input[0].lineControl.x);

    float4 v0 = float4(e0.xy + n / 2.0 - ext, e0.z, 1.0);
    float4 v1 = float4(e0.xy - n / 2.0 - ext, e0.z, 1.0);
    float4 v2 = float4(e1.xy + n / 2.0 + ext, e1.z, 1.0);
    float4 v3 = float4(e1.xy - n / 2.0 + ext, e1.z, 1.0);

    o.positionCS = v0;
    o.zoffset = input[0].lineControl.g;
    stream.Append(o);
    o.positionCS = v3;
    stream.Append(o);
    o.positionCS = v2;
    stream.Append(o);
    stream.RestartStrip();

    o.positionCS = v0;
    stream.Append(o);
    o.positionCS = v1;
    stream.Append(o);
    o.positionCS = v3;
    stream.Append(o);
    stream.RestartStrip();
}

float4 SilhouettePassFragment(Varyings input) : SV_Target
{
    float originDepth = tex2D(_CameraDepthTexture, input.positionCS.xy/_ScreenParams.xy).r;
    
    float linearDepth = LinearEyeDepth(originDepth, _ZBufferParams);
    float lineLinearDepth = LinearEyeDepth(input.positionCS.z, _ZBufferParams);
    float zoffset = input.zoffset > 0.5 ? (input.zoffset - 1) *0.002 : 0.002*input.zoffset;
    zoffset *= _VertexColorScale;
    if (abs(lineLinearDepth) + zoffset > abs(linearDepth))
        discard;
    
    return float4(_LineColor.rgb, 1);

}
#endif