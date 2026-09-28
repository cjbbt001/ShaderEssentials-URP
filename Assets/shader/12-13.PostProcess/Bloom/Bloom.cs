using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;

public class Bloom : ScriptableRendererFeature
{
    public Shader shader;
    public RenderPassEvent injectionPoint = RenderPassEvent.BeforeRenderingPostProcessing;

    Material material;
    BloomPass pass;

    public override void Create()
    {
        if (shader == null)
            shader = Shader.Find("URP/PostProcess/Bloom");
        if (shader == null)
            return;

        if (material == null || material.shader != shader)
        {
            CoreUtils.Destroy(material);
            material = CoreUtils.CreateEngineMaterial(shader);
        }

        pass = new BloomPass(material);
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

public class BloomPass : ScriptableRenderPass
{
    const int ExtractPass = 0;
    const int VerticalPass = 1;
    const int HorizontalPass = 2;
    const int CompositePass = 3;

    static readonly int LuminanceThresholdId = Shader.PropertyToID("_LuminanceThreshold");
    static readonly int BlurSizeId = Shader.PropertyToID("_BlurSize");
    static readonly int BloomIntensityId = Shader.PropertyToID("_BloomIntensity");
    static readonly int BloomTexId = Shader.PropertyToID("_Bloom");

    readonly Material material;

    class CompositePassData
    {
        public TextureHandle source;
        public TextureHandle bloom;
        public Material material;
    }

    public BloomPass(Material material)
    {
        this.material = material;
        profilingSampler = new ProfilingSampler("Bloom");
        requiresIntermediateTexture = true;
    }

    public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
    {
        if (material == null)
            return;

        BloomVolume volume = VolumeManager.instance.stack.GetComponent<BloomVolume>();
        if (volume == null || !volume.IsActive())
            return;

        UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
        if (resourceData.isActiveTargetBackBuffer)
            return;

        TextureHandle source = resourceData.activeColorTexture;
        if (!source.IsValid())
            return;

        material.SetFloat(LuminanceThresholdId, volume.luminanceThreshold.value);
        material.SetFloat(BlurSizeId, volume.blurSize.value);
        material.SetFloat(BloomIntensityId, volume.intensity.value);

        TextureDesc bloomDesc = source.GetDescriptor(renderGraph);
        bloomDesc.name = "_BloomTexture";
        bloomDesc.depthBufferBits = 0;
        // 亮部先缩小再模糊，光晕更散，也少采样。
        bloomDesc.width = Mathf.Max(1, bloomDesc.width / volume.downSample.value);
        bloomDesc.height = Mathf.Max(1, bloomDesc.height / volume.downSample.value);

        TextureHandle bloomA = renderGraph.CreateTexture(bloomDesc);
        TextureHandle bloomB = renderGraph.CreateTexture(bloomDesc);

        RenderGraphUtils.BlitMaterialParameters extract = new(source, bloomA, material, ExtractPass);
        renderGraph.AddBlitPass(extract, "Bloom Extract");

        for (int i = 0; i < volume.iterations.value; i++)
        {
            RenderGraphUtils.BlitMaterialParameters vertical = new(bloomA, bloomB, material, VerticalPass);
            renderGraph.AddBlitPass(vertical, "Bloom Vertical");

            RenderGraphUtils.BlitMaterialParameters horizontal = new(bloomB, bloomA, material, HorizontalPass);
            renderGraph.AddBlitPass(horizontal, "Bloom Horizontal");
        }

        TextureDesc destinationDesc = source.GetDescriptor(renderGraph);
        destinationDesc.name = "_BloomResult";
        destinationDesc.depthBufferBits = 0;
        TextureHandle destination = renderGraph.CreateTexture(destinationDesc);

        // 合成要同时读原图和模糊图，不能用只带一张源图的 AddBlitPass。
        using (var builder = renderGraph.AddRasterRenderPass<CompositePassData>("Bloom Composite", out var passData))
        {
            passData.source = source;
            passData.bloom = bloomA;
            passData.material = material;

            builder.UseTexture(passData.source, AccessFlags.Read);
            builder.UseTexture(passData.bloom, AccessFlags.Read);
            builder.SetRenderAttachment(destination, 0);
            builder.AllowGlobalStateModification(true);

            builder.SetRenderFunc((CompositePassData data, RasterGraphContext context) =>
            {
                data.material.SetTexture(BloomTexId, data.bloom);
                Blitter.BlitTexture(context.cmd, data.source, new Vector4(1, 1, 0, 0), data.material, CompositePass);
            });
        }

        resourceData.cameraColor = destination;
    }
}

[Serializable, VolumeComponentMenu("Custom-Postprocessing/Bloom")]
public class BloomVolume : VolumeComponent, IPostProcessComponent
{
    public ClampedFloatParameter luminanceThreshold = new ClampedFloatParameter(0.6f, 0f, 2f);
    public ClampedFloatParameter blurSize = new ClampedFloatParameter(1f, 0f, 5f);
    public ClampedIntParameter iterations = new ClampedIntParameter(2, 1, 8);
    public ClampedIntParameter downSample = new ClampedIntParameter(2, 1, 8);
    public ClampedFloatParameter intensity = new ClampedFloatParameter(1f, 0f, 5f);

    public bool IsActive()
    {
        return active && intensity.value > 0f;
    }

    public bool IsTileCompatible() => false;
}
