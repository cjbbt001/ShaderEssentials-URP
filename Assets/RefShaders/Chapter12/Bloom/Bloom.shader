Shader "URP/Chapter12/Bloom"
{
    Properties
    {
        _Bloom ("Bloom RGB", 2D) = "black" {}
        _BloomIntensity ("Bloom Intensity", Float) = 1.0
        _LuminanceThreshold ("Luminance Threshold", Float) = 0.5
        _BlurSize ("Blur Size", Float) = 1.0
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float _LuminanceThreshold;
        float _BloomIntensity;
        CBUFFER_END

        TEXTURE2D(_Bloom);
        SAMPLER(sampler_Bloom);

        ENDHLSL

        Pass
        {
            ZTest Always
            Cull Off
            ZWrite Off

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag

            half luminance(half4 color)
            {
                return 0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b;
            }

            half4 frag(Varyings i) : SV_Target
            {
                half4 texColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord);

                //根据亮度确定哪些地方需要进行泛光效果
                half val = clamp(luminance(texColor) - _LuminanceThreshold, 0.0, 1.0);
                return texColor * val;
            }
            ENDHLSL
        }

        UsePass "URP/Chapter12/GaussianBlur/VERTICAL_GAUSSIANBLUR"
        UsePass "URP/Chapter12/GaussianBlur/HORIZONTAL_GAUSSIANBLUR"

        Pass
        {
            ZTest Always
            Cull Off
            ZWrite Off

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag

            half4 frag(Varyings i) : SV_Target
            {
                half4 texColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord);
                half4 bloomColor = SAMPLE_TEXTURE2D(_Bloom, sampler_LinearClamp, i.texcoord) * _BloomIntensity;

                return texColor + bloomColor;
            }
            ENDHLSL
        }
    }

    Fallback Off
}