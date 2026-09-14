Shader "URP/Chapter12/BrightnessSaturationAndContrast"
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
        //Blit.hlsl包含了屏幕后处理所需的顶点着色器和纹理
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float _Brightness;
        float _Saturation;
        float _Contrast;
        CBUFFER_END

        ENDHLSL

        Pass
        {
            //后处理必要的设置
            ZTest Always
            Cull Off
            ZWrite Off

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag

            half4 frag(Varyings i) : SV_Target
            {
                half4 texColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord);

                //Brightness
                half3 finalColor = texColor.rgb * _Brightness;

                //Saturation
                float luminance = 0.2125 * texColor.r + 0.7154 * texColor.g + 0.0721 * texColor.b;
                half3 luminanceColor = half3(luminance, luminance, luminance);
                finalColor = lerp(luminanceColor, finalColor, _Saturation);

                //Contrast
                half3 avgColor = half3(0.5, 0.5, 0.5);
                finalColor = lerp(avgColor, finalColor, _Contrast);

                return half4(finalColor, texColor.a);
            }
            ENDHLSL
        }
    }
}