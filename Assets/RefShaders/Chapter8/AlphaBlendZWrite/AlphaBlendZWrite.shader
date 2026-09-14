Shader "URP/Chapter8/AlphaBlendZWrite"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor ("BaseColor", Color) =  (1, 1, 1, 1)
        _AlphaScale ("AlphaScale", Range(0,1)) = 1.0
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
        }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        float _AlphaScale;
        half4 _BaseColor;
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
            float4 vertex : SV_POSITION;
        };

        ENDHLSL

        Pass
        {
            //两个Pass之间的全局渲染状态：DepthBuffer\StencilBuffer\ColorBuffer会被传递
            ZWrite On
            //使用ColorMask保证当前Pass仅进行深度测试，而不输入颜色
            ColorMask  0
        }

        Pass
        {
            //Unity会优先渲染默认渲染路径的Pass，然后再渲染前向渲染路径的Pass
            Tags { "LightMode" = "UniversalForward" }
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            v2f vert(a2v v)
            {
                v2f o;

                VertexPositionInputs positionInputs = GetVertexPositionInputs(v.vertex.xyz);
                o.vertex = positionInputs.positionCS;

                VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normal, v.tangent);
                o.normal = normalInputs.normalWS;

                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv) * _BaseColor;
                return half4(col.xyz, col.w * _AlphaScale);
            }
            ENDHLSL
        }
    }
}