Shader "URP/Chapter11/ScrollingBackground"
{
    Properties
    {
        _MainTex ("Base Layer (RGB)", 2D) = "white" {}
        _DetailTex ("2nd Layer (RGB)", 2D) = "white" {}
        _ScrollX ("Base Layer Scroll Speed", Float) = 1.0
        _Scroll2X ("2nd Layer Scroll Speed", Float) = 1.0
        _Multiplier ("Layer Multiplier", Float) = 1.0
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        float4 _DetailTex_ST;
        float _ScrollX;
        float _Scroll2X;
        float _Multiplier;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        TEXTURE2D(_DetailTex);
        SAMPLER(sampler_DetailTex);

        struct a2v
        {
            float4 vertex : POSITION;
            float3 normal : NORMAL;
            float4 tangent : TANGENT;
            float2 uv : TEXCOORD0;
        };

        struct v2f
        {
            float4 uv : TEXCOORD0;
            float3 normal : TEXCOORD1;
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

                VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normal, v.tangent);
                o.normal = normalInputs.normalWS;

                o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex) + frac(half2(_ScrollX, 0) * _Time.y);
                o.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex) + frac(half2(_Scroll2X, 0) * _Time.y);

                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                half4 baseColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy);
                half4 secondColor = SAMPLE_TEXTURE2D(_DetailTex, sampler_DetailTex, i.uv.zw);

                half4 finalColor = lerp(baseColor, secondColor, secondColor.a);
                finalColor.rgb *= _Multiplier;

                return finalColor;
            }
            ENDHLSL
        }
    }
}