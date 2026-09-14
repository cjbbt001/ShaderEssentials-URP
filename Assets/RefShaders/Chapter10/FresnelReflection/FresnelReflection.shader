Shader "URP/Chapter10/FresnelReflection"
{
    Properties
    {
        _BaseColor ("BaseColor", Color) =  (1, 1, 1, 1)
        _ReflectColor ("Reflection Color", Color) =  (1, 1, 1, 1)
        _FresnelScale ("Fresnel Scale", Range(0,1)) = 0.5
        _Cubemap ("Reflection Cubemap", Cube) = "_Skybox" {}
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
        half4 _BaseColor;
        half4 _ReflectColor;
        float _FresnelScale;
        CBUFFER_END

        TEXTURECUBE(_Cubemap);
        SAMPLER(sampler_Cubemap);

        struct a2v
        {
            float4 vertex : POSITION;
            float3 normal : NORMAL;
            float4 tangent : TANGENT;
            float2 uv : TEXCOORD0;
        };

        struct v2f
        {
            float2 uv : TEXCOORD0;
            float3 fragWS : TEXCOORD1;
            float3 normal : TEXCOORD2;
            float4 vertex : SV_POSITION;
        };

        ENDHLSL

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            v2f vert(a2v v)
            {
                v2f o;

                VertexPositionInputs positionInputs = GetVertexPositionInputs(v.vertex.xyz);
                o.vertex = positionInputs.positionCS;
                o.fragWS = positionInputs.positionWS;

                VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normal, v.tangent);
                o.normal = normalInputs.normalWS;

                o.uv = v.uv;

                return o;
            }

            float FresnelSchlick(float R0, float cosTheta)
            {
                return R0 + (1.0 - R0) * pow(1.0 - cosTheta, 5.0);
            }

            half4 frag(v2f i) : SV_Target
            {
                Light light = GetMainLight();

                float3 worldNormal = normalize(i.normal);
                float3 viewDir = normalize(GetCameraPositionWS() - i.fragWS);
                float3 lightDir = normalize(light.direction);

                float3 diffuse = (_BaseColor.rgb * light.color) * max(dot(worldNormal, lightDir), 0);
                float3 ambient = 0.02;

                float3 reflectDir = reflect(-viewDir, worldNormal);
                float3 reflectColor = SAMPLE_TEXTURECUBE(_Cubemap, sampler_Cubemap, reflectDir).xyz * _ReflectColor;

                //计算菲涅耳项
                float fresnel = saturate(FresnelSchlick(_FresnelScale, dot(viewDir, worldNormal)));

                diffuse = lerp(diffuse, reflectColor, fresnel);

                float3 finalColor = diffuse + ambient;

                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
}