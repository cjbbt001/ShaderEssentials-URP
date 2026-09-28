Shader "URP/PostProcess/MotionBlurWithDepthTexture"
{
    Properties
    {
        _BlurSize ("Blur Size", Float) = 1
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

        CBUFFER_START(UnityPerMaterial)
        half _BlurSize;
        // 这两个矩阵由脚本每帧传入，用来比较当前帧和上一帧的位置。
        float4x4 _CurrentViewProjectionInverseMatrix;
        float4x4 _PreviousViewProjectionMatrix;
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
                float rawDepth = SampleSceneDepth(input.texcoord);
                float4 worldPosition = float4(
                    ComputeWorldSpacePosition(input.texcoord, rawDepth, _CurrentViewProjectionInverseMatrix), 1);

                // 把同一个世界坐标投影回上一帧，差值就是这个像素的运动方向。
                float4 previousClipPosition = mul(_PreviousViewProjectionMatrix, worldPosition);
                previousClipPosition /= previousClipPosition.w;
                float2 currentNdc = input.texcoord * 2 - 1;
                float2 velocity = (currentNdc - previousClipPosition.xy) * 0.5;

                half4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord);
                float2 uv = input.texcoord;
                [unroll]
                for (int i = 1; i < 3; i++)
                {
                    uv += velocity * _BlurSize;
                    color += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv);
                }

                return half4(color.rgb / 3, 1);
            }

            ENDHLSL
        }
    }

    Fallback Off
}
