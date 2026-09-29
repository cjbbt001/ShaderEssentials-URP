Shader "URP/NPR/Hatching"
{
    Properties
    {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
        _OutlineColor ("Outline Color", Color) = (0, 0, 0, 1)
        _TileFactor ("Tile Factor", Float) = 1              // 笔触贴图平铺次数
        _Outline ("Outline", Range(0, 1)) = 0.1
        _Hatch0 ("Hatch 0", 2D) = "white" {}                // 最亮档，笔触最稀
        _Hatch1 ("Hatch 1", 2D) = "white" {}
        _Hatch2 ("Hatch 2", 2D) = "white" {}
        _Hatch3 ("Hatch 3", 2D) = "white" {}
        _Hatch4 ("Hatch 4", 2D) = "white" {}
        _Hatch5 ("Hatch 5", 2D) = "white" {}                // 最暗档，笔触最密
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" }

        // 复用卡通着色的背面外扩轮廓
        UsePass "URP/NPR/ToonShading/OUTLINE"

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
                float _TileFactor;
            CBUFFER_END

            TEXTURE2D(_Hatch0);
            SAMPLER(sampler_Hatch0);
            TEXTURE2D(_Hatch1);
            SAMPLER(sampler_Hatch1);
            TEXTURE2D(_Hatch2);
            SAMPLER(sampler_Hatch2);
            TEXTURE2D(_Hatch3);
            SAMPLER(sampler_Hatch3);
            TEXTURE2D(_Hatch4);
            SAMPLER(sampler_Hatch4);
            TEXTURE2D(_Hatch5);
            SAMPLER(sampler_Hatch5);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 posWS : TEXCOORD2;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionHCS = positionInputs.positionCS;
                OUT.posWS = positionInputs.positionWS;
                OUT.uv = IN.uv * _TileFactor;
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                return OUT;
            }

            // 亮度映射到 6 张笔触 + 纯白，相邻两档之间线性混合
            void GetHatchWeights(half diff, out half3 weights0, out half3 weights1)
            {
                float hatchFactor = saturate(diff) * 7.0;
                weights0 = half3(0, 0, 0);
                weights1 = half3(0, 0, 0);

                if (hatchFactor > 6.0)
                {
                    // 纯白，权重全 0
                }
                else if (hatchFactor > 5.0)
                {
                    weights0.x = hatchFactor - 5.0;
                }
                else if (hatchFactor > 4.0)
                {
                    weights0.x = hatchFactor - 4.0;
                    weights0.y = 1.0 - weights0.x;
                }
                else if (hatchFactor > 3.0)
                {
                    weights0.y = hatchFactor - 3.0;
                    weights0.z = 1.0 - weights0.y;
                }
                else if (hatchFactor > 2.0)
                {
                    weights0.z = hatchFactor - 2.0;
                    weights1.x = 1.0 - weights0.z;
                }
                else if (hatchFactor > 1.0)
                {
                    weights1.x = hatchFactor - 1.0;
                    weights1.y = 1.0 - weights1.x;
                }
                else
                {
                    weights1.y = hatchFactor;
                    weights1.z = 1.0 - weights1.y;
                }
            }

            half3 SampleHatch(float2 uv, half3 weights0, half3 weights1)
            {
                half3 color = SAMPLE_TEXTURE2D(_Hatch0, sampler_Hatch0, uv).rgb * weights0.x;
                color += SAMPLE_TEXTURE2D(_Hatch1, sampler_Hatch1, uv).rgb * weights0.y;
                color += SAMPLE_TEXTURE2D(_Hatch2, sampler_Hatch2, uv).rgb * weights0.z;
                color += SAMPLE_TEXTURE2D(_Hatch3, sampler_Hatch3, uv).rgb * weights1.x;
                color += SAMPLE_TEXTURE2D(_Hatch4, sampler_Hatch4, uv).rgb * weights1.y;
                color += SAMPLE_TEXTURE2D(_Hatch5, sampler_Hatch5, uv).rgb * weights1.z;
                // 权重总和不足 1 的部分用纯白补上
                color += half3(1, 1, 1) * (1 - weights0.x - weights0.y - weights0.z - weights1.x - weights1.y - weights1.z);
                return color;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half3 normalWS = normalize(IN.normalWS);

                // 笔触档位在片元里算，阴影衰减才能换更密的笔触
                float4 shadowCoord = TransformWorldToShadowCoord(IN.posWS);
                Light mainLight = GetMainLight(shadowCoord);
                half mainDiff = saturate(dot(normalWS, mainLight.direction)) * mainLight.shadowAttenuation;

                half3 weights0, weights1;
                GetHatchWeights(mainDiff, weights0, weights1);
                return half4(SampleHatch(IN.uv, weights0, weights1) * _Color.rgb, 1.0);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
    }
    FallBack Off
}
