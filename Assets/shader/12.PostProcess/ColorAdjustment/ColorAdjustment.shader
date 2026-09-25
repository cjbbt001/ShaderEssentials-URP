Shader "URP/PostProcess/ColorAdjustment"
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
        // 对应 Built-in 里 UnityCG.cginc 提供的全屏顶点变换和 _MainTex
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float _Brightness;
        float _Saturation;
        float _Contrast;
        CBUFFER_END

        ENDHLSL

        Pass
        {
            // 和书里一样：永远通过深度测试，不写深度，不剔除
            ZTest Always
            Cull Off
            ZWrite Off

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag

            half4 frag(Varyings i) : SV_Target
            {
                // Built-in: tex2D(_MainTex, i.uv)
                // URP Blit: 源图由管线绑到 _BlitTexture
                half4 renderTex = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord);

                // 亮度：RGB 整体乘。1 不变，>1 更亮，<1 更暗
                half3 finalColor = renderTex.rgb * _Brightness;

                // 饱和度：和灰度图 lerp。0 全灰，1 原色，>1 更艳
                half luminance = dot(renderTex.rgb, half3(0.2125, 0.7154, 0.0721));
                half3 luminanceColor = half3(luminance, luminance, luminance);
                finalColor = lerp(luminanceColor, finalColor, _Saturation);

                // 对比度：和中灰 lerp。0 一片灰，1 原图，>1 反差更大
                half3 avgColor = half3(0.5, 0.5, 0.5);
                finalColor = lerp(avgColor, finalColor, _Contrast);

                return half4(finalColor, renderTex.a);
            }
            ENDHLSL
        }
    }
    Fallback Off
}
