#region using
using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;
#endregion

#region RendererFeature
public class FogWithNoise : ScriptableRendererFeature
{
    [SerializeField] private FogWithNoiseSettings defaultSettings;
    [SerializeField] private Shader shader;
    [SerializeField] private RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;

    private Material material;
    private Material copyMaterial;
    private FogWithNoiseRenderPass fogRenderPass;

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

        fogRenderPass = new FogWithNoiseRenderPass(material, copyMaterial, defaultSettings);
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
public class FogWithNoiseSettings
{
    [Range(0, 5.0f)] public float fogDensity = 1.0f;
    public Color fogColor = Color.white;
    [Range(0, 20.0f)] public float fogStart = 0.0f;
    [Range(0, 20.0f)] public float fogEnd = 10.0f;
    public Texture noiseTexture;
    [Range(-5.0f, 5.0f)] public float fogXSpeed = 0.1f;
    [Range(-5.0f, 5.0f)] public float fogYSpeed = 0.1f;
    [Range(0, 3.0f)] public float noiseAmount = 1.0f;
}

public class FogWithNoiseRenderPass : ScriptableRenderPass
{
    private static readonly int fogDensityID = Shader.PropertyToID("_FogDensity");
    private static readonly int fogColorID = Shader.PropertyToID("_FogColor");
    private static readonly int fogStartID = Shader.PropertyToID("_FogStart");
    private static readonly int fogEndID = Shader.PropertyToID("_FogEnd");
    private static readonly int noiseTexID = Shader.PropertyToID("_NoiseTex");
    private static readonly int fogXSpeedID = Shader.PropertyToID("_FogXSpeed");
    private static readonly int fogYSpeedID = Shader.PropertyToID("_FogYSpeed");
    private static readonly int noiseAmountID = Shader.PropertyToID("_NoiseAmount");
    private const string textureName = "FogTempTexture";

    private FogWithNoiseSettings defaultSettings;
    private Material material;
    private Material copyMaterial;

    private TextureDesc tempTextureDescriptor;

    public FogWithNoiseRenderPass(Material material, Material copyMaterial, FogWithNoiseSettings defaultSettings)
    {
        this.material = material;
        this.defaultSettings = defaultSettings;
        this.copyMaterial = copyMaterial;
    }

    private void UpdateEffectSettings()
    {
        if (material == null) return;

        var volumeComponent = VolumeManager.instance.stack.GetComponent<FogWithNoiseVolumeComponent>();
        float fogDensity = volumeComponent.fogDensity.overrideState ? volumeComponent.fogDensity.value : defaultSettings.fogDensity;
        Color fogColor = volumeComponent.fogColor.overrideState ? volumeComponent.fogColor.value : defaultSettings.fogColor;
        float fogStart = volumeComponent.fogStart.overrideState ? volumeComponent.fogStart.value : defaultSettings.fogStart;
        float fogEnd = volumeComponent.fogEnd.overrideState ? volumeComponent.fogEnd.value : defaultSettings.fogEnd;
        Texture noiseTex = volumeComponent.noiseTexture.overrideState ? volumeComponent.noiseTexture.value : defaultSettings.noiseTexture;
        float fogXSpeed = volumeComponent.fogXSpeed.overrideState ? volumeComponent.fogXSpeed.value : defaultSettings.fogXSpeed;
        float fogYSpeed = volumeComponent.fogYSpeed.overrideState ? volumeComponent.fogYSpeed.value : defaultSettings.fogYSpeed;
        float noiseAmount = volumeComponent.noiseAmount.overrideState ? volumeComponent.noiseAmount.value : defaultSettings.noiseAmount;

        material.SetFloat(fogDensityID, fogDensity);
        material.SetColor(fogColorID, fogColor);
        material.SetFloat(fogStartID, fogStart);
        material.SetFloat(fogEndID, fogEnd);
        material.SetTexture(noiseTexID, noiseTex);
        material.SetFloat(fogXSpeedID, fogXSpeed);
        material.SetFloat(fogYSpeedID, fogYSpeed);
        material.SetFloat(noiseAmountID, noiseAmount);
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
[Serializable, VolumeComponentMenu("My Post-processing/FogWithNoise")]
public class FogWithNoiseVolumeComponent : VolumeComponent
{
    public FloatParameter fogDensity = new FloatParameter(1f);
    public ColorParameter fogColor = new ColorParameter(Color.white);
    public FloatParameter fogStart = new FloatParameter(0f);
    public FloatParameter fogEnd = new FloatParameter(10f);
    public TextureParameter noiseTexture = new TextureParameter(null);
    public FloatParameter fogXSpeed = new FloatParameter(0.1f);
    public FloatParameter fogYSpeed = new FloatParameter(0.1f);
    public FloatParameter noiseAmount = new FloatParameter(1f);
}
#endregion VolumeComponent