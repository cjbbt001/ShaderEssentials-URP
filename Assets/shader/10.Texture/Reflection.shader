Shader "URP/Texture/Reflection"
{
    Properties
    {
        _BaseColor ("BaseColor", Color) =  (1, 1, 1, 1)
        _ReflectAmount ("Reflect Amount", Range(0,1)) = 1.0
        _Cubemap ("Reflection Cubemap", Cube) = "_Skybox" {}
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
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float3 posWS : TEXCOORD1;
            };

            TEXTURECUBE(_Cubemap);
            SAMPLER(sampler_Cubemap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float _ReflectAmount;
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

            half4 frag(Varyings IN) : SV_Target
            {
                Light light = GetMainLight();

                float3 normalWS = normalize(IN.normalWS);
                float3 viewDirWS = normalize(GetCameraPositionWS() - IN.posWS);
                float3 lightDirWS = light.direction;

                //diffuse
                half3 diffuse = (_BaseColor.rgb * light.color) * max(0, dot(normalWS, lightDirWS));

                //Cubemap
                float3 reflectDir = reflect(-viewDirWS, normalWS);
                half3 reflectColor = SAMPLE_TEXTURECUBE(_Cubemap, sampler_Cubemap, reflectDir).rgb;

                half3 color = lerp(diffuse, reflectColor, _ReflectAmount);
                return half4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
