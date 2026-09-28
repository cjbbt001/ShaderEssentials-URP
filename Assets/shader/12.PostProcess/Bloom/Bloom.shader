Shader "URP/PostProcess/Bloom"
{
    Properties
    {
        _LuminanceThreshold ("Luminance Threshold", Float) = 0.6
        _BlurSize ("Blur Size", Float) = 1
        _BloomIntensity ("Bloom Intensity", Float) = 1
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float _LuminanceThreshold;
        float _BlurSize;
        float _BloomIntensity;
        CBUFFER_END

        // 合成时原图走 _BlitTexture，模糊后的亮部单独绑到这张图。
        TEXTURE2D(_Bloom);
        SAMPLER(sampler_Bloom);

        static const float Weights[3] = { 0.4026, 0.2442, 0.0545 };

        half Luminance(half3 color)
        {
            return dot(color, half3(0.2125, 0.7154, 0.0721));
        }

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
            Name "EXTRACT"

            ZTest Always
            Cull Off
            ZWrite Off

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag

            // Pass 0：亮度超过阈值的部分留下来，其余压成黑色。
            // 用 (亮度 - 阈值) 做缩放，越亮的地方贡献越大，避免硬切边。
            half4 frag(Varyings input) : SV_Target
            {
                half4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord);
                half brightness = saturate(Luminance(color.rgb) - _LuminanceThreshold);
                return half4(color.rgb * brightness, 1);
            }

            ENDHLSL
        }

        Pass
        {
            Name "VERTICAL"

            ZTest Always
            Cull Off
            ZWrite Off

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag

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

            half4 frag(Varyings input) : SV_Target
            {
                return Blur(input, float2(1, 0));
            }

            ENDHLSL
        }

        Pass
        {
            Name "COMPOSITE"

            ZTest Always
            Cull Off
            ZWrite Off

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag

            // Pass 3：原图加上模糊后的亮部。
            half4 frag(Varyings input) : SV_Target
            {
                half4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord);
                half3 bloom = SAMPLE_TEXTURE2D(_Bloom, sampler_LinearClamp, input.texcoord).rgb;
                return half4(color.rgb + bloom * _BloomIntensity, color.a);
            }

            ENDHLSL
        }
    }

    Fallback Off
}
