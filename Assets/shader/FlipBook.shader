Shader "cjbbt/FlipBook"
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
        Tags { "RenderType" = "Transparent"
               "RenderPipeline" = "UniversalPipeline"
               "Queue" = "Transparent"
               "IgnoreProjector" = "True"}

        Pass
        {
            Tags{"LightMode" = "UniversalForward"}
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float _HorizontalAmount;
                float _VerticalAmount;
                float _Speed;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float totalFrames = _HorizontalAmount * _VerticalAmount;
                float currentFrame = fmod(floor(_Time.y * _Speed), totalFrames);

                float row = floor(currentFrame / _HorizontalAmount);
                float column = currentFrame - row * _HorizontalAmount;

                // Row 0 is the top row (Unity UV origin is bottom-left).
                float2 uv;
                uv.x = (IN.uv.x + column) / _HorizontalAmount;
                uv.y = (IN.uv.y + (_VerticalAmount - 1.0 - row)) / _VerticalAmount;

                return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
            }
            ENDHLSL
        }
    }
}
