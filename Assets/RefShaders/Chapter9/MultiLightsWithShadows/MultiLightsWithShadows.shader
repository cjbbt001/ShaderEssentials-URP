Shader "URP/Chapter9/MultiLightsWithShadows"
{
    Properties
    {
        [HideInInspector]
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor ("BaseColor", Color) =  (1, 1, 1, 1)
        _SpecularColor ("Specular Color", Color) =  (1, 1, 1, 1)
        _Shiness ("Shiness", Range(1,256)) = 32
        [Toggle(_AdditionalLights)]
        _AddLights ("AddtionalLights", Float) = 1
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        half4 _BaseColor;
        half4 _SpecularColor;
        float _Shiness;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

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
            float3 normal : TEXCOORD1;
            float3 fragWS : TEXCOORD2;
            float4 vertex : SV_POSITION;
        };

        ENDHLSL

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature _AdditionalLights

            //确保可以访问主光源的阴影贴图
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            //确保可以访问附加光源的阴影贴图
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            //（可选）生成软阴影
            #pragma multi_compile _ _SHADOWS_SOFT

            v2f vert(a2v v)
            {
                v2f o;

                VertexPositionInputs positionInputs = GetVertexPositionInputs(v.vertex.xyz);
                o.vertex = positionInputs.positionCS;
                o.fragWS = positionInputs.positionWS;

                VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normal, v.tangent);
                o.normal = normalInputs.normalWS;

                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            half4 frag(v2f fragment) : SV_Target
            {
                //主光源

                //将世界空间中的位置转换为阴影空间
                float4 shadowCoord = TransformWorldToShadowCoord(fragment.fragWS);
                //传入阴影坐标，shadowAttenuation将用于确定衰减值
                Light light = GetMainLight(shadowCoord);
                float3 worldNormal = normalize(fragment.normal);
                float3 viewDir = normalize(GetCameraPositionWS() - fragment.fragWS);

                float3 diffuse = (light.color * _BaseColor.rgb) * max(dot(light.direction, worldNormal), 0);

                float3 h = normalize(light.direction + viewDir);
                float3 specular = (light.color * _SpecularColor.rgb) * pow(max(dot(worldNormal, h), 0), _Shiness);

                float3 ambient = 0.02;
                float3 mainLightColor = (diffuse + specular) * light.shadowAttenuation + ambient;


                //计算附加光源
                float3 addtionalLightsColor = float3(0, 0, 0);

                #ifdef _AdditionalLights
                int addtionalLightsCount = GetAdditionalLightsCount();

                for (int i = 0; i < addtionalLightsCount; ++i)
                {
                    //计算附加光源及其阴影衰减，half4(1,1,1,1)是阴影遮罩
                    //此时Light.direction是世界坐标空间下从片元到光源的方向
                    Light addLight = GetAdditionalLight(i, fragment.fragWS, half4(1, 1, 1, 1));
                    float3 diffuse = (addLight.color * _BaseColor.rgb) * max(dot(addLight.direction, worldNormal), 0);
                    float3 h = normalize(addLight.direction + viewDir);
                    float3 specular = (addLight.color * _SpecularColor.rgb) * pow(max(dot(worldNormal, h), 0), _Shiness);
                    addtionalLightsColor += (diffuse + specular) * addLight.distanceAttenuation * addLight.shadowAttenuation;
                }
                #endif

                float3 finalColor = mainLightColor + addtionalLightsColor;

                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
}