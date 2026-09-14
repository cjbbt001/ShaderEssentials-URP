Shader "URP/Chapter15/Dissolve"
{
    Properties
    {
        _BurnAmount ("Burn Amount", Range(0.0,1.0)) = 0.0
        _LineWidth ("Burn Line Width", Range(0.0,0.2)) = 0.1
        _BurnFirstColor ("Burn First Color", Color) =  (1, 0, 0, 1)
        _BurnSecondColor ("Burn Second Color", Color) =  (1, 0, 0, 1)
        _MainTex ("Texture", 2D) = "white" {}
        [Normal]
        _BumpMap ("Nromal Map", 2D) = "bump" {}
        _BurnMap ("Burn Map", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        float _BurnAmount;
        float _LineWidth;
        float4 _BurnFirstColor;
        float4 _BurnSecondColor;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        TEXTURE2D(_BumpMap);
        SAMPLER(sampler_BumpMap);
        TEXTURE2D(_BurnMap);
        SAMPLER(sampler_BurnMap);

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
            float3 T2W0 : TEXCOORD1;
            float3 T2W1 : TEXCOORD2;
            float3 T2W2 : TEXCOORD3;
            float4 vertex : SV_POSITION;
        };

        ENDHLSL

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }

            Cull Off

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            v2f vert(a2v v)
            {
                v2f o;

                VertexPositionInputs positionInputs = GetVertexPositionInputs(v.vertex.xyz);
                o.vertex = positionInputs.positionCS;

                VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normal, v.tangent);
                o.T2W0 = float3(normalInputs.tangentWS.x, normalInputs.bitangentWS.x, normalInputs.normalWS.x);
                o.T2W1 = float3(normalInputs.tangentWS.y, normalInputs.bitangentWS.y, normalInputs.normalWS.y);
                o.T2W2 = float3(normalInputs.tangentWS.z, normalInputs.bitangentWS.z, normalInputs.normalWS.z);

                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                Light light = GetMainLight();
                float3 worldLightDir = normalize(light.direction);

                half3 burn = SAMPLE_TEXTURE2D(_BurnMap, sampler_BurnMap, i.uv).rgb;
                clip(burn - _BurnAmount);

                float3x3 TBN = float3x3(normalize(i.T2W0), normalize(i.T2W1), normalize(i.T2W2));
                float3 bump = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, i.uv));
                float3 worldNormal = normalize(mul(TBN, bump));

                float3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).rgb;
                //ambient
                float3 ambient = 0.02 * albedo;
                //diffuse
                float3 diffuse = light.color * albedo * max(0, dot(worldNormal, worldLightDir));

                //t可以认为是消融的程度，1完全消融，0完全没有消融
                float t = 1 - smoothstep(0.0, _LineWidth, burn.r - _BurnAmount);
                float3 burnColor = lerp(_BurnFirstColor, _BurnSecondColor, t).rgb;
                burnColor = pow(burnColor, 5);

                half3 finalColor = lerp(ambient + diffuse, burnColor, t * step(0.0001, _BurnAmount));
                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode" = "ShadowCaster" }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            half3 _LightDirection;

            v2f vert(a2v v)
            {
                v2f o;

                float3 worldPos = TransformObjectToWorld(v.vertex.xyz);
                float3 worldNormal = TransformObjectToWorldNormal(v.normal);
                o.vertex = TransformWorldToHClip(ApplyShadowBias(worldPos, worldNormal, _LightDirection));

                #if UNITY_REVERSED_Z
                o.vertex.z = min(o.vertex.z, o.vertex.w * UNITY_NEAR_CLIP_VALUE);
                #else
                o.vertex.z = max(o.vertex.z, o.vertex.w * UNITY_NEAR_CLIP_VALUE);
                #endif

                o.uv = v.uv;
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                half3 burn = SAMPLE_TEXTURE2D(_BurnMap, sampler_BurnMap, i.uv).rgb;
                clip(burn.r - _BurnAmount);
                return 0;
            }
            ENDHLSL
        }
    }
}