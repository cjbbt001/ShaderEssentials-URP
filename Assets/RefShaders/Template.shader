Shader "URP/Chapter3/Template"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor ("BaseColor", Color) =  (1, 1, 1, 1)
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" }

        HLSLINCLUDE

        //导入必要文件
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        //常量缓冲区，适合存放一些小型数据，可以提高性能
        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        half4 _BaseColor;
        CBUFFER_END

        //纹理
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        //必要的结构体
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

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            v2f vert(a2v v)
            {
                v2f o;

                //获取不同坐标空间下的顶点位置信息
                VertexPositionInputs positionInputs = GetVertexPositionInputs(v.vertex.xyz);
                
                o.vertex = positionInputs.positionCS;

                // 也可以直接使用以下函数获得裁剪空间的位置信息
                // o.vertex = TransformObjectToHClip(v.vertex.xyz);

                //获得世界空间的法线与切线信息
                VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normal, v.tangent);
                o.normal = normalInputs.normalWS;

                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                //HLSL中不存在fixed4类型
                half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv) * _BaseColor;
                return col;
            }
            ENDHLSL
        }
    }
}