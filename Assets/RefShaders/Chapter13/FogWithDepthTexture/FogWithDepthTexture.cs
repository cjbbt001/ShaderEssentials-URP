#region using
using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;
#endregion

#region RendererFeature
public class FogWithDepthTexture : ScriptableRendererFeature
{
    [SerializeField] private FogWithDepthTextureSettings defaultSettings;
    [SerializeField] private Shader shader;
    [SerializeField] private RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;

    private Material material;
    private Material copyMaterial;
    private FogWithDepthTextureRenderPass fogRenderPass;

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

        fogRenderPass = new FogWithDepthTextureRenderPass(material, copyMaterial, defaultSettings);
        fogRenderPass.renderPassEvent = renderPassEvent;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer,
        ref RenderingData renderingData)
    {
        if (fogRenderPass == null)
        {
            return;
        }
        if (renderingData.cameraData.cameraType == CameraType.Game || renderingData.cameraData.cameraType == CameraType.SceneView)
        {
            // 开启深度纹理
            renderingData.cameraData.camera.depthTextureMode |= DepthTextureMode.Depth;
            renderer.EnqueuePass(fogRenderPass);
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
public class FogWithDepthTextureSettings
{
    [Range(0, 5.0f)] public float fogDensity = 1.0f;
    public Color fogColor = Color.white;
    [Range(0, 10.0f)] public float fogStart = 0.0f;
    [Range(0, 20.0f)] public float fogEnd = 10.0f;
}

public class FogWithDepthTextureRenderPass : ScriptableRenderPass
{
    private static readonly int fogDensityID = Shader.PropertyToID("_FogDensity");
    private static readonly int fogColorID = Shader.PropertyToID("_FogColor");
    private static readonly int fogStartID = Shader.PropertyToID("_FogStart");
    private static readonly int fogEndID = Shader.PropertyToID("_FogEnd");
    private const string textureName = "FogTempTexture";

    private FogWithDepthTextureSettings defaultSettings;
    private Material material;
    private Material copyMaterial;

    private TextureDesc tempTextureDescriptor;

    public FogWithDepthTextureRenderPass(Material material, Material copyMaterial, FogWithDepthTextureSettings defaultSettings)
    {
        this.material = material;
        this.defaultSettings = defaultSettings;
        this.copyMaterial = copyMaterial;
    }

    private void UpdateEffectSettings()
    {
        if (material == null) return;

        var volumeComponent = VolumeManager.instance.stack.GetComponent<FogWithDepthTextureVolumeComponent>();
        float fogDensity = volumeComponent.fogDensity.overrideState ? volumeComponent.fogDensity.value : defaultSettings.fogDensity;
        Color fogColor = volumeComponent.fogColor.overrideState ? volumeComponent.fogColor.value : defaultSettings.fogColor;
        float fogStart = volumeComponent.fogStart.overrideState ? volumeComponent.fogStart.value : defaultSettings.fogStart;
        float fogEnd = volumeComponent.fogEnd.overrideState ? volumeComponent.fogEnd.value : defaultSettings.fogEnd;

        material.SetFloat(fogDensityID, fogDensity);
        material.SetColor(fogColorID, fogColor);
        material.SetFloat(fogStartID, fogStart);
        material.SetFloat(fogEndID, fogEnd);
    }

    public override void RecordRenderGraph(RenderGraph renderGraph,
        ContextContainer frameData)
    {
        UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
        UniversalCameraData cameraData = frameData.Get<UniversalCameraData>();

        if (resourceData.isActiveTargetBackBuffer)
            return;

        TextureHandle srcCamColor = resourceData.activeColorTexture;
        tempTextureDescriptor = srcCamColor.GetDescriptor(renderGraph);
        tempTextureDescriptor.name = textureName;
        tempTextureDescriptor.depthBufferBits = 0;
        var dst = renderGraph.CreateTexture(tempTextureDescriptor);

        UpdateEffectSettings();

        if (!srcCamColor.IsValid() || !dst.IsValid())
            return;

        if (material == null)
        {
            Debug.LogError("material is null, skipping pass.");
            return;
        }

        //使用效果材质将源图像处理到临时纹理
        RenderGraphUtils.BlitMaterialParameters paraFirst = new(srcCamColor, dst, material, 0);
        renderGraph.AddBlitPass(paraFirst, "FogPass_First");

        //使用拷贝材质将临时纹理复制回相机颜色目标
        RenderGraphUtils.BlitMaterialParameters paraSecond = new(dst, srcCamColor, copyMaterial, 0);
        renderGraph.AddBlitPass(paraSecond, "FogPass_Second");
    }
}
#endregion RenderPass

#region VolumeComponent
[Serializable, VolumeComponentMenu("My Post-processing/FogWithDepthTexture")]
public class FogWithDepthTextureVolumeComponent : VolumeComponent
{
    public FloatParameter fogDensity = new FloatParameter(1f);
    public ColorParameter fogColor = new ColorParameter(Color.white);
    public FloatParameter fogStart = new FloatParameter(0f);
    public FloatParameter fogEnd = new FloatParameter(10f);
}
#endregion VolumeComponent