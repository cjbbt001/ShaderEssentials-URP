Shader "URP/Chapter7/NormalMapWorldSpace"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [Normal]
        _BumpMap ("Normal Map", 2D) = "white" {}
        _BumpScale ("Bump Scale", Range(0.1,1.0)) = .5

        _BaseColor ("BaseColor", Color) =  (1, 1, 1, 1)
        _SpecularColor ("Specular Color", Color) =  (1, 1, 1, 1)
        _Shiness ("Shiness", Range(1,256)) = 32
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
        float _BumpScale;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        TEXTURE2D(_BumpMap);
        SAMPLER(sampler_BumpMap);

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

            float4 T2W0 : TEXCOORD1;
            float4 T2W1 : TEXCOORD2;
            float4 T2W2 : TEXCOORD3;

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

                VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normal, v.tangent);

                //计算TBN矩阵（按行存储），第四个分量存储世界坐标
                o.T2W0 = float4(normalInputs.tangentWS.x, normalInputs.bitangentWS.x, normalInputs.normalWS.x, positionInputs.positionWS.x);
                o.T2W1 = float4(normalInputs.tangentWS.y, normalInputs.bitangentWS.y, normalInputs.normalWS.y, positionInputs.positionWS.y);
                o.T2W2 = float4(normalInputs.tangentWS.z, normalInputs.bitangentWS.z, normalInputs.normalWS.z, positionInputs.positionWS.z);

                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                Light light = GetMainLight();
                float3 fragWS = float3(i.T2W0.w, i.T2W1.w, i.T2W2.w);
                float3 viewDir = normalize(_WorldSpaceCameraPos - fragWS);
                float3 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);

                //从切线空间中获取世界空间的法线
                //这里使用UnpackNormal，需要在Unity编辑器中将纹理类型（Texture Type）设置为法线贴图（Normal Map）
                float3 tangentNormal = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, i.uv));
                tangentNormal.xy *= _BumpScale;
                tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
                //这里使用向量构建矩阵时默认是按行存储的
                float3x3 TBN = float3x3(i.T2W0.xyz, i.T2W1.xyz, i.T2W2.xyz);
                float3 worldNormal = mul(TBN, tangentNormal);
                worldNormal = normalize(worldNormal);

                float3 diffuse = (light.color * _BaseColor.rgb * texColor) * max(dot(light.direction, worldNormal), 0);

                float3 h = normalize(light.direction + viewDir);
                float3 specular = (light.color * _SpecularColor.rgb) * pow(max(dot(worldNormal, h), 0), _Shiness);

                float3 ambient = 0.01;
                float3 finalColor = diffuse + specular + ambient;

                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
}