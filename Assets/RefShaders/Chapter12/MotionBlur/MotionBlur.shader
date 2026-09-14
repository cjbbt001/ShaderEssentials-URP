Shader "URP/Chapter12/MotionBlur"
{
    Properties
    {
        _BlurAmount ("Blur Amount", Float) = 1.0
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" }

        ZTest Always
        Cull Off
        ZWrite Off

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float _BlurAmount;
        CBUFFER_END

        ENDHLSL

        Pass
        {
            //用于在原图像上进行叠加，实现运动模糊
            Blend SrcAlpha OneMinusSrcAlpha
            ColorMask RGB

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment fragRGB

            half4 fragRGB(Varyings i) : SV_Target
            {
                return half4(SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord).rgb, _BlurAmount);
            }
            ENDHLSL
        }

        Pass
        {
            Blend One Zero
            ColorMask A

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment fragA

            half4 fragA(Varyings i) : SV_Target
            {
                return SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord);
            }

            ENDHLSL
        }
    }

    Fallback Off
}