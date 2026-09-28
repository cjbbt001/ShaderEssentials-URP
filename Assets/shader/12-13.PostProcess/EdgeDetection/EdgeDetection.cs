using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;

public class EdgeDetection : ScriptableRendererFeature
{
    public Shader shader;
    public RenderPassEvent injectionPoint = RenderPassEvent.BeforeRenderingPostProcessing;

    Material material;
    EdgeDetectionPass pass;

    public override void Create()
    {
        if (shader == null)
            shader = Shader.Find("URP/PostProcess/EdgeDetection");
        if (shader == null)
            return;

        if (material == null || material.shader != shader)
        {
            CoreUtils.Destroy(material);
            material = CoreUtils.CreateEngineMaterial(shader);
        }

        pass = new EdgeDetectionPass(material);
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

public class EdgeDetectionPass : ScriptableRenderPass
{
    static readonly int EdgeOnlyId = Shader.PropertyToID("_EdgeOnly");
    static readonly int EdgeColorId = Shader.PropertyToID("_EdgeColor");
    static readonly int BackgroundColorId = Shader.PropertyToID("_BackgroundColor");

    readonly Material material;

    public EdgeDetectionPass(Material material)
    {
        this.material = material;
        profilingSampler = new ProfilingSampler("Edge Detection");
        requiresIntermediateTexture = true;
    }

    public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
    {
        if (material == null)
            return;

        EdgeDetectionVolume volume = VolumeManager.instance.stack.GetComponent<EdgeDetectionVolume>();
        if (volume == null || !volume.IsActive())
            return;

        UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
        if (resourceData.isActiveTargetBackBuffer)
            return;

        TextureHandle source = resourceData.activeColorTexture;
        if (!source.IsValid())
            return;

        TextureDesc destinationDesc = source.GetDescriptor(renderGraph);
        destinationDesc.name = "_EdgeDetectionTexture";
        destinationDesc.depthBufferBits = 0;
        TextureHandle destination = renderGraph.CreateTexture(destinationDesc);

        // 边缘检测只需要一次 Blit，变化的是这三个 Shader 参数。
        material.SetFloat(EdgeOnlyId, volume.edgeOnly.value);
        material.SetColor(EdgeColorId, volume.edgeColor.value);
        material.SetColor(BackgroundColorId, volume.backgroundColor.value);

        RenderGraphUtils.BlitMaterialParameters blit = new(source, destination, material, 0);
        renderGraph.AddBlitPass(blit, "Edge Detection");
        resourceData.cameraColor = destination;
    }
}

[Serializable, VolumeComponentMenu("Custom-Postprocessing/Edge Detection")]
public class EdgeDetectionVolume : VolumeComponent, IPostProcessComponent
{
    public ClampedFloatParameter edgeOnly = new ClampedFloatParameter(1f, 0f, 1f);
    public ColorParameter edgeColor = new ColorParameter(Color.black, true, false, true);
    public ColorParameter backgroundColor = new ColorParameter(Color.white, true, false, true);

    public bool IsActive()
    {
        return active;
    }

    public bool IsTileCompatible() => false;
}
