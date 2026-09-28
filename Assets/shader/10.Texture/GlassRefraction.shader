Shader "URP/Texture/GlassRefraction"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1, 1, 1, 1)          // 最终颜色 tint
        _MainTex ("Main Tex", 2D) = "white" {}                   // 玻璃表面颜色（叠在反射上）
        [Normal]
        _BumpMap ("Normal Map", 2D) = "bump" {}                  // 法线贴图：扰动折射方向
        _Cubemap ("Reflection Cubemap", Cube) = "_Skybox" {}     // 反射用的环境立方体贴图
        _Distortion ("Distortion", Range(0, 150)) = 10           // 折射扭曲强度（按像素）
        _RefractAmount ("Refract Amount", Range(0.0, 1.0)) = 1.0 // 折射占比：0=全反射，1=全折射
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            // 关键：_CameraOpaqueTexture 在 Opaque 之后、Transparent 之前生成，
            // 玻璃必须放进 Transparent 队列，才能抓到已经画好的不透明场景。
            "Queue" = "Transparent"
        }

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }

            ZWrite Off   // 透明物体不写深度，避免遮挡后面透明物体的排序问题
            Cull Back    // 只渲染正面（实心玻璃）

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // 此头文件内部已声明（所以下面直接使用，不要再声明一遍，否则重复定义）：
            //   TEXTURE2D_X(_CameraOpaqueTexture);
            //   SAMPLER(sampler_CameraOpaqueTexture);
            //   float4 _CameraOpaqueTexture_TexelSize;   // (1/宽, 1/高, 宽, 高)
            //   float3 SampleSceneColor(float2 uv);
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;  // 模型空间顶点
                float2 uv : TEXCOORD0;         // 模型 UV
                float3 normalOS : NORMAL;      // 模型空间法线
                float4 tangentOS : TANGENT;    // 模型空间切线（xyz 切线，w 副切线符号）
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION; // 裁剪空间位置
                float2 uv : TEXCOORD0;            // 主纹理 UV
                float2 uvBump : TEXCOORD1;        // 法线纹理 UV（独立平铺）
                float3 normalWS : TEXCOORD2;      // 世界空间法线
                float3 tangentWS : TEXCOORD3;     // 世界空间切线
                float3 binormalWS : TEXCOORD4;    // 世界空间副切线
                float4 scrpos : TEXCOORD5;        // 齐次屏幕坐标（片元里 /w）
                float3 posWS : TEXCOORD6;         // 世界空间位置（算视线方向）
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            TEXTURE2D(_BumpMap);
            SAMPLER(sampler_BumpMap);

            TEXTURECUBE(_Cubemap);
            SAMPLER(sampler_Cubemap);

            // 材质级属性都放进 UnityPerMaterial，才能被 SRP Batcher 合批
            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _MainTex_ST;   // TRANSFORM_TEX 需要的 Tiling/Offset
                float4 _BumpMap_ST;
                float _Distortion;
                float _RefractAmount;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                // 一次算出 WS / VS / CS / 齐次屏幕坐标
                VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionHCS = positionInputs.positionCS;
                OUT.posWS = positionInputs.positionWS;

                // ComputeScreenPos 的输入必须是裁剪空间坐标，返回 [0,w] 的齐次值；
                // 片元里再 /w 得到 [0,1] 的屏幕 UV（先除后插值在透视投影下是错的）
                OUT.scrpos = ComputeScreenPos(positionInputs.positionCS);

                VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                OUT.normalWS = normalInputs.normalWS;
                OUT.tangentWS = normalInputs.tangentWS;
                OUT.binormalWS = normalInputs.bitangentWS;

                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
                OUT.uvBump = TRANSFORM_TEX(IN.uv, _BumpMap);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // 视线方向：物体表面 -> 相机
                float3 viewDirWS = normalize(GetCameraPositionWS() - IN.posWS);
                half3 mainTexColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv).rgb;

                // 采样法线贴图，并把法线从切线空间转到世界空间
                // float3x3(T, B, N) 按行摆放，因此用 mul(bump, TBN)
                float3 bump = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, IN.uvBump));
                float3x3 TBN = float3x3(IN.tangentWS, IN.binormalWS, IN.normalWS);
                float3 normalWS = normalize(mul(bump, TBN));

                // 折射：用切线空间法线的 xy 扰动屏幕 UV，模拟光线穿过玻璃的偏折
                // 乘 _CameraOpaqueTexture_TexelSize.xy 把「像素」换算成 UV，保证不同分辨率下强度一致
                float2 offset = bump.xy * _Distortion * _CameraOpaqueTexture_TexelSize.xy;
                float2 screenUV = IN.scrpos.xy / IN.scrpos.w + offset;
                half3 refractColor = SampleSceneColor(screenUV);

                // 反射：沿世界空间法线反射视线方向，采样环境立方体贴图，再叠主纹理颜色
                float3 reflectDir = reflect(-viewDirWS, normalWS);
                half3 reflectColor = SAMPLE_TEXTURECUBE(_Cubemap, sampler_Cubemap, reflectDir).rgb * mainTexColor;

                // 按 _RefractAmount 在反射与折射之间插值，最后乘 BaseColor
                half3 color = lerp(reflectColor, refractColor, _RefractAmount) * _BaseColor.rgb;
                return half4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
