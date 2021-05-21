#ifndef CUSTOM_COLOR_BLEND_INCLUDED
#define CUSTOM_COLOR_BLEND_INCLUDED

#define SOFT_LIGHT(A,B) \
    B <= 0.5 ? A*B*2+A*A*(1-2*B) : A*(1-B)*2+sqrt(A)*(2*B-1)
#define OVERLAY(A,B) \
    A<=0.5 ? A*B*2 : 1-(1-A)*(1-B)*2 
#define COLOR_DODGE(A,B) \
    A + A*B/(1-B)
#define SCREEN(A,B) \
    1-(1-A)*(1-B)
float4 Soft_Light(float4 A,float4 B)
{
    return float4(SOFT_LIGHT(A.x, B.x),
                SOFT_LIGHT(A.y, B.y),
                SOFT_LIGHT(A.z, B.z),
                SOFT_LIGHT(A.w, B.w));
}
float3 Soft_Light(float3 A, float3 B)
{
    return float3(SOFT_LIGHT(A.x, B.x),
                SOFT_LIGHT(A.y, B.y),
                SOFT_LIGHT(A.z, B.z));
}

float3 ColorDodge(float3 A,float3 B)
{
    return COLOR_DODGE(A, B);
}
#endif
