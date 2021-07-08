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

float ApplyOutlineDistanceFadeOut(float positionVS_Z)
{
    #ifdef UNITY_REVERSED_Z
        positionVS_Z = abs(positionVS_Z);
    #endif
    positionVS_Z = smoothstep(25.0, 0.5f, positionVS_Z);
    return positionVS_Z * 0.01;
}

float4 GetNewClipPosWithZOffset(float4 originalPositionCS, float viewSpaceZOffsetAmount)
{
    if (unity_OrthoParams.w == 0)
    {
        ////////////////////////////////
        //Perspective camera case
        ////////////////////////////////
        float2 ProjM_ZRow_ZW = UNITY_MATRIX_P[2].zw;
        float modifiedPositionVS_Z = -originalPositionCS.w + -viewSpaceZOffsetAmount; // push imaginary vertex
        float modifiedPositionCS_Z = modifiedPositionVS_Z * ProjM_ZRow_ZW[0] + ProjM_ZRow_ZW[1];
        //-modifiedPositionVS_Z = modifiedPositionCS.w, here make modifiedPositionCS_Z value scale to origin.w
        originalPositionCS.z = modifiedPositionCS_Z * originalPositionCS.w / (-modifiedPositionVS_Z);
        
        return originalPositionCS;
    }
    else
    {
        ////////////////////////////////
        //Orthographic camera case
        ////////////////////////////////
        originalPositionCS.z += (-viewSpaceZOffsetAmount) / _ProjectionParams.z; // push imaginary vertex and overwrite positionCS.z
        return originalPositionCS;
    }
}
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
    
    float3 scale = GetModelScaleMatrix();
    float3 extension = normalCS * scale;

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