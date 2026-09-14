#region using
using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;
#endregion

#region RendererFeature
public class GaussianBlur : ScriptableRendererFeature
{
    [SerializeField] private GaussianBlurSettings defaultSettings;
    [SerializeField] private Shader shader;
    [SerializeField] private RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;

    private Material material;
    private Material copyMaterial;
    private GaussianBlurRenderPass gaussianBlurRenderPass;

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
            Debug.LogError("Failed to find Blit shader for down/upsampling!");

        gaussianBlurRenderPass = new GaussianBlurRenderPass(material, copyMaterial, defaultSettings);
        gaussianBlurRenderPass.renderPassEvent = renderPassEvent;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer,
        ref RenderingData renderingData)
    {
        if (gaussianBlurRenderPass == null)
            return;
        if (renderingData.cameraData.cameraType == CameraType.Game ||
            renderingData.cameraData.cameraType == CameraType.SceneView)
        {
            renderer.EnqueuePass(gaussianBlurRenderPass);
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
public class GaussianBlurSettings
{
    [Range(0, 3.0f)] public float blurSize = 1.0f;
}

public class GaussianBlurRenderPass : ScriptableRenderPass
{
    private static readonly int blurSizeID = Shader.PropertyToID("_BlurSize");
    private const string downsampledTexName = "_DownsampledTexture";

    private GaussianBlurSettings defaultSettings;
    private Material material;
    private Material copyMaterial;   // 用于降采样和上采样

    public GaussianBlurRenderPass(Material material, Material copyMaterial, GaussianBlurSettings defaultSettings)
    {
        this.material = material;
        this.copyMaterial = copyMaterial;
        this.defaultSettings = defaultSettings;
    }

    private void UpdateEffectSettings()
    {
        if (material == null) return;

        var volumeComponent = VolumeManager.instance.stack.GetComponent<GaussianBlurVolumeComponent>();
        float blurSize = volumeComponent != null && volumeComponent.blurSize.overrideState
            ? volumeComponent.blurSize.value
            : defaultSettings.blurSize;
        material.SetFloat(blurSizeID, blurSize);
    }

    public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
    {
        UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
        UniversalCameraData cameraData = frameData.Get<UniversalCameraData>();

        if (resourceData.isActiveTargetBackBuffer)
            return;

        TextureHandle srcCamColor = resourceData.activeColorTexture;

        var volumeComponent = VolumeManager.instance.stack.GetComponent<GaussianBlurVolumeComponent>();
        int iteration = volumeComponent?.iteration.overrideState == true ? volumeComponent.iteration.value : 1;
        int downSampleFactor = volumeComponent?.downSample.overrideState == true ? volumeComponent.downSample.value : 1;

        UpdateEffectSettings();

        if (!srcCamColor.IsValid())
            return;

        var srcDesc = srcCamColor.GetDescriptor(renderGraph);
        int downWidth = Mathf.Max(1, srcDesc.width / downSampleFactor);
        int downHeight = Mathf.Max(1, srcDesc.height / downSampleFactor);

        // 创建降采样纹理描述符
        var downDesc = srcDesc;
        downDesc.name = downsampledTexName;
        downDesc.width = downWidth;
        downDesc.height = downHeight;
        downDesc.depthBufferBits = 0;

        //两个用于模糊的纹理
        TextureHandle texA = renderGraph.CreateTexture(downDesc);
        TextureHandle texB = renderGraph.CreateTexture(downDesc);

        //降采样
        if (copyMaterial != null)
        {
            RenderGraphUtils.BlitMaterialParameters downParams = new(srcCamColor, texA, copyMaterial, 0);
            renderGraph.AddBlitPass(downParams, "Downsample");
        }
        else
        {
            Debug.LogError("copyMaterial is null, cannot downscale!");
            return;
        }

        //迭代模糊
        for (int i = 0; i < iteration; i++)
        {
            RenderGraphUtils.BlitMaterialParameters verticalParams = new(texA, texB, material, 0);
            renderGraph.AddBlitPass(verticalParams, $"VerticalBlur_{i}");

            RenderGraphUtils.BlitMaterialParameters horizontalParams = new(texB, texA, material, 1);
            renderGraph.AddBlitPass(horizontalParams, $"HorizontalBlur_{i}");
        }

        //上采样
        RenderGraphUtils.BlitMaterialParameters upParams = new(texA, srcCamColor, copyMaterial, 0);
        renderGraph.AddBlitPass(upParams, "Upsample");

    }
}
#endregion RenderPass

#region VolumeComponent
[Serializable, VolumeComponentMenu("My Post-processing/GaussianBlur")]
public class GaussianBlurVolumeComponent : VolumeComponent
{
    public ClampedFloatParameter blurSize = new ClampedFloatParameter(1f, 0, 3f);
    public ClampedIntParameter iteration = new ClampedIntParameter(2, 1, 8);
    public ClampedIntParameter downSample = new ClampedIntParameter(1, 1, 4);
}
#endregion VolumeComponent