#region using
using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;
#endregion

#region RendererFeature
public class Bloom : ScriptableRendererFeature
{
    [SerializeField] private BloomSettings defaultSettings;
    [SerializeField] private Shader shader;
    [SerializeField] private RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;

    private Material material;
    private Material copyMaterial;
    private BloomRenderPass bloomRenderPass;

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

        bloomRenderPass = new BloomRenderPass(material, copyMaterial, defaultSettings);
        bloomRenderPass.renderPassEvent = renderPassEvent;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer,
        ref RenderingData renderingData)
    {
        if (bloomRenderPass == null) return;

        if (renderingData.cameraData.cameraType == CameraType.Game || renderingData.cameraData.cameraType == CameraType.SceneView)
        {
            renderer.EnqueuePass(bloomRenderPass);
        }
    }

    protected override void Dispose(bool disposing)
    {
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
public class BloomSettings
{
    [Range(0, 2f)] public float luminanceThreshold = 0.5f;
    [Range(0, 5f)] public float blurSize = 1.0f;
    [Range(1, 8)] public int iterations = 1;
}

public class BloomRenderPass : ScriptableRenderPass
{
    private static readonly int luminanceThresholdID = Shader.PropertyToID("_LuminanceThreshold");
    private static readonly int blurSizeID = Shader.PropertyToID("_BlurSize");
    private static readonly int bloomTexID = Shader.PropertyToID("_Bloom");
    private static readonly int bloomIntensityID = Shader.PropertyToID("_BloomIntensity");

    private const int brightPass = 0;
    private const int verticalBlurPass = 1;
    private const int horizontalBlurPass = 2;
    private const int compositePass = 3;

    private int iterationsCount = 1;

    private BloomSettings defaultSettings;
    private Material material;
    private Material copyMaterial;

    private class CompositePassData
    {
        public TextureHandle src;
        public TextureHandle bloomTex;
        public Material material;
        public int passIndex;
    }

    public BloomRenderPass(Material material, Material copyMaterial, BloomSettings defaultSettings)
    {
        this.material = material;
        this.defaultSettings = defaultSettings;
        this.copyMaterial = copyMaterial;
    }

    private void UpdateEffectSettings()
    {
        if (material == null) return;

        var volumeComponent = VolumeManager.instance.stack.GetComponent<BloomVolumeComponent>();
        float luminanceThreshold = volumeComponent.luminanceThreshold.overrideState ? volumeComponent.luminanceThreshold.value : defaultSettings.luminanceThreshold;
        float blurSize = volumeComponent.blurSize.overrideState ? volumeComponent.blurSize.value : defaultSettings.blurSize;
        float bloomIntensity = volumeComponent.bloomIntensity.overrideState ? volumeComponent.bloomIntensity.value : 1.0f;

        iterationsCount = volumeComponent.iterations.overrideState ? volumeComponent.iterations.value : defaultSettings.iterations;

        material.SetFloat(luminanceThresholdID, luminanceThreshold);
        material.SetFloat(blurSizeID, blurSize);
        material.SetFloat(bloomIntensityID, bloomIntensity);
    }

    public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
    {
        UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
        if (resourceData.isActiveTargetBackBuffer) return;

        TextureHandle srcCamColor = resourceData.activeColorTexture;
        if (!srcCamColor.IsValid()) return;

        TextureDesc sourceDesc = srcCamColor.GetDescriptor(renderGraph);
        sourceDesc.depthBufferBits = 0;

        TextureHandle brightTex = renderGraph.CreateTexture(sourceDesc);
        TextureHandle blurredTex = renderGraph.CreateTexture(sourceDesc);
        TextureHandle finalTex = renderGraph.CreateTexture(sourceDesc);

        UpdateEffectSettings();

        if (material == null) return;

        //提取亮部
        RenderGraphUtils.BlitMaterialParameters brightExtract = new(srcCamColor, brightTex, material, brightPass);
        renderGraph.AddBlitPass(brightExtract, "Bloom_BrightExtract");

        //模糊循环
        for (int it = 0; it < iterationsCount; ++it)
        {
            RenderGraphUtils.BlitMaterialParameters horizontalBlur = new(brightTex, blurredTex, material, horizontalBlurPass);
            renderGraph.AddBlitPass(horizontalBlur, "Bloom_HorizontalBlur");

            RenderGraphUtils.BlitMaterialParameters verticalBlur = new(blurredTex, brightTex, material, verticalBlurPass);
            renderGraph.AddBlitPass(verticalBlur, "Bloom_VerticalBlur");
        }

        // 合并
        using (var builder = renderGraph.AddRasterRenderPass<CompositePassData>("Bloom_Composite", out var passData))
        {
            passData.src = srcCamColor;
            passData.bloomTex = brightTex;
            passData.material = material;
            passData.passIndex = compositePass;

            builder.UseTexture(passData.src, AccessFlags.Read);
            builder.UseTexture(passData.bloomTex, AccessFlags.Read);

            builder.SetRenderAttachment(finalTex, 0);
            builder.AllowGlobalStateModification(true);

            builder.SetRenderFunc((CompositePassData data, RasterGraphContext context) =>
            {
                data.material.SetTexture(bloomTexID, data.bloomTex);
                Blitter.BlitTexture(context.cmd, data.src, new Vector4(1, 1, 0, 0), data.material, data.passIndex);
            });
        }

        //拷回最终结果
        RenderGraphUtils.BlitMaterialParameters copyBack = new(finalTex, srcCamColor, copyMaterial, 0);
        renderGraph.AddBlitPass(copyBack, "Bloom_CopyBack");
    }
}
#endregion RenderPass

#region VolumeComponent
[Serializable, VolumeComponentMenu("My Post-processing/Bloom")]
public class BloomVolumeComponent : VolumeComponent
{
    public ClampedFloatParameter luminanceThreshold = new ClampedFloatParameter(0.5f, 0f, 2f);
    public ClampedFloatParameter blurSize = new ClampedFloatParameter(1f, 0f, 5f);
    public ClampedIntParameter iterations = new ClampedIntParameter(1, 1, 8);
    public ClampedFloatParameter bloomIntensity = new ClampedFloatParameter(1.0f, 0.1f, 3.0f);
}
#endregion VolumeComponent