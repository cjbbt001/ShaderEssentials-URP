Shader "URP/Texture/Fresnel"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1, 1, 1, 1)           // 物体底色（漫反射）
        _ReflectColor ("Reflection Color", Color) = (1, 1, 1, 1)  // 反射颜色 tint
        _FresnelScale ("Fresnel Scale (R0)", Range(0, 1)) = 0.5   // 菲涅耳系数：正对视角时的最小反射率
        _Cubemap ("Reflection Cubemap", Cube) = "_Skybox" {}      // 环境反射立方体贴图
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;  // 模型空间顶点
                float3 normalOS : NORMAL;      // 模型空间法线
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION; // 裁剪空间位置
                float3 normalWS : TEXCOORD0;      // 世界空间法线
                float3 posWS : TEXCOORD1;         // 世界空间位置（算视线方向）
            };

            TEXTURECUBE(_Cubemap);
            SAMPLER(sampler_Cubemap);

            // 材质级属性放进 UnityPerMaterial，才能被 SRP Batcher 合批
            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half4 _ReflectColor;
                float _FresnelScale;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionHCS = positionInputs.positionCS;
                OUT.posWS = positionInputs.positionWS;

                VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS);
                OUT.normalWS = normalInputs.normalWS;

                return OUT;
            }

            // Schlick 近似：F = R0 + (1 - R0) * (1 - cosθ)^5
            // cosθ = dot(viewDir, normal)：
            //   正对表面 cosθ→1，反射最弱，只剩 R0；
            //   掠射 cosθ→0，反射最强，趋近 1。
            float FresnelSchlick(float R0, float cosTheta)
            {
                return R0 + (1.0 - R0) * pow(1.0 - cosTheta, 5.0);
            }

            half4 frag(Varyings IN) : SV_Target
            {
                Light light = GetMainLight();

                float3 normalWS = normalize(IN.normalWS);
                float3 viewDirWS = normalize(GetCameraPositionWS() - IN.posWS);
                float3 lightDirWS = normalize(light.direction);

                // 漫反射
                half3 diffuse = (_BaseColor.rgb * light.color) * max(0, dot(normalWS, lightDirWS));
                half3 ambient = 0.02;

                // 环境反射：沿法线反射视线方向，采样 Cubemap
                float3 reflectDir = reflect(-viewDirWS, normalWS);
                half3 reflectColor = SAMPLE_TEXTURECUBE(_Cubemap, sampler_Cubemap, reflectDir).rgb * _ReflectColor.rgb;

                // 菲涅耳项：视角越掠射，反射越强
                float fresnel = saturate(FresnelSchlick(_FresnelScale, dot(viewDirWS, normalWS)));

                // 用菲涅耳项在漫反射与反射之间混合
                half3 color = lerp(diffuse, reflectColor, fresnel) + ambient;
                return half4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
