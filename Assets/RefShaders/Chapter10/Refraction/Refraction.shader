Shader "URP/Chapter10/Refraction"
{
    Properties
    {
        _BaseColor ("BaseColor", Color) =  (1, 1, 1, 1)
        _RefractColor ("Refraction Color", Color) =  (1, 1, 1, 1)
        _RefractAmount ("Refract Amount", Range(0,1)) = 1.0
        _RefractRatio ("Refraction Ratio", Range(0.05,1)) = 0.5
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
        half4 _RefractColor;
        float _RefractAmount;
        float _RefractRatio;
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

            half4 frag(v2f i) : SV_Target
            {
                Light light = GetMainLight();

                float3 worldNormal = normalize(i.normal);
                float3 viewDir = normalize(GetCameraPositionWS() - i.fragWS);
                float3 lightDir = normalize(light.direction);

                float3 diffuse = (_BaseColor.rgb * light.color) * max(dot(worldNormal, lightDir), 0);
                float3 ambient = 0.02;

                //采样Cubemap
                float3 refractDir = refract(-viewDir, worldNormal, _RefractRatio);
                float3 refractColor = SAMPLE_TEXTURECUBE(_Cubemap, sampler_Cubemap, refractDir).xyz;
                //根据反射强度混合反射颜色和物体自身颜色
                diffuse = lerp(diffuse, refractColor, _RefractAmount);

                float3 finalColor = diffuse + ambient;

                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
}