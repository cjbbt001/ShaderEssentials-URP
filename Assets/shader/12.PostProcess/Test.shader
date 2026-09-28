Shader "URP/PostProcess/Test"
{
    Properties
    {
        _Brightness ("Brightness", Float) = 1
        _Saturation ("Saturation", Float) = 1
        _Contrast ("Contrast", Float) = 1
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        // Vert、Varyings、_BlitTexture 都由 Blit.hlsl 提供
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float _Brightness;
        float _Saturation;
        float _Contrast;
        CBUFFER_END

        ENDHLSL

        Pass
        {
            ZTest Always
            Cull Off
            ZWrite Off

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag

            half4 frag(Varyings input) : SV_Target
            {
                half4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord);

                // 亮度：整体缩放 RGB。1 不变，大于 1 更亮，小于 1 更暗。
                half3 result = color.rgb * _Brightness;

                // 饱和度：向灰度插值。0 是灰度，1 是当前颜色，大于 1 更鲜艳。
                half luminance = dot(color.rgb, half3(0.2125, 0.7154, 0.0721));
                result = lerp(half3(luminance, luminance, luminance), result, _Saturation);

                // 对比度：向中灰插值。0 是一片灰，1 不变，大于 1 反差更大。
                result = lerp(half3(0.5, 0.5, 0.5), result, _Contrast);

                return half4(result, color.a);
            }

            ENDHLSL
        }
    }

    Fallback Off
}
