Shader "cjbbt/2Dwater"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor ("BaseColor", Color) =  (1, 1, 1, 1)
        _Magnitude ("Distortion Magnitude", Float) = 1
        _Frequency ("Distortion Frequency", Float) = 1
        _InWaveLength ("Distortion Inverse Wave Length", Float) = 10
        _Speed ("Speed", Float) = .5
    }

    SubShader
    {
        Tags { "RenderType" = "Transparent" 
               "Queue" = "Transparent"
               "IgnoreProjector" = "True"
               "DisableBatching" = "True"
               "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            
            ZWrite Off
            Cull Off
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
                half4 _BaseColor;
                float _Magnitude;
                float _Frequency;
                float _InWaveLength;
                float _Speed;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                //sin函数模拟波动
                float3 offset = float3(
                    sin((IN.positionOS.y + IN.positionOS.z) * _InWaveLength + _Frequency * _Time.y) * _Magnitude,
                    0, 0);

                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz + offset);
                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
                OUT.uv += float2(0,_Time.y * _Speed);//UV移动模拟水流动
                
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv) * _BaseColor;
                return color;
            }
            ENDHLSL
        }
    }
}
