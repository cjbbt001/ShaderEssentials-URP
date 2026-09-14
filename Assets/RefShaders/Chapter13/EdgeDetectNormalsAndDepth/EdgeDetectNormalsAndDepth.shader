Shader "URP/Chapter13/EdgeDetectNormalAndDepth"
{
    Properties
    {
        _EdgeOnly ("Edge Only", Float) = 1.0
        _EdgeColor ("Edge Color", Color) =  (0, 0, 0, 1)
        _BackgroundColor ("Background Color", Color) =  (1, 1, 1, 1)
        _SampleDistance ("Sample Distance", Float) = 1.0
        _Sensitivity ("Sensitivity", Vector) =  (1, 1, 1, 1)
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"

        CBUFFER_START(UnityPerMaterial)
        half _EdgeOnly;
        half4 _EdgeColor;
        half4 _BackgroundColor;
        float _SampleDistance;
        half4 _Sensitivity;
        CBUFFER_END

        half CheckSame(half2 centerN, half2 sampleN, half centerD, half sampleD)
        {
            half2 centerNormal = centerN;
            float centerDepth = centerD;
            half2 sampleNormal = sampleN;
            float sampleDepth = sampleD;

            //检测法线
            half2 diffNormal = abs(centerNormal - sampleNormal) * _Sensitivity.x;
            int isSameNormal = (diffNormal.x + diffNormal.y) < 0.1;

            //检测深度
            float diffDepth = abs(centerDepth - sampleDepth) * _Sensitivity.y;
            int isSameDepth = diffDepth < 0.1 * centerDepth;

            return isSameNormal * isSameDepth ? 1.0 : 0.0;
        }

        half4 frag(Varyings i) : SV_Target
        {
            //Roberts算子
            half2 uv[5];
            uv[0] = i.texcoord;
            uv[1] = i.texcoord + _BlitTexture_TexelSize.xy * half2(1, 1) * _SampleDistance;
            uv[2] = i.texcoord + _BlitTexture_TexelSize.xy * half2(-1, -1) * _SampleDistance;
            uv[3] = i.texcoord + _BlitTexture_TexelSize.xy * half2(-1, 1) * _SampleDistance;
            uv[4] = i.texcoord + _BlitTexture_TexelSize.xy * half2(1, -1) * _SampleDistance;

            //采样法线
            half2 sample1Normal = SampleSceneNormals(uv[1]).xy;
            half2 sample2Normal = SampleSceneNormals(uv[2]).xy;
            half2 sample3Normal = SampleSceneNormals(uv[3]).xy;
            half2 sample4Normal = SampleSceneNormals(uv[4]).xy;

            //采样深度
            half sample1Depth = LinearEyeDepth(SampleSceneDepth(uv[1]), _ZBufferParams);
            half sample2Depth = LinearEyeDepth(SampleSceneDepth(uv[2]), _ZBufferParams);
            half sample3Depth = LinearEyeDepth(SampleSceneDepth(uv[3]), _ZBufferParams);
            half sample4Depth = LinearEyeDepth(SampleSceneDepth(uv[4]), _ZBufferParams);

            //当前像素是否是边缘
            half isSame = 1.0;
            isSame *= CheckSame(sample1Normal, sample2Normal, sample1Depth, sample2Depth);
            isSame *= CheckSame(sample3Normal, sample4Normal, sample3Depth, sample4Depth);

            half4 withEdgeColor = lerp(_EdgeColor, SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv[0]), isSame);
            half4 onlyEdgeColor = lerp(_EdgeColor, _BackgroundColor, isSame);

            return lerp(withEdgeColor, onlyEdgeColor, _EdgeOnly);
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