#region using
using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;
#endregion

#region RendererFeature
public class EdgeDetection : ScriptableRendererFeature
{
    [SerializeField] private EdgeDetectionSettings defaultSettings;
    [SerializeField] private Shader shader;
    [SerializeField] private RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;

    private Material material;
    private Material copyMaterial;
    private EdgeDetectionRenderPass edgeDetectionRenderPass;

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

        edgeDetectionRenderPass = new EdgeDetectionRenderPass(material, copyMaterial, defaultSettings);
        edgeDetectionRenderPass.renderPassEvent = renderPassEvent;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer,
        ref RenderingData renderingData)
    {
        if (edgeDetectionRenderPass == null)
        {
            return;
        }
        if (renderingData.cameraData.cameraType == CameraType.Game || renderingData.cameraData.cameraType == CameraType.SceneView)
        {
            renderer.EnqueuePass(edgeDetectionRenderPass);
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
public class EdgeDetectionSettings
{
    [Range(0, 1.0f)] public float edgeOnly;
    public Color edgeColor = Color.black;
    public Color backgroundColor = Color.white;
}

public class EdgeDetectionRenderPass : ScriptableRenderPass
{
    private static readonly int edgeOnlyID = Shader.PropertyToID("_EdgeOnly");
    private static readonly int edgeColorID = Shader.PropertyToID("_EdgeColor");
    private static readonly int backgroundColorID = Shader.PropertyToID("_BackgroundColor");
    private const string textureName = "EdgeDetectionTexture";

    private EdgeDetectionSettings defaultSettings;
    private Material material;
    private Material copyMaterial;

    private TextureDesc edgeDetectionTextureDescriptor;

    public EdgeDetectionRenderPass(Material material, Material copyMaterial, EdgeDetectionSettings defaultSettings)
    {
        this.material = material;
        this.defaultSettings = defaultSettings;
        this.copyMaterial = copyMaterial;
    }

    private void UpdateEffectSettings()
    {
        if (material == null) return;

        var volumeComponent = VolumeManager.instance.stack.GetComponent<EdgeDetectionVolumeComponent>();
        float edgeOnly = volumeComponent.edgeOnly.overrideState ? volumeComponent.edgeOnly.value : defaultSettings.edgeOnly;
        Color edgeColor = volumeComponent.edgeColor.overrideState ? volumeComponent.edgeColor.value : defaultSettings.edgeColor;
        Color backgroundColor = volumeComponent.backgroundColor.overrideState ? volumeComponent.backgroundColor.value : defaultSettings.backgroundColor;

        material.SetFloat(edgeOnlyID, edgeOnly);
        material.SetColor(edgeColorID, edgeColor);
        material.SetColor(backgroundColorID, backgroundColor);
    }

    public override void RecordRenderGraph(RenderGraph renderGraph,
    ContextContainer frameData)
    {
        UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();

        UniversalCameraData cameraData = frameData.Get<UniversalCameraData>();

        if (resourceData.isActiveTargetBackBuffer)
            return;

        TextureHandle srcCamColor = resourceData.activeColorTexture;
        edgeDetectionTextureDescriptor = resourceData.activeColorTexture.GetDescriptor(renderGraph);
        edgeDetectionTextureDescriptor.name = textureName;
        edgeDetectionTextureDescriptor.depthBufferBits = 0;
        var dst = renderGraph.CreateTexture(edgeDetectionTextureDescriptor);

        UpdateEffectSettings();

        if (!srcCamColor.IsValid() || !dst.IsValid())
            return;

        if (material == null)
        {
            Debug.LogError("material is null, skipping pass.");
            return;
        }

        //Pass 1：使用效果材质将源图像处理到临时纹理
        RenderGraphUtils.BlitMaterialParameters paraFirst = new(srcCamColor, dst, material, 0);
        renderGraph.AddBlitPass(paraFirst, "EdgeDetectionPass_First");

        //Pass 2：使用拷贝材质将临时纹理复制回相机颜色目标
        RenderGraphUtils.BlitMaterialParameters paraSecond = new(dst, srcCamColor, copyMaterial, 0);
        renderGraph.AddBlitPass(paraSecond, "EdgeDetectionPass_Second");

    }
}

#endregion RenderPass

#region VolumeComponent
[Serializable, VolumeComponentMenu("My Post-processing/EdgeDetection")]
public class EdgeDetectionVolumeComponent : VolumeComponent
{
    public ClampedFloatParameter edgeOnly = new ClampedFloatParameter(1f, 0, 1f);
    public ColorParameter edgeColor = new ColorParameter(Color.black, true, false, true);
    public ColorParameter backgroundColor = new ColorParameter(Color.white, true, false, true);
}
#endregion VolumeComponent