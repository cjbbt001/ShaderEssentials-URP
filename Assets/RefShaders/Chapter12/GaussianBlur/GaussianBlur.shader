Shader "URP/Chapter12/GaussianBlur"
{
    Properties
    {
        _BlurSize ("Blur Size", Float) = 1.0
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        //Blit.hlsl包含了屏幕后处理所需的顶点着色器和纹理
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float _BlurSize;
        CBUFFER_END

        ENDHLSL

        Pass
        {
            Name "VERTICAL_GAUSSIANBLUR"

            ZTest Always
            Cull Off
            ZWrite Off

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag

            half4 frag(Varyings i) : SV_Target
            {
                float weight[3] = { 0.4026, 0.2442, 0.0545 };

                half2 uv[5];
                uv[0] = i.texcoord;
                uv[1] = i.texcoord + float2(0.0, _BlitTexture_TexelSize.y * 1.0) * _BlurSize;
                uv[2] = i.texcoord - float2(0.0, _BlitTexture_TexelSize.y * 1.0) * _BlurSize;
                uv[3] = i.texcoord + float2(0.0, _BlitTexture_TexelSize.y * 2.0) * _BlurSize;
                uv[4] = i.texcoord - float2(0.0, _BlitTexture_TexelSize.y * 2.0) * _BlurSize;

                half3 texColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv[0]).rgb * weight[0];

                for (int it = 1; it < 3; ++it)
                {
                    texColor += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv[2*it-1]).rgb * weight[it];
                    texColor += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv[2*it]).rgb * weight[it];
                }

                return half4(texColor, 1.0);
            }
            ENDHLSL
        }

        Pass
        {
            Name "HORIZONTAL_GAUSSIANBLUR"

            ZTest Always
            Cull Off
            ZWrite Off

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag

            half4 frag(Varyings i) : SV_Target
            {
                float weight[3] = { 0.4026, 0.2442, 0.0545 };

                half2 uv[5];
                uv[0] = i.texcoord;
                uv[1] = i.texcoord + float2(_BlitTexture_TexelSize.x * 1.0, 0.0) * _BlurSize;
                uv[2] = i.texcoord - float2(_BlitTexture_TexelSize.x * 1.0, 0.0) * _BlurSize;
                uv[3] = i.texcoord + float2(_BlitTexture_TexelSize.x * 2.0, 0.0) * _BlurSize;
                uv[4] = i.texcoord - float2(_BlitTexture_TexelSize.x * 2.0, 0.0) * _BlurSize;

                half3 texColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv[0]).rgb * weight[0];

                for (int it = 1; it < 3; ++it)
                {
                    texColor += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv[2*it-1]).rgb * weight[it];
                    texColor += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv[2*it]).rgb * weight[it];
                }

                return half4(texColor, 1.0);
            }
            ENDHLSL
        }
    }
}