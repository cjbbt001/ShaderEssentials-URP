Shader "cjbbt/ScrollingBackground"
{
    Properties
    {
        _MainTex ("Base Layer (RGB)", 2D) = "white" {}
        _DetailTex ("2nd Layer (RGB)", 2D) = "white" {}
        _ScrollX ("Base Layer Scroll Speed", Float) = 1.0
        _Scroll2X ("2nd Layer Scroll Speed", Float) = 1.0
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float4 uv : TEXCOORD0;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            TEXTURE2D(_DetailTex);
            SAMPLER(sampler_DetailTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _DetailTex_ST;
                float _ScrollX;
                float _Scroll2X;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv.xy = TRANSFORM_TEX(IN.uv, _MainTex) + frac(float2(_ScrollX, 0) * _Time.y);
                OUT.uv.zw = TRANSFORM_TEX(IN.uv, _DetailTex) + frac(float2(_Scroll2X, 0) * _Time.y);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 layer1 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv.xy);
                half4 layer2 = SAMPLE_TEXTURE2D(_DetailTex, sampler_DetailTex, IN.uv.zw);
                half4 color = lerp(layer1, layer2, layer2.a);
                return color;
            }
            ENDHLSL
        }
    }
}
