Shader "URP/PostProcess/FogWithDepthTexture"
{
    Properties
    {
        _FogDensity ("Fog Density", Float) = 1
        _FogColor ("Fog Color", Color) = (1, 1, 1, 1)
        _FogStart ("Fog Start", Float) = 0
        _FogEnd ("Fog End", Float) = 10
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
        // SampleSceneDepth 和 ComputeWorldSpacePosition 来自深度纹理库。
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float _FogDensity;
        float _FogStart;
        float _FogEnd;
        float4 _FogColor;
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
                // 用深度还原世界坐标，再按高度决定雾的浓度。
                float rawDepth = SampleSceneDepth(input.texcoord);
                float3 worldPosition = ComputeWorldSpacePosition(input.texcoord, rawDepth, UNITY_MATRIX_I_VP);
                float fogFactor = saturate(((_FogEnd - worldPosition.y) / (_FogEnd - _FogStart)) * _FogDensity);

                half4 sourceColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord);
                half3 color = lerp(sourceColor.rgb, _FogColor.rgb, fogFactor);
                return half4(color, sourceColor.a);
            }

            ENDHLSL
        }
    }

    Fallback Off
}
