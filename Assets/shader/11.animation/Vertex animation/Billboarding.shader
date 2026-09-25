Shader "cjbbt/Billboarding"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor ("BaseColor", Color) =  (1, 1, 1, 1)
        _VerticalBillboarding ("Vertical Restraints", Range(0,1)) = 1
    }

    SubShader
    {
        Tags {  "RenderPipeline" = "UniversalPipeline"
                "RenderType" = "Transparent"
                "Queue" = "Transparent"
                "DisableBatching" = "True"
                "IgnoreProjector" = "True" }

        Pass
        {
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off

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
                float _VerticalBillboarding;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                //法线指向视线方向
                float3 center = (0, 0, 0);
                float3 viewer = TransformWorldToObject(GetCameraPositionWS());
                float3 normalDir = viewer - center;

                //选择up方向固定或者normal指向摄像机
                normalDir.y = normalDir.y * _VerticalBillboarding;//_VerticalBillboarding = 0 ,noraml就在xz平面, = 1,normal指向视线方向
                normalDir = normalize(normalDir);

                //构造三个基向量
                float3 upDir = abs(normalDir.y) > 0.999 ? float3(0, 0, 1) : float3(0, 1, 0);  //防止upDir和normalDir平行
                float3 rightDir = normalize(cross(upDir, normalDir));
                upDir = normalize(cross(normalDir, rightDir));

                //计算旋转后的顶点坐标 [r, u, n]
                float3 offset = IN.positionOS.xyz - center;
                float3 localPos = center + offset.x * rightDir + offset.y * upDir + offset.z * normalDir;

                OUT.positionHCS = TransformObjectToHClip(localPos);
                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);

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
