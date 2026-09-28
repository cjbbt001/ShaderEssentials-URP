Shader "URP/PostProcess/GaussianBlur"
{
    Properties
    {
        _BlurSize ("Blur Size", Float) = 1
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float _BlurSize;
        CBUFFER_END

        static const float Weights[3] = { 0.4026, 0.2442, 0.0545 };

        half4 Blur(Varyings input, float2 direction)
        {
            half3 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord).rgb * Weights[0];

            [unroll]
            for (int i = 1; i < 3; i++)
            {
                float2 offset = direction * (_BlitTexture_TexelSize.xy * i * _BlurSize);
                color += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord + offset).rgb * Weights[i];
                color += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord - offset).rgb * Weights[i];
            }

            return half4(color, 1);
        }

        ENDHLSL

        Pass
        {
            Name "VERTICAL"

            ZTest Always
            Cull Off
            ZWrite Off

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag

            // Pass 0：只沿竖直方向采样。
            half4 frag(Varyings input) : SV_Target
            {
                return Blur(input, float2(0, 1));
            }

            ENDHLSL
        }

        Pass
        {
            Name "HORIZONTAL"

            ZTest Always
            Cull Off
            ZWrite Off

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag

            // Pass 1：只沿水平方向采样。两次单向模糊合起来近似二维高斯模糊。
            half4 frag(Varyings input) : SV_Target
            {
                return Blur(input, float2(1, 0));
            }

            ENDHLSL
        }
    }

    Fallback Off
}
