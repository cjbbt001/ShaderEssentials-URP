Shader "URP/Chapter7/RampTexture"
{
    Properties
    {
        [HideInInspector]
        _MainTex ("Texture", 2D) = "white" {}
        _Ramp ("Ramp", 2D) = "white" {}
        _BaseColor ("BaseColor", Color) =  (1, 1, 1, 1)
        _SpecularColor ("Specular Color", Color) =  (1, 1, 1, 1)
        _Shiness ("Shiness", Range(1,256)) = 32
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        half4 _BaseColor;
        half4 _SpecularColor;
        float _Shiness;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        TEXTURE2D(_Ramp);
        SAMPLER(sampler_Ramp);

        struct a2v
        {
            float4 vertex : POSITION;
            float3 normal : NORMAL;
            float4 tangent : TANGENT;
            float2 uv : TEXCOORD0;
        };

        struct v2f
        {
            float2 uv : TEXCOORD0;
            float3 normal : TEXCOORD1;
            float3 fragWS : TEXCOORD2;
            float4 vertex : SV_POSITION;
        };

        ENDHLSL

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            v2f vert(a2v v)
            {
                v2f o;

                VertexPositionInputs positionInputs = GetVertexPositionInputs(v.vertex.xyz);
                o.vertex = positionInputs.positionCS;
                o.fragWS = positionInputs.positionWS;

                VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normal, v.tangent);
                o.normal = normalInputs.normalWS;

                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                Light light = GetMainLight();
                float3 worldNormal = normalize(i.normal);
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.fragWS);

                float3 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).xyz;

                //[-1,1]->[-0.5,0.5]->[0,1]
                float halfLambert = 0.5 * dot(light.direction, worldNormal) + 0.5;
                float3 rampColor = SAMPLE_TEXTURE2D(_Ramp, sampler_Ramp, half2(halfLambert, halfLambert)).xyz;
                float3 diffuse = (light.color * _BaseColor.rgb) * rampColor;

                float3 h = normalize(light.direction + viewDir);
                float3 specular = (light.color * _SpecularColor.rgb) * pow(max(dot(worldNormal, h), 0), _Shiness);

                float3 ambient = 0.01;
                float3 finalColor = diffuse + specular + ambient;

                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
}