#region using
using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;
#endregion

#region RendererFeature
public class BrightnessSaturationAndContrast : ScriptableRendererFeature
{
    [SerializeField] private BriSatConSettings defaultSettings;
    [SerializeField] private Shader shader;
    [SerializeField] private RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;

    private Material material;
    private Material copyMaterial;
    private BriSatConRenderPass BriSatConRenderPass;

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

        BriSatConRenderPass = new BriSatConRenderPass(material, copyMaterial, defaultSettings);
        BriSatConRenderPass.renderPassEvent = renderPassEvent;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer,
        ref RenderingData renderingData)
    {
        if (BriSatConRenderPass == null)
        {
            return;
        }
        if (renderingData.cameraData.cameraType == CameraType.Game || renderingData.cameraData.cameraType == CameraType.SceneView)
        {
            renderer.EnqueuePass(BriSatConRenderPass);
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
public class BriSatConSettings
{
    [Range(0, 5.0f)] public float brightness;
    [Range(0, 1.0f)] public float saturation;
    [Range(0, 1.0f)] public float contrast;
}

public class BriSatConRenderPass : ScriptableRenderPass
{
    private static readonly int brightnessID = Shader.PropertyToID("_Brightness");
    private static readonly int saturationID = Shader.PropertyToID("_Saturation");
    private static readonly int contrastID = Shader.PropertyToID("_Contrast");
    private const string textureName = "BriSatConTexture";


    private BriSatConSettings defaultSettings;
    private Material material;
    private Material copyMaterial;

    private TextureDesc BriSatConTextureDescriptor;

    public BriSatConRenderPass(Material material, Material copyMaterial, BriSatConSettings defaultSettings)
    {
        this.material = material;
        this.defaultSettings = defaultSettings;
        this.copyMaterial = copyMaterial;
    }

    private void UpdateEffectSettings()
    {
        if (material == null) return;

        var volumeComponent = VolumeManager.instance.stack.GetComponent<BriSatConVolumeComponent>();
        float brightness = volumeComponent.Brightness.overrideState ? volumeComponent.Brightness.value : defaultSettings.brightness;
        float saturation = volumeComponent.Saturation.overrideState ? volumeComponent.Saturation.value : defaultSettings.saturation;
        float contrast = volumeComponent.Contrast.overrideState ? volumeComponent.Contrast.value : defaultSettings.contrast;

        material.SetFloat(brightnessID, brightness);
        material.SetFloat(saturationID, saturation);
        material.SetFloat(contrastID, contrast);
    }

    public override void RecordRenderGraph(RenderGraph renderGraph,
    ContextContainer frameData)
    {
        UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();

        UniversalCameraData cameraData = frameData.Get<UniversalCameraData>();

        if (resourceData.isActiveTargetBackBuffer)
            return;

        TextureHandle srcCamColor = resourceData.activeColorTexture;
        BriSatConTextureDescriptor = resourceData.activeColorTexture.GetDescriptor(renderGraph);
        BriSatConTextureDescriptor.name = textureName;
        BriSatConTextureDescriptor.depthBufferBits = 0;
        var dst = renderGraph.CreateTexture(BriSatConTextureDescriptor);

        UpdateEffectSettings();

        if (!srcCamColor.IsValid() || !dst.IsValid())
            return;

        //Pass 1：使用效果材质将源图像处理到临时纹理
        RenderGraphUtils.BlitMaterialParameters paraFirst = new(srcCamColor, dst, material, 0);
        renderGraph.AddBlitPass(paraFirst, "BriSatConPass_First");

        //Pass 2：使用拷贝材质将临时纹理复制回相机颜色目标
        RenderGraphUtils.BlitMaterialParameters paraSecond = new(dst, srcCamColor, copyMaterial, 0);
        renderGraph.AddBlitPass(paraSecond, "BriSatConPass_Second");

    }
}

#endregion RenderPass

#region VolumeComponent
[Serializable, VolumeComponentMenu("My Post-processing/BrightnessSaturationAndContrast")]
public class BriSatConVolumeComponent : VolumeComponent
{
    public ClampedFloatParameter Brightness = new ClampedFloatParameter(1f, 0, 5.0f);
    public ClampedFloatParameter Saturation = new ClampedFloatParameter(1f, 0, 1.0f);
    public ClampedFloatParameter Contrast = new ClampedFloatParameter(1f, 0, 1.0f);
}
#endregion VolumeComponent