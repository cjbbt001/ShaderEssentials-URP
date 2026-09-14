Shader "URP/Chapter13/FogWithDepthTexture"
{
    Properties
    {
        _FogDensity ("Fog Density", Float) = 1.0
        _FogColor ("Fog Color", Color) =  (1, 1, 1, 1)
        _FogStart ("Fog Start", Float) = 0.0
        _FogEnd ("Fog End", Float) = 1.0
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float _FogDensity;
        float _FogStart;
        float _FogEnd;
        float4 _FogColor;
        CBUFFER_END

        half4 frag(Varyings i) : SV_Target
        {
            float rawDepth = SampleSceneDepth(i.texcoord);
            float3 worldPos = ComputeWorldSpacePosition(i.texcoord, rawDepth, UNITY_MATRIX_I_VP);

            float fogDensity = (_FogEnd - worldPos.y) / (_FogEnd - _FogStart);
            fogDensity = saturate(fogDensity * _FogDensity);

            half4 texColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord);

            half3 finalColor = lerp(texColor.rgb, _FogColor.rgb, fogDensity);

            return half4(finalColor, texColor.a);
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