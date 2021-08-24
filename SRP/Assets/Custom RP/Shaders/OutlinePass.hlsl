#ifndef OUTLINE_INCLUDED
#define OUTLINE_INCLUDED

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 color : COLOR;
    float2 uv : TEXCOORD0;
    float4 tangentOS : TANGENT;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{ 
    float2 uv : TEXCOORD0;
    float4 postionCS : SV_POSITION;
    float vis_debug : VAR_DEBUG; 
    UNITY_VERTEX_INPUT_INSTANCE_ID
};


Varyings OutlinePassVertex(Attributes input)
{
    Varyings output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    float3 positionWS = TransformObjectToWorld(input.positionOS);
    float3 positionVS = TransformWorldToView(positionWS);
    float3 normalWS = TransformObjectToWorldDir(input.tangentOS.rgb); 
    float3 normalVS = TransformWorldToViewDir(normalWS);
    float3 normalCS = TransformWorldToHClipDir(normalWS);
    //positionWS += normalWS * _OutlineWidth * ApplyOutlineDistanceFadeOut(positionVS.z);
    output.postionCS = TransformWorldToHClip(positionWS);
    
    //float3 scale = GetModelScaleMatrix();
    float3 extension = normalCS;

    //float aspect = _ScreenParams.y / _ScreenParams.x;
    //extension.x *= aspect;
    output.postionCS.xyz += extension * GetOutlineWidth() * ApplyOutlineDistanceFadeOut(positionVS.z) *(input.color.r);
    
    output.uv = input.uv;
    #ifdef _ZOFFSET
        float mask = 1 - GetOutlineZOffsetMask(input.uv);
        float offset = (GetOutlineZOffsetStrength() + 0.1 - input.color.b*0.1) * mask;
        offset = (offset-GetOutlineZOffsetMaskRemapStart())/(GetOutlineZOffsetMaskRemapEnd()-GetOutlineZOffsetMaskRemapStart());
        output.postionCS = GetNewClipPosWithZOffset(output.postionCS,offset);
    #endif
    output.vis_debug = GetOutlineZOffsetStrength();
    return output;
}

float4 OutlinePassFragment(Varyings input) : SV_Target
{
    float4 col = GetOutlineColor();
    return col;
}
#endif