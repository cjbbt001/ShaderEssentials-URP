Shader "URP/Chapter11/ImageSequenceAnimation"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _HorizontalAmount ("Horizontal Amount", float) = 4
        _VerticalAmount ("Vertical Amount", float) = 4
        _Speed ("Speed", Range(1,100)) = 30
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
        }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        float _HorizontalAmount;
        float _VerticalAmount;
        float _Speed;
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
            Tags { "LightMode" = "UniversalForward" }

            //当成半透明材质去处理序列帧动画
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
                //计算当前位于哪一帧
                float time = floor(_Time.y * _Speed);
                float totalFrames = _HorizontalAmount * _VerticalAmount * 1.0;
                float currentFrame = fmod(time, totalFrames);

                //计算行列索引
                //关系式：currentFrame = row * _HorizontalAmount + column
                float row = floor(currentFrame / _HorizontalAmount);
                float column = currentFrame - _HorizontalAmount * row;

                //计算偏移量
                float offset_x = (1.0 / _HorizontalAmount) * column;
                float offset_y = (1.0 / _VerticalAmount) * (_VerticalAmount - row - 1);

                //计算纹理坐标
                half2 uv = half2(i.uv.x / _HorizontalAmount, i.uv.y / _VerticalAmount);
                uv.x += offset_x;
                uv.y += offset_y;

                float4 finalColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
                return finalColor;
            }
            ENDHLSL
        }
    }
}