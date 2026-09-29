Shader "URP/NPR/ToonShading"
{
    Properties
    {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
        _MainTex ("Main Tex", 2D) = "white" {}
        _Ramp ("Ramp Texture", 2D) = "white" {}          // 漫反射阶梯图，决定明暗分界
        _Outline ("Outline", Range(0, 1)) = 0.1          // 轮廓线宽度（观察空间外扩）
        _OutlineColor ("Outline Color", Color) = (0, 0, 0, 1)
        _Specular ("Specular", Color) = (1, 1, 1, 1)
        _SpecularScale ("Specular Scale", Range(0, 0.1)) = 0.01  // 高光阈值偏移，0 关闭高光
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            float _Outline;
            half4 _OutlineColor;
            half4 _Color;
            half4 _Specular;
            half _SpecularScale;
        CBUFFER_END
        ENDHLSL

        // 背面外扩画轮廓：先画正面会盖住内部，只留下边缘一圈
        Pass
        {
            Name "OUTLINE"
            Cull Front

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                // 观察空间里沿法线外扩，屏幕上的轮廓宽度更均匀
                float4 posVS = mul(UNITY_MATRIX_MV, IN.positionOS);
                float3 normalVS = mul((float3x3)UNITY_MATRIX_IT_MV, IN.normalOS);
                // 压低 z，避免正对相机的面也被明显撑开
                normalVS.z = -0.5;
                posVS = posVS + float4(normalize(normalVS), 0) * _Outline;
                OUT.positionHCS = mul(UNITY_MATRIX_P, posVS);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                return half4(_OutlineColor.rgb, 1);
            }
            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // 主光阴影贴图变体：单级联 / 级联 / 屏幕空间阴影
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_Ramp);
            SAMPLER(sampler_Ramp);

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
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // 世界空间位置转阴影坐标，再取主光及其衰减
                float4 shadowCoord = TransformWorldToShadowCoord(IN.posWS);
                Light mainLight = GetMainLight(shadowCoord);
                half3 lightDirWS = normalize(mainLight.direction);
                half3 viewDirWS = normalize(GetCameraPositionWS() - IN.posWS);
                half3 halfDirWS = normalize(lightDirWS + viewDirWS);
                half3 normalWS = normalize(IN.normalWS);

                half3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv).rgb * _Color.rgb;

                // 半兰伯特 remap 到 [0,1]，再用 ramp 把连续明暗切成色块
                half diff = dot(normalWS, lightDirWS) * 0.5 + 0.5;
                half3 diffuse = mainLight.color * albedo * SAMPLE_TEXTURE2D(_Ramp, sampler_Ramp, float2(diff, diff)).rgb;

                half3 ambient = 0.02 * albedo;

                // fwidth 让高光边缘宽度跟屏幕空间变化走，避免远近硬边闪烁
                half spec = dot(normalWS, halfDirWS);
                half w = fwidth(spec) * 2.0;
                half3 specular = mainLight.color * _Specular.rgb
                    * lerp(0, 1, smoothstep(-w, w, spec + _SpecularScale - 1))
                    * step(0.0001, _SpecularScale);

                // 环境光不受阴影衰减，否则阴影里会全黑
                return half4(ambient + (diffuse + specular) * mainLight.shadowAttenuation, 1.0);
            }
            ENDHLSL
        }

        // 把物体写进阴影贴图。URP 不走 Fallback，必须单独写这个 Pass
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
            // 点光 / 聚光用 _LightPosition，方向光用 _LightDirection
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
    }
    FallBack Off
}
