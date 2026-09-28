using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;

public class EdgeDetectNormalsAndDepth : ScriptableRendererFeature
{
    public Shader shader;
    public RenderPassEvent injectionPoint = RenderPassEvent.BeforeRenderingPostProcessing;

    Material material;
    EdgeDetectNormalsAndDepthPass pass;

    public override void Create()
    {
        if (shader == null)
            shader = Shader.Find("URP/PostProcess/EdgeDetectNormalsAndDepth");
        if (shader == null)
            return;

        if (material == null || material.shader != shader)
        {
            CoreUtils.Destroy(material);
            material = CoreUtils.CreateEngineMaterial(shader);
        }

        pass = new EdgeDetectNormalsAndDepthPass(material);
        pass.renderPassEvent = injectionPoint;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (pass == null || material == null)
            return;

        CameraType cameraType = renderingData.cameraData.cameraType;
        if (cameraType != CameraType.Game && cameraType != CameraType.SceneView)
            return;

        renderer.EnqueuePass(pass);
    }

    protected override void Dispose(bool disposing)
    {
        CoreUtils.Destroy(material);
    }
}

public class EdgeDetectNormalsAndDepthPass : ScriptableRenderPass
{
    static readonly int EdgeOnlyId = Shader.PropertyToID("_EdgeOnly");
    static readonly int EdgeColorId = Shader.PropertyToID("_EdgeColor");
    static readonly int BackgroundColorId = Shader.PropertyToID("_BackgroundColor");
    static readonly int SampleDistanceId = Shader.PropertyToID("_SampleDistance");
    static readonly int SensitivityId = Shader.PropertyToID("_Sensitivity");

    readonly Material material;

    public EdgeDetectNormalsAndDepthPass(Material material)
    {
        this.material = material;
        profilingSampler = new ProfilingSampler("Edge Detect Normals And Depth");
        requiresIntermediateTexture = true;
        // 这个效果同时比较相邻像素的深度和法线。
        ConfigureInput(ScriptableRenderPassInput.Depth | ScriptableRenderPassInput.Normal);
    }

    public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
    {
        if (material == null)
            return;

        EdgeDetectNormalsAndDepthVolume volume = VolumeManager.instance.stack.GetComponent<EdgeDetectNormalsAndDepthVolume>();
        if (volume == null || !volume.IsActive())
            return;

        UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
        if (resourceData.isActiveTargetBackBuffer)
            return;

        TextureHandle source = resourceData.activeColorTexture;
        if (!source.IsValid())
            return;

        TextureDesc destinationDesc = source.GetDescriptor(renderGraph);
        destinationDesc.name = "_EdgeDetectNormalsAndDepthTexture";
        destinationDesc.depthBufferBits = 0;
        TextureHandle destination = renderGraph.CreateTexture(destinationDesc);

        material.SetFloat(EdgeOnlyId, volume.edgeOnly.value);
        material.SetColor(EdgeColorId, volume.edgeColor.value);
        material.SetColor(BackgroundColorId, volume.backgroundColor.value);
        material.SetFloat(SampleDistanceId, volume.sampleDistance.value);
        material.SetVector(SensitivityId, volume.sensitivity.value);

        RenderGraphUtils.BlitMaterialParameters blit = new(source, destination, material, 0);
        renderGraph.AddBlitPass(blit, "Edge Detect Normals And Depth");
        resourceData.cameraColor = destination;
    }
}

[Serializable, VolumeComponentMenu("Custom-Postprocessing/Edge Detect Normals And Depth")]
public class EdgeDetectNormalsAndDepthVolume : VolumeComponent, IPostProcessComponent
{
    public ClampedFloatParameter edgeOnly = new ClampedFloatParameter(1f, 0f, 1f);
    public ColorParameter edgeColor = new ColorParameter(Color.black, true, false, true);
    public ColorParameter backgroundColor = new ColorParameter(Color.white, true, false, true);
    public ClampedFloatParameter sampleDistance = new ClampedFloatParameter(1f, 0f, 5f);
    public Vector4Parameter sensitivity = new Vector4Parameter(new Vector4(1f, 1f, 1f, 1f));

    public bool IsActive()
    {
        return active;
    }

    public bool IsTileCompatible() => false;
}
