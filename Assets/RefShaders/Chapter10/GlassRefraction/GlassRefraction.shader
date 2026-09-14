Shader "URP/Chapter10/GlassRefraction"
{
    Properties
    {
        _BaseColor ("BaseColor", Color) =  (1, 1, 1, 1)
        _MainTex ("Main Tex", 2D) = "white" {}
        [Normal]
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _Cubemap ("Reflection Cubemap", Cube) = "_Skybox" {}
        _Distortion ("Distortion", Range(0,150)) = 10
        _RefractAmount ("Refract Amount", Range(0.0,1.0)) = 1.0
    }
    SubShader
    {
        //注意需要将渲染队列设置为"Transparent",保证玻璃在其他不透明物体之后渲染
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" "Queue" = "Transparent" }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        //使用DeclareOpaqueTexture.hlsl内部提供的变量获得_CameraOpaqueTexture
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

        CBUFFER_START(UnityPerMaterial)
        half4 _BaseColor;
        float _Distortion;
        float _RefractAmount;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        TEXTURE2D(_BumpMap);
        SAMPLER(sampler_BumpMap);

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
            float4 T2W0 : TEXCOORD1;
            float4 T2W1 : TEXCOORD2;
            float4 T2W2 : TEXCOORD3;
            float4 scrPos : TEXCOORD4;
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

                o.T2W0 = float4(normalInputs.tangentWS.x, normalInputs.bitangentWS.x, normalInputs.normalWS.x, positionInputs.positionWS.x);
                o.T2W1 = float4(normalInputs.tangentWS.y, normalInputs.bitangentWS.y, normalInputs.normalWS.y, positionInputs.positionWS.y);
                o.T2W2 = float4(normalInputs.tangentWS.z, normalInputs.bitangentWS.z, normalInputs.normalWS.z, positionInputs.positionWS.z);

                //采样_CameraOpaqueTexture要使用屏幕空间坐标，该函数返回的xy范围是[0,w]，zw保持不变
                o.scrPos = ComputeScreenPos(positionInputs.positionCS);
                o.uv = v.uv;

                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                float3 fragWS = float3(i.T2W0.w, i.T2W1.w, i.T2W2.w);
                float3 viewDir = normalize(GetCameraPositionWS() - fragWS);
                float3 bump = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, i.uv));
                float2 offset = bump.xy * _Distortion * _CameraOpaqueTexture_TexelSize.xy;

                float2 screenUV = i.scrPos.xy / i.scrPos.w;
                screenUV += offset;

                //折射颜色
                float3 refractColor = SampleSceneColor(screenUV);

                //计算世界空间法线
                float3x3 TBN = float3x3(i.T2W0.xyz, i.T2W1.xyz, i.T2W2.xyz);
                float3 worldNormal = mul(TBN, bump);

                //反射颜色
                float3 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).rgb;
                float3 reflectDir = reflect(-viewDir, worldNormal);
                float3 reflectColor = SAMPLE_TEXTURECUBE(_Cubemap, sampler_Cubemap, reflectDir).rgb * texColor;

                //混合折射和反射颜色
                float3 finalColor = lerp(reflectColor, refractColor, _RefractAmount);

                return half4(finalColor, 1);
            }
            ENDHLSL
        }
    }
}