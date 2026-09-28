Shader "URP/PostProcess/MotionBlur"
{
    Properties
    {
        _BlurAmount ("Blur Amount", Float) = 0.5
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float _BlurAmount;
        CBUFFER_END

        ENDHLSL

        Pass
        {
            Name "BLEND_RGB"

            // 用当前帧颜色的 Alpha 混合到上一帧累积结果上。
            Blend SrcAlpha OneMinusSrcAlpha
            ColorMask RGB
            ZTest Always
            Cull Off
            ZWrite Off

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag

            half4 frag(Varyings input) : SV_Target
            {
                half3 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord).rgb;
                return half4(color, _BlurAmount);
            }

            ENDHLSL
        }

        Pass
        {
            Name "COPY"

            // 初始化历史图和最终输出都要写 RGBA。
            // COPY_ALPHA 的 ColorMask 只写 A，新分配的历史图 RGB 会留在默认的蓝色。
            Blend One Zero
            ZTest Always
            Cull Off
            ZWrite Off

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag

            half4 frag(Varyings input) : SV_Target
            {
                return SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord);
            }

            ENDHLSL
        }

        Pass
        {
            Name "COPY_ALPHA"

            // 只恢复 Alpha，避免上一个混合 Pass 改掉历史纹理的 Alpha。
            Blend One Zero
            ColorMask A
            ZTest Always
            Cull Off
            ZWrite Off

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag

            half4 frag(Varyings input) : SV_Target
            {
                return SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord);
            }

            ENDHLSL
        }
    }

    Fallback Off
}
