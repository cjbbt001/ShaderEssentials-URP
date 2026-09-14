#region using
using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;
#endregion

#region RendererFeature
public class MotionBlur : ScriptableRendererFeature
{
    [SerializeField] private MotionBlurSettings defaultSettings;
    [SerializeField] private Shader shader;
    [SerializeField] private RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;

    private Material material;
    private Material copyMaterial;
    private MotionBlurRenderPass motionBlurRenderPass;

    public override void Create()
    {
        if (shader == null)
        {
            Debug.LogWarning("Shader is null!");
            return;
        }
        material = new Material(shader);

        Shader blitShader = Shader.Find("Hidden/Universal Render Pipeline/Blit");
        if (blitShader != null)
            copyMaterial = new Material(blitShader);
        else
            Debug.LogError("Failed to find Hidden/Universal/Blit shader!");

        motionBlurRenderPass = new MotionBlurRenderPass(material, copyMaterial, defaultSettings);
        motionBlurRenderPass.renderPassEvent = renderPassEvent;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer,
        ref RenderingData renderingData)
    {
        if (motionBlurRenderPass == null)
        {
            return;
        }

        //这里需要设置CameraType仅为Game，如果设置为Game和Scene会在RecordRenderGraph中因为分辨率不同而导致始终无法执行MotionBlur_BlendToHistoryRGB/A这两个Pass
        if (renderingData.cameraData.cameraType == CameraType.Game)
        {
            renderer.EnqueuePass(motionBlurRenderPass);
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (motionBlurRenderPass != null)
        {
            motionBlurRenderPass.Cleanup();
        }
        if (material != null)
        {
            if (Application.isPlaying) Destroy(material);
            else DestroyImmediate(material);
        }
        if (copyMaterial != null)
        {
            if (Application.isPlaying) Destroy(copyMaterial);
            else DestroyImmediate(copyMaterial);
        }
    }
}
#endregion RendererFeature

#region RenderPass

[Serializable]
public class MotionBlurSettings
{
    [Range(0, 0.9f)] public float blurAmount = 0.5f;
}

public class MotionBlurRenderPass : ScriptableRenderPass
{
    private static readonly int blurAmountID = Shader.PropertyToID("_BlurAmount");
    private const string tempTextureName = "_MotionBlurTemp";

    private MotionBlurSettings defaultSettings;
    private Material material;
    private Material copyMaterial;

    //持久化的历史纹理
    private RTHandle m_HistoryTexture;
    private bool m_TextureInitialized = false;

    public MotionBlurRenderPass(Material material, Material copyMaterial, MotionBlurSettings defaultSettings)
    {
        this.material = material;
        this.defaultSettings = defaultSettings;
        this.copyMaterial = copyMaterial;
    }

    private void UpdateEffectSettings()
    {
        if (material == null) return;

        var volumeComponent = VolumeManager.instance.stack.GetComponent<MotionBlurVolumeComponent>();
        float blurAmount = volumeComponent.blurAmount.overrideState ? volumeComponent.blurAmount.value : defaultSettings.blurAmount;

        material.SetFloat(blurAmountID, 1.0f - blurAmount);
    }

    public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
    {
        UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
        if (resourceData.isActiveTargetBackBuffer) return;

        TextureHandle srcCamColor = resourceData.activeColorTexture;
        if (!srcCamColor.IsValid()) return;

        var srcDesc = srcCamColor.GetDescriptor(renderGraph);
        srcDesc.name = tempTextureName;
        srcDesc.depthBufferBits = 0;

        //检查历史纹理是否需要创建或重建
        if (m_HistoryTexture == null ||
    m_HistoryTexture.rt.width != srcDesc.width ||
    m_HistoryTexture.rt.height != srcDesc.height)
        {
            m_HistoryTexture?.Release();
            m_HistoryTexture = RTHandles.Alloc(
                srcDesc.width,
                srcDesc.height,
                colorFormat: srcDesc.colorFormat,
                depthBufferBits: DepthBits.None,
                dimension: TextureDimension.Tex2D,
                name: "MotionBlurHistory"
            );
            m_TextureInitialized = false;
        }

        // 导入历史纹理到 RenderGraph
        TextureHandle historyTex = renderGraph.ImportTexture(m_HistoryTexture);

        UpdateEffectSettings();

        if (material == null)
        {
            Debug.LogError("MotionBlur material is null, skipping pass.");
            return;
        }
        if (copyMaterial == null)
        {
            Debug.LogError("MotionBlur copyMaterial is null, skipping pass.");
            return;
        }

        //第一帧特殊处理，直接输出原图像
        if (!m_TextureInitialized)
        {
            m_TextureInitialized = true;
            RenderGraphUtils.BlitMaterialParameters copyToHistory = new(srcCamColor, historyTex, copyMaterial, 0);
            renderGraph.AddBlitPass(copyToHistory, "MotionBlur_InitHistory");
            return;
        }

        //混合RGB
        RenderGraphUtils.BlitMaterialParameters blendToHistoryRGB = new(srcCamColor, historyTex, material, 0);
        renderGraph.AddBlitPass(blendToHistoryRGB, "MotionBlur_BlendToHistoryRGB");
        //混合A
        RenderGraphUtils.BlitMaterialParameters blendToHistoryA = new(srcCamColor, historyTex, material, 1);
        renderGraph.AddBlitPass(blendToHistoryA, "MotionBlur_BlendToHistoryA");
        //写回SrcCamColor
        RenderGraphUtils.BlitMaterialParameters copyToCamera = new(historyTex, srcCamColor, copyMaterial, 0);
        renderGraph.AddBlitPass(copyToCamera, "MotionBlur_CopyToCamera");
    }

    //清理历史纹理
    public void Cleanup()
    {
        m_HistoryTexture?.Release();
        m_HistoryTexture = null;
    }
}
#endregion RenderPass

