Shader "URP/PostProcess/EdgeDetectNormalsAndDepth"
{
    Properties
    {
        _EdgeOnly ("Edge Only", Float) = 1
        _EdgeColor ("Edge Color", Color) = (0, 0, 0, 1)
        _BackgroundColor ("Background Color", Color) = (1, 1, 1, 1)
        _SampleDistance ("Sample Distance", Float) = 1
        _Sensitivity ("Sensitivity", Vector) = (1, 1, 1, 1)
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
        // SampleSceneNormals 来自法线纹理库。
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"

        CBUFFER_START(UnityPerMaterial)
        half _EdgeOnly;
        half4 _EdgeColor;
        half4 _BackgroundColor;
        float _SampleDistance;
        half4 _Sensitivity;
        CBUFFER_END

        half CheckSame(half2 firstNormal, half2 secondNormal, half firstDepth, half secondDepth)
        {
            half2 normalDifference = abs(firstNormal - secondNormal) * _Sensitivity.x;
            bool sameNormal = normalDifference.x + normalDifference.y < 0.1;

            float depthDifference = abs(firstDepth - secondDepth) * _Sensitivity.y;
            bool sameDepth = depthDifference < 0.1 * firstDepth;
            return sameNormal && sameDepth ? 1 : 0;
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

            half4 frag(Varyings input) : SV_Target
            {
                // Roberts 算子使用两条对角线，而不是颜色版边缘检测的 3x3 邻域。
                float2 diagonalA = _BlitTexture_TexelSize.xy * float2(1, 1) * _SampleDistance;
                float2 diagonalB = _BlitTexture_TexelSize.xy * float2(-1, 1) * _SampleDistance;

                // AB、CD是对角线
                float2 uvA = input.texcoord + diagonalA;
                float2 uvB = input.texcoord - diagonalA;
                float2 uvC = input.texcoord + diagonalB;
                float2 uvD = input.texcoord - diagonalB;

                half edge = CheckSame(
                    SampleSceneNormals(uvA).xy,
                    SampleSceneNormals(uvB).xy,
                    LinearEyeDepth(SampleSceneDepth(uvA), _ZBufferParams),
                    LinearEyeDepth(SampleSceneDepth(uvB), _ZBufferParams));
                edge *= CheckSame(
                    SampleSceneNormals(uvC).xy,
                    SampleSceneNormals(uvD).xy,
                    LinearEyeDepth(SampleSceneDepth(uvC), _ZBufferParams),
                    LinearEyeDepth(SampleSceneDepth(uvD), _ZBufferParams));

                half4 sourceColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord);
                half4 withEdgeColor = lerp(_EdgeColor, sourceColor, edge);
                half4 onlyEdgeColor = lerp(_EdgeColor, _BackgroundColor, edge);
                return lerp(withEdgeColor, onlyEdgeColor, _EdgeOnly);
            }

            ENDHLSL
        }
    }

    Fallback Off
}
