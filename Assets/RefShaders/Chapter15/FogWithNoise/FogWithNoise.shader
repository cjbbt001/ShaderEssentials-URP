Shader "URP/Chapter15/FogWithNoise"
{
    Properties
    {
        _FogDensity ("Fog Density", Float) = 1.0
        _FogColor ("Fog Color", Color) =  (1, 1, 1, 1)
        _FogStart ("Fog Start", Float) = 0.0
        _FogEnd ("Fog End", Float) = 1.0
        _NoiseTex ("Noise Texture", 2D) = "white" {}
        _FogXSpeed ("Fog Horizontal Speed", Float) = 0.1
        _FogYSpeed ("Fog Vertical Speed", Float) = 0.1
        _NoiseAmount ("Noise Amount", Float) = 1
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
        float _FogXSpeed;
        float _FogYSpeed;
        float _NoiseAmount;
        CBUFFER_END

        TEXTURE2D(_NoiseTex);
        SAMPLER(sampler_NoiseTex);

        half4 frag(Varyings i) : SV_Target
        {
            float rawDepth = SampleSceneDepth(i.texcoord);
            float3 worldPos = ComputeWorldSpacePosition(i.texcoord, rawDepth, UNITY_MATRIX_I_VP);

            float2 speed = _Time.y * float2(_FogXSpeed, _FogYSpeed);
            float noise = (SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, i.texcoord + speed).r - 0.5) * _NoiseAmount;

            if (_FogEnd <= _FogStart)
            {
                _FogStart = _FogEnd - 0.0001;
            }

            float fogDensity = (_FogEnd - worldPos.y) / (_FogEnd - _FogStart);
            fogDensity = saturate(fogDensity * _FogDensity * (1 + noise));

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