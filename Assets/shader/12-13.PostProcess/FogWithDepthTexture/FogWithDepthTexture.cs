using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;

public class FogWithDepthTexture : ScriptableRendererFeature
{
    public Shader shader;
    public RenderPassEvent injectionPoint = RenderPassEvent.BeforeRenderingPostProcessing;

    Material material;
    FogWithDepthTexturePass pass;

    public override void Create()
    {
        if (shader == null)
            shader = Shader.Find("URP/PostProcess/FogWithDepthTexture");
        if (shader == null)
            return;

        if (material == null || material.shader != shader)
        {
            CoreUtils.Destroy(material);
            material = CoreUtils.CreateEngineMaterial(shader);
        }

        pass = new FogWithDepthTexturePass(material);
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

public class FogWithDepthTexturePass : ScriptableRenderPass
{
    static readonly int FogDensityId = Shader.PropertyToID("_FogDensity");
    static readonly int FogColorId = Shader.PropertyToID("_FogColor");
    static readonly int FogStartId = Shader.PropertyToID("_FogStart");
    static readonly int FogEndId = Shader.PropertyToID("_FogEnd");

    readonly Material material;

    public FogWithDepthTexturePass(Material material)
    {
        this.material = material;
        profilingSampler = new ProfilingSampler("Fog With Depth Texture");
        requiresIntermediateTexture = true;
        // 声明这个 Pass 需要场景深度纹理。
        ConfigureInput(ScriptableRenderPassInput.Depth);
    }

    public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
    {
        if (material == null)
            return;

        FogWithDepthTextureVolume volume = VolumeManager.instance.stack.GetComponent<FogWithDepthTextureVolume>();
        if (volume == null || !volume.IsActive())
            return;

        UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
        if (resourceData.isActiveTargetBackBuffer)
            return;

        TextureHandle source = resourceData.activeColorTexture;
        if (!source.IsValid())
            return;

        TextureDesc destinationDesc = source.GetDescriptor(renderGraph);
        destinationDesc.name = "_FogWithDepthTexture";
        destinationDesc.depthBufferBits = 0;
        TextureHandle destination = renderGraph.CreateTexture(destinationDesc);

        material.SetFloat(FogDensityId, volume.fogDensity.value);
        material.SetColor(FogColorId, volume.fogColor.value);
        material.SetFloat(FogStartId, volume.fogStart.value);
        material.SetFloat(FogEndId, volume.fogEnd.value);

        RenderGraphUtils.BlitMaterialParameters blit = new(source, destination, material, 0);
        renderGraph.AddBlitPass(blit, "Fog With Depth Texture");
        resourceData.cameraColor = destination;
    }
}

[Serializable, VolumeComponentMenu("Custom-Postprocessing/Fog With Depth Texture")]
public class FogWithDepthTextureVolume : VolumeComponent, IPostProcessComponent
{
    public ClampedFloatParameter fogDensity = new ClampedFloatParameter(1f, 0f, 5f);
    public ColorParameter fogColor = new ColorParameter(Color.white, true, false, true);
    public ClampedFloatParameter fogStart = new ClampedFloatParameter(0f, -50f, 50f);
    public ClampedFloatParameter fogEnd = new ClampedFloatParameter(10f, -50f, 100f);

    public bool IsActive()
    {
        return active && fogDensity.value > 0f;
    }

    public bool IsTileCompatible() => false;
}
