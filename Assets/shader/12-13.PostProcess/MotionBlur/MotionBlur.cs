using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;

public class MotionBlur : ScriptableRendererFeature
{
    public Shader shader;
    public RenderPassEvent injectionPoint = RenderPassEvent.BeforeRenderingPostProcessing;

    Material material;
    MotionBlurPass pass;

    public override void Create()
    {
        if (shader == null)
            shader = Shader.Find("URP/PostProcess/MotionBlur");
        if (shader == null)
            return;

        if (material == null || material.shader != shader)
        {
            CoreUtils.Destroy(material);
            material = CoreUtils.CreateEngineMaterial(shader);
        }

        pass = new MotionBlurPass(material);
        pass.renderPassEvent = injectionPoint;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (pass == null || material == null)
            return;

        // 历史纹理按 Game 视图分辨率保存，Scene 视图分辨率不同，不能共用。
        if (renderingData.cameraData.cameraType != CameraType.Game)
            return;

        renderer.EnqueuePass(pass);
    }

    protected override void Dispose(bool disposing)
    {
        pass?.Dispose();
        CoreUtils.Destroy(material);
    }
}

public class MotionBlurPass : ScriptableRenderPass
{
    static readonly int BlurAmountId = Shader.PropertyToID("_BlurAmount");

    readonly Material material;
    RTHandle historyTexture;
    bool historyInitialized;

    public MotionBlurPass(Material material)
    {
        this.material = material;
        profilingSampler = new ProfilingSampler("Motion Blur");
        requiresIntermediateTexture = true;
    }

    public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
    {
        if (material == null)
            return;

        MotionBlurVolume volume = VolumeManager.instance.stack.GetComponent<MotionBlurVolume>();
        if (volume == null || !volume.IsActive())
            return;

        UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
        if (resourceData.isActiveTargetBackBuffer)
            return;

        TextureHandle source = resourceData.activeColorTexture;
        if (!source.IsValid())
            return;

        TextureDesc sourceDesc = source.GetDescriptor(renderGraph);
        EnsureHistory(sourceDesc);
        if (historyTexture == null)
            return;

        // 把跨帧保存的 RTHandle 导入当前 Render Graph 才能作为 Blit 目标。
        TextureHandle history = renderGraph.ImportTexture(historyTexture);
        material.SetFloat(BlurAmountId, volume.blurAmount.value);

        if (!historyInitialized)
        {
            historyInitialized = true;
            RenderGraphUtils.BlitMaterialParameters initialize = new(source, history, material, 1);
            renderGraph.AddBlitPass(initialize, "Motion Blur Initialize");
            return;
        }

        // Pass 0 混合 RGB，Pass 2 单独恢复 Alpha。Pass 1 是全通道拷贝。
        RenderGraphUtils.BlitMaterialParameters blendRgb = new(source, history, material, 0);
        renderGraph.AddBlitPass(blendRgb, "Motion Blur Blend RGB");

        RenderGraphUtils.BlitMaterialParameters copyAlpha = new(source, history, material, 2);
        renderGraph.AddBlitPass(copyAlpha, "Motion Blur Copy Alpha");

        TextureDesc destinationDesc = sourceDesc;
        destinationDesc.name = "_MotionBlurTexture";
        destinationDesc.depthBufferBits = 0;
        TextureHandle destination = renderGraph.CreateTexture(destinationDesc);

        RenderGraphUtils.BlitMaterialParameters output = new(history, destination, material, 1);
        renderGraph.AddBlitPass(output, "Motion Blur Output");
        resourceData.cameraColor = destination;
    }

    void EnsureHistory(TextureDesc sourceDesc)
    {
        RenderTexture history = historyTexture != null ? historyTexture.rt : null;
        if (history != null && history.width == sourceDesc.width && history.height == sourceDesc.height)
            return;

        historyTexture?.Release();
        historyTexture = RTHandles.Alloc(
            sourceDesc.width,
            sourceDesc.height,
            colorFormat: sourceDesc.colorFormat,
            depthBufferBits: DepthBits.None,
            dimension: TextureDimension.Tex2D,
            name: "MotionBlurHistory");
        historyInitialized = false;
    }

    public void Dispose()
    {
        historyTexture?.Release();
        historyTexture = null;
        historyInitialized = false;
    }
}

[Serializable, VolumeComponentMenu("Custom-Postprocessing/Motion Blur")]
public class MotionBlurVolume : VolumeComponent, IPostProcessComponent
{
    public ClampedFloatParameter blurAmount = new ClampedFloatParameter(0.5f, 0f, 0.9f);

    public bool IsActive()
    {
        return active && blurAmount.value > 0f;
    }

    public bool IsTileCompatible() => false;
}
