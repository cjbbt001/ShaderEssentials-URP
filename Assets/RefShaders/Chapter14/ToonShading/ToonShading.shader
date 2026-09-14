Shader "URP/Chapter14/ToonShading"
{
Properties
{
_Color("Color Tint", Color) = (1, 1, 1, 1)
_MainTex("Main Tex", 2D) = "white" {}
_Ramp("Ramp Texture", 2D) = "white" {}
_Outline("Outline", Range(0, 1)) = 0.1
_OutlineColor("Outline Color", Color) = (0, 0, 0, 1)
_Specular("Specular", Color) = (1, 1, 1, 1)
_SpecularScale("Specular Scale", Range(0, 0.1)) = 0.01
}

SubShader
{
Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque"}

HLSLINCLUDE
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

CBUFFER_START(UnityPerMaterial)
float4 _MainTex_ST;
float _Outline;
half4 _OutlineColor;
half4 _Color;
half4 _Specular;
half _SpecularScale;
CBUFFER_END
ENDHLSL

Pass
{
NAME "OUTLINE"
Cull Front

HLSLPROGRAM
#pragma vertex vert
#pragma fragment frag

struct a2v
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
};

struct v2f
{
    float4 pos : SV_POSITION;
};

v2f vert(a2v v)
{
    v2f o;
    float4 pos = mul(UNITY_MATRIX_MV, v.vertex);
    float3 normal = mul((float3x3)UNITY_MATRIX_IT_MV, v.normal);
    // 向背面扩展顶点以进行描边
    normal.z = -0.5;
    pos = pos + float4(normalize(normal), 0) * _Outline;
    o.pos = mul(UNITY_MATRIX_P, pos);
    return o;
}

float4 frag(v2f i) : SV_Target
{
    return float4(_OutlineColor.rgb, 1);
}
ENDHLSL
}

Pass
{
Tags {"LightMode"="UniversalForward"}
Cull Back

HLSLPROGRAM
#pragma vertex vert
#pragma fragment frag

TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex);
TEXTURE2D(_Ramp);
SAMPLER(sampler_Ramp);

struct a2v
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float4 texcoord : TEXCOORD0;
};

struct v2f
{
    float4 pos : POSITION;
    float2 uv : TEXCOORD0;
    float3 worldNormal : TEXCOORD1;
    float3 worldPos : TEXCOORD2;
};

v2f vert(a2v v)
{
    v2f o;
    VertexPositionInputs positionInputs = GetVertexPositionInputs(v.vertex.xyz);
    o.worldPos = positionInputs.positionWS;
    o.pos = positionInputs.positionCS;
    o.worldNormal = TransformObjectToWorldNormal(v.normal);
    o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
    return o;
}

float4 frag(v2f i) : SV_Target
{
    Light mainLight = GetMainLight();
    half3 worldLightDir = normalize(mainLight.direction);
    half3 worldViewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);
    half3 worldHalfDir = normalize(worldLightDir + worldViewDir);

    half4 c = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
    half3 albedo = c.rgb * _Color.rgb;

    // diffuse
    half diff = dot(i.worldNormal, worldLightDir);
    diff = (diff * 0.5 + 0.5);
    half3 diffuse = mainLight.color * albedo * SAMPLE_TEXTURE2D(_Ramp, sampler_Ramp, float2(diff, diff)).rgb;

    // ambient
    half3 ambient = 0.02 * albedo;

    // specular
    half spec = dot(i.worldNormal, worldHalfDir);
    // abs(ddx(x)) + abs(ddy(x))
    half w = fwidth(spec) * 2.0;
    half3 specular = mainLight.color * _Specular.rgb * lerp(0, 1, smoothstep(-w, w, spec + _SpecularScale - 1)) * step(0.0001, _SpecularScale);

    return half4(ambient + diffuse + specular, 1.0);
}
ENDHLSL
}
}
FallBack Off
}