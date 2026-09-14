Shader "URP/Chapter12/EdgeDetection"
{
    Properties
    {
        _EdgeOnly ("Edge Only", Float) = 1.0
        _EdgeColor ("Edge Color", Color) =  (0, 0, 0, 1)
        _BackgroundColor ("Background Color", Color) =  (1, 1, 1, 1)
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        //Blit.hlsl包含了屏幕后处理所需的顶点着色器和纹理
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float _EdgeOnly;
        float4 _EdgeColor;
        float4 _BackgroundColor;
        CBUFFER_END

        ENDHLSL

        Pass
        {
            //后处理必要的设置
            ZTest Always
            Cull Off
            ZWrite Off

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag

            float luminance(float4 color)
            {
                return 0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b;
            }

            float Sobel(Varyings i)
            {
                //Sobel算子
                const half Gx[9] = { -1, -2, -1, 0, 0, 0, 1, 2, 1 };
                const half Gy[9] = { -1, 0, 1, -2, 0, 2, -1, 0, 1 };

                half2 uv[9];
                uv[0] = i.texcoord + _BlitTexture_TexelSize.xy * half2(-1, -1);
                uv[1] = i.texcoord + _BlitTexture_TexelSize.xy * half2(0, -1);
                uv[2] = i.texcoord + _BlitTexture_TexelSize.xy * half2(1, -1);
                uv[3] = i.texcoord + _BlitTexture_TexelSize.xy * half2(-1, 0);
                uv[4] = i.texcoord + _BlitTexture_TexelSize.xy * half2(0, 0);
                uv[5] = i.texcoord + _BlitTexture_TexelSize.xy * half2(1, 0);
                uv[6] = i.texcoord + _BlitTexture_TexelSize.xy * half2(-1, 1);
                uv[7] = i.texcoord + _BlitTexture_TexelSize.xy * half2(0, 1);
                uv[8] = i.texcoord + _BlitTexture_TexelSize.xy * half2(1, 1);

                half texColor;
                half edgeX = 0;
                half edgeY = 0;

                for (int it = 0; it < 9; ++it)
                {
                    texColor = luminance(SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv[it]));
                    edgeX += texColor * Gx[it];
                    edgeY += texColor * Gy[it];
                }

                half edge = 1 - abs(edgeX) - abs(edgeY);
                edge = saturate(edge);

                return edge;
            }

            half4 frag(Varyings i) : SV_Target
            {
                half4 texColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord);
                float edge = Sobel(i);

                half4 withEdgeColor = lerp(_EdgeColor, texColor, edge);
                half4 onlyEdgeColor = lerp(_EdgeColor, _BackgroundColor, edge);

                return lerp(withEdgeColor, onlyEdgeColor, _EdgeOnly);
            }
            ENDHLSL
        }
    }
}