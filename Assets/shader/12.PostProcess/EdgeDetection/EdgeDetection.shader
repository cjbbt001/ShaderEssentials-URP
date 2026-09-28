Shader "URP/PostProcess/EdgeDetection"
{
    Properties
    {
        _EdgeOnly ("Edge Only", Float) = 1
        _EdgeColor ("Edge Color", Color) = (0, 0, 0, 1)
        _BackgroundColor ("Background Color", Color) = (1, 1, 1, 1)
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float _EdgeOnly;
        float4 _EdgeColor;
        float4 _BackgroundColor;
        CBUFFER_END

        float Luminance(half3 color)
        {
            return dot(color, half3(0.2125, 0.7154, 0.0721));
        }

        // 采样周围 3x3 像素，用 Sobel 算子求边缘强度。返回值越接近 0，边缘越强。
        float Sobel(Varyings input)
        {
            const half Gx[9] =
            {
                -1, -2, -1,
                 0,  0,  0,
                 1,  2,  1
            };
            const half Gy[9] =
            {
                -1, 0, 1,
                -2, 0, 2,
                -1, 0, 1
            };

            half edgeX = 0;
            half edgeY = 0;

            [unroll]
            for (int y = -1; y <= 1; y++)
            {
                [unroll]
                for (int x = -1; x <= 1; x++)
                {
                    int index = (y + 1) * 3 + (x + 1);
                    float2 uv = input.texcoord + _BlitTexture_TexelSize.xy * float2(x, y);
                    half luminance = Luminance(SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv).rgb);
                    edgeX += luminance * Gx[index];
                    edgeY += luminance * Gy[index];
                }
            }

            return saturate(1 - abs(edgeX) - abs(edgeY));
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
                half4 sourceColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, input.texcoord);
                float edge = Sobel(input);

                // edge 为 0 时使用边缘色，为 1 时保留原图或背景。
                half4 withEdgeColor = lerp(_EdgeColor, sourceColor, edge);
                half4 onlyEdgeColor = lerp(_EdgeColor, _BackgroundColor, edge);
                return lerp(withEdgeColor, onlyEdgeColor, _EdgeOnly);
            }

            ENDHLSL
        }
    }

    Fallback Off
}
