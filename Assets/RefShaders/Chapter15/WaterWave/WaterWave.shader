Shader "URP/Chapter15/WaterWave"
{
    Properties
    {
        _Color ("Main Color", Color) =  (0, 0.15, 0.115, 1)
        _MainTex ("Base (RGB)", 2D) = "white" {}
        [Normal]
        _WaveMap ("Wave Map", 2D) = "bump" {}
        _Cubemap ("Environment Cubemap", Cube) = "_Skybox" {}
        _WaveXSpeed ("Wave Horizontal Speed", Range(-0.1, 0.1)) = 0.01
        _WaveYSpeed ("Wave Vertical Speed", Range(-0.1, 0.1)) = 0.01
        _Distortion ("Distortion", Range(0, 100)) = 10
    }
    SubShader
    {
        //使用OpaqueTexture替代GrabPass
        //因为OpaqueTexture在不透明物体之后才生成，所以需要将渲染队列设置为Transparent
        Tags { "RenderPipeline" = "UniversalPipeline" "Queue" = "Transparent" "RenderType" = "Opaque" }
        Pass
        {
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
            half4 _Color;
            float4 _MainTex_ST;
            float4 _WaveMap_ST;
            half _WaveXSpeed;
            half _WaveYSpeed;
            float _Distortion;
            float4 _CameraOpaqueTexture_TexelSize;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_WaveMap);
            SAMPLER(sampler_WaveMap);
            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);
            TEXTURECUBE(_Cubemap);
            SAMPLER(sampler_Cubemap);

            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 texcoord : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float4 scrPos : TEXCOORD0;
                float4 uv : TEXCOORD1;
                float4 TtoW0 : TEXCOORD2;
                float4 TtoW1 : TEXCOORD3;
                float4 TtoW2 : TEXCOORD4;
            };

            v2f vert(a2v v)
            {
                v2f o;

                VertexPositionInputs positionInputs = GetVertexPositionInputs(v.vertex.xyz);
                o.pos = positionInputs.positionCS;
                VertexNormalInputs normalInput = GetVertexNormalInputs(v.normal, v.tangent);

                o.scrPos = positionInputs.positionNDC;

                o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.uv.zw = TRANSFORM_TEX(v.texcoord, _WaveMap);

                o.TtoW0 = float4(normalInput.tangentWS.x, normalInput.bitangentWS.x, normalInput.normalWS.x, positionInputs.positionWS.x);
                o.TtoW1 = float4(normalInput.tangentWS.y, normalInput.bitangentWS.y, normalInput.normalWS.y, positionInputs.positionWS.y);
                o.TtoW2 = float4(normalInput.tangentWS.z, normalInput.bitangentWS.z, normalInput.normalWS.z, positionInputs.positionWS.z);

                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                float3 positionWS = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
                half3 viewDir = normalize(GetCameraPositionWS() - positionWS);
                float2 speed = _Time.y * float2(_WaveXSpeed, _WaveYSpeed);

                //根据时间控制speed去采样法线纹理，达到法线跟随时间变化的效果
                half3 bump1 = UnpackNormal(SAMPLE_TEXTURE2D(_WaveMap, sampler_WaveMap, i.uv.zw + speed)).rgb;
                half3 bump2 = UnpackNormal(SAMPLE_TEXTURE2D(_WaveMap, sampler_WaveMap, i.uv.zw - speed)).rgb;
                half3 bump = normalize(bump1 + bump2);

                //采样折射颜色
                float2 offset = bump.xy * _Distortion * _CameraOpaqueTexture_TexelSize.xy;
                i.scrPos.xy = offset * i.scrPos.z + i.scrPos.xy;
                half3 refrCol = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, i.scrPos.xy / i.scrPos.w).rgb;

                float3x3 TBN = float3x3(normalize(i.TtoW0.xyz), normalize(i.TtoW1.xyz), normalize(i.TtoW2.xyz));
                bump = normalize(mul(TBN, bump));

                //采样水波本身颜色
                half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy + speed);

                //采样反射颜色
                half3 reflDir = reflect(-viewDir, bump);
                half3 reflCol = SAMPLE_TEXTURECUBE(_Cubemap, sampler_Cubemap, reflDir).rgb * texColor.rgb * _Color.rgb;

                //计算菲涅耳项，混合反射和折射效果
                half fresnel = pow(1 - saturate(dot(viewDir, bump)), 4);
                half3 finalColor = reflCol * fresnel + refrCol * (1 - fresnel);

                return half4(finalColor, 1);
            }

            ENDHLSL
        }
    }
}