#region using
using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;
#endregion

#region RendererFeature
public class EdgeDetectNormalsAndDepth : ScriptableRendererFeature
{
    [SerializeField] private EdgeDetectNormalsAndDepthSettings defaultSettings;
    [SerializeField] private Shader shader;
    [SerializeField] private RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;

    private Material material;
    private Material copyMaterial;
    private EdgeDetectNormalsAndDepthRenderPass edgeDetectRenderPass;

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

        edgeDetectRenderPass = new EdgeDetectNormalsAndDepthRenderPass(material, copyMaterial, defaultSettings);
        edgeDetectRenderPass.renderPassEvent = renderPassEvent;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer,
        ref RenderingData renderingData)
    {
        if (edgeDetectRenderPass == null)
        {
            return;
        }
        if (renderingData.cameraData.cameraType == CameraType.Game || renderingData.cameraData.cameraType == CameraType.SceneView)
        {
            renderer.EnqueuePass(edgeDetectRenderPass);
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
public class EdgeDetectNormalsAndDepthSettings
{
    [Range(0, 1.0f)] public float edgeOnly = 1.0f;
    public Color edgeColor = Color.black;
    public Color backgroundColor = Color.white;
    [Range(0, 5.0f)] public float sampleDistance = 1.0f;
    public Vector4 sensitivity = new Vector4(1, 1, 1, 1);
}

public class EdgeDetectNormalsAndDepthRenderPass : ScriptableRenderPass
{
    private static readonly int edgeOnlyID = Shader.PropertyToID("_EdgeOnly");
    private static readonly int edgeColorID = Shader.PropertyToID("_EdgeColor");
    private static readonly int backgroundColorID = Shader.PropertyToID("_BackgroundColor");
    private static readonly int sampleDistanceID = Shader.PropertyToID("_SampleDistance");
    private static readonly int sensitivityID = Shader.PropertyToID("_Sensitivity");
    private const string textureName = "EdgeDetectTexture";

    private EdgeDetectNormalsAndDepthSettings defaultSettings;
    private Material material;
    private Material copyMaterial;

    private TextureDesc edgeDetectTextureDescriptor;

    public EdgeDetectNormalsAndDepthRenderPass(Material material, Material copyMaterial, EdgeDetectNormalsAndDepthSettings defaultSettings)
    {
        this.material = material;
        this.defaultSettings = defaultSettings;
        this.copyMaterial = copyMaterial;
    }

    private void UpdateEffectSettings()
    {
        if (material == null) return;

        var volumeComponent = VolumeManager.instance.stack.GetComponent<EdgeDetectNormalsAndDepthVolumeComponent>();
        float edgeOnly = volumeComponent.EdgeOnly.overrideState ? volumeComponent.EdgeOnly.value : defaultSettings.edgeOnly;
        Color edgeColor = volumeComponent.EdgeColor.overrideState ? volumeComponent.EdgeColor.value : defaultSettings.edgeColor;
        Color backgroundColor = volumeComponent.BackgroundColor.overrideState ? volumeComponent.BackgroundColor.value : defaultSettings.backgroundColor;
        float sampleDistance = volumeComponent.SampleDistance.overrideState ? volumeComponent.SampleDistance.value : defaultSettings.sampleDistance;
        Vector4 sensitivity = volumeComponent.Sensitivity.overrideState ? volumeComponent.Sensitivity.value : defaultSettings.sensitivity;

        material.SetFloat(edgeOnlyID, edgeOnly);
        material.SetColor(edgeColorID, edgeColor);
        material.SetColor(backgroundColorID, backgroundColor);
        material.SetFloat(sampleDistanceID, sampleDistance);
        material.SetVector(sensitivityID, sensitivity);
    }

    public override void RecordRenderGraph(RenderGraph renderGraph,
    ContextContainer frameData)
    {
        UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
        UniversalCameraData cameraData = frameData.Get<UniversalCameraData>();

        if (resourceData.isActiveTargetBackBuffer)
            return;

        TextureHandle srcCamColor = resourceData.activeColorTexture;
        edgeDetectTextureDescriptor = resourceData.activeColorTexture.GetDescriptor(renderGraph);
        edgeDetectTextureDescriptor.name = textureName;
        edgeDetectTextureDescriptor.depthBufferBits = 0;
        var dst = renderGraph.CreateTexture(edgeDetectTextureDescriptor);

        UpdateEffectSettings();

        if (!srcCamColor.IsValid() || !dst.IsValid())
            return;

        //使用效果材质将源图像处理到临时纹理
        RenderGraphUtils.BlitMaterialParameters paraFirst = new(srcCamColor, dst, material, 0);
        renderGraph.AddBlitPass(paraFirst, "EdgeDetectPass_First");

        //使用拷贝材质将临时纹理复制回相机颜色目标
        RenderGraphUtils.BlitMaterialParameters paraSecond = new(dst, srcCamColor, copyMaterial, 0);
        renderGraph.AddBlitPass(paraSecond, "EdgeDetectPass_Second");
    }
}

#endregion RenderPass

#region VolumeComponent
[Serializable, VolumeComponentMenu("My Post-processing/EdgeDetectNormalsAndDepth")]
public class EdgeDetectNormalsAndDepthVolumeComponent : VolumeComponent
{
    public ClampedFloatParameter EdgeOnly = new ClampedFloatParameter(1f, 0, 1f);
    public ColorParameter EdgeColor = new ColorParameter(Color.black);
    public ColorParameter BackgroundColor = new ColorParameter(Color.white);
    public ClampedFloatParameter SampleDistance = new ClampedFloatParameter(1f, 0, 5f);
    public Vector4Parameter Sensitivity = new Vector4Parameter(new Vector4(1, 1, 1, 1));
}
#endregion VolumeComponent