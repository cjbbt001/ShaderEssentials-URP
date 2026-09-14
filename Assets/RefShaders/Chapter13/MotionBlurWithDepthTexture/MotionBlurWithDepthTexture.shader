Shader "URP/Chapter13/MotionBlurWithDepthTexture"
{
    Properties
    {
        _BlurSize ("Blur Size", Float) = 1.0
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
        //专门用于采样深度纹理的库
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

        CBUFFER_START(UnityPerMaterial)
        half _BlurSize;
        float4x4 _CurrentViewProjectionInverseMatrix;
        float4x4 _PreviousViewProjectionMatrix;
        CBUFFER_END

        half4 frag(Varyings i) : SV_Target
        {
            //重建世界空间位置
            float rawDepth = SampleSceneDepth(i.texcoord);
            float4 worldPos = float4(ComputeWorldSpacePosition(i.texcoord, rawDepth, _CurrentViewProjectionInverseMatrix), 1.0);
            //计算上一帧的NDC
            float4 previousPos = mul(_PreviousViewProjectionMatrix, worldPos);
            previousPos /= previousPos.w;
            //计算当前帧的NDC
            float4 currentPos = float4(i.texcoord.x * 2 - 1, i.texcoord.y * 2 - 1, rawDepth * 2 - 1, 1);

            //计算Motion Vector
            float2 velocity = (currentPos.xy - previousPos.xy) / 2.0f;

            float4 finalColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord);

            float2 uv = i.texcoord;
            uv += velocity * _BlurSize;
            for (int it = 1; it < 3; it++)
            {
                float4 currentColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv);
                finalColor += currentColor;

                uv += velocity * _BlurSize;
            }

            //保证能量守恒
            finalColor /= 3;

            return half4(finalColor.rgb, 1.0);
        }

        ENDHLSL

        Pass
        {
            ZTest Always
            Cull Off
            ZWrite Off

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag

            ENDHLSL
        }
    }
    FallBack Off
}