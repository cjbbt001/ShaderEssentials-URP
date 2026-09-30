using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;

public class FogWithNoise : ScriptableRendererFeature
{
    public Shader shader;
    public RenderPassEvent injectionPoint = RenderPassEvent.BeforeRenderingPostProcessing;

    Material material;
    FogWithNoisePass pass;

    public override void Create()
    {
        if (shader == null)
            shader = Shader.Find("URP/Noise/FogWithNoise");
        if (shader == null)
            return;

        if (material == null || material.shader != shader)
        {
            CoreUtils.Destroy(material);
            material = CoreUtils.CreateEngineMaterial(shader);
        }

        pass = new FogWithNoisePass(material);
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

public class FogWithNoisePass : ScriptableRenderPass
{
    static readonly int FogDensityId = Shader.PropertyToID("_FogDensity");
    static readonly int FogColorId = Shader.PropertyToID("_FogColor");
    static readonly int FogStartId = Shader.PropertyToID("_FogStart");
    static readonly int FogEndId = Shader.PropertyToID("_FogEnd");
    static readonly int NoiseTexId = Shader.PropertyToID("_NoiseTex");
    static readonly int FogXSpeedId = Shader.PropertyToID("_FogXSpeed");
    static readonly int FogYSpeedId = Shader.PropertyToID("_FogYSpeed");
    static readonly int NoiseAmountId = Shader.PropertyToID("_NoiseAmount");

    readonly Material material;

    public FogWithNoisePass(Material material)
    {
        this.material = material;
        profilingSampler = new ProfilingSampler("Fog With Noise");
        requiresIntermediateTexture = true;
        ConfigureInput(ScriptableRenderPassInput.Depth);
    }

    public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
    {
        if (material == null)
            return;

        FogWithNoiseVolume volume = VolumeManager.instance.stack.GetComponent<FogWithNoiseVolume>();
        if (volume == null || !volume.IsActive())
            return;

        UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
        if (resourceData.isActiveTargetBackBuffer)
            return;

        TextureHandle source = resourceData.activeColorTexture;
        if (!source.IsValid())
            return;

        TextureDesc destinationDesc = source.GetDescriptor(renderGraph);
        destinationDesc.name = "_FogWithNoise";
        destinationDesc.depthBufferBits = 0;
        TextureHandle destination = renderGraph.CreateTexture(destinationDesc);

        material.SetFloat(FogDensityId, volume.fogDensity.value);
        material.SetColor(FogColorId, volume.fogColor.value);
        material.SetFloat(FogStartId, volume.fogStart.value);
        material.SetFloat(FogEndId, volume.fogEnd.value);
        material.SetTexture(NoiseTexId, volume.noiseTexture.value);
        material.SetFloat(FogXSpeedId, volume.fogXSpeed.value);
        material.SetFloat(FogYSpeedId, volume.fogYSpeed.value);
        material.SetFloat(NoiseAmountId, volume.noiseAmount.value);

        RenderGraphUtils.BlitMaterialParameters blit = new(source, destination, material, 0);
        renderGraph.AddBlitPass(blit, "Fog With Noise");
        resourceData.cameraColor = destination;
    }
}

[Serializable, VolumeComponentMenu("Custom-Postprocessing/Fog With Noise")]
public class FogWithNoiseVolume : VolumeComponent, IPostProcessComponent
{
    public ClampedFloatParameter fogDensity = new ClampedFloatParameter(1f, 0f, 20f);
    public ColorParameter fogColor = new ColorParameter(Color.white, true, false, true);
    public ClampedFloatParameter fogStart = new ClampedFloatParameter(0f, -50f, 50f);
    public ClampedFloatParameter fogEnd = new ClampedFloatParameter(10f, -50f, 200f);
    public TextureParameter noiseTexture = new TextureParameter(null);
    public ClampedFloatParameter fogXSpeed = new ClampedFloatParameter(0.1f, -5f, 5f);
    public ClampedFloatParameter fogYSpeed = new ClampedFloatParameter(0.1f, -5f, 5f);
    public ClampedFloatParameter noiseAmount = new ClampedFloatParameter(1f, 0f, 10f);

    public bool IsActive()
    {
        return active && fogDensity.value > 0f;
    }

    public bool IsTileCompatible() => false;
}
