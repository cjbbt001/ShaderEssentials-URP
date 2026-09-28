using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;

public class GaussianBlur : ScriptableRendererFeature
{
    public Shader shader;
    public RenderPassEvent injectionPoint = RenderPassEvent.BeforeRenderingPostProcessing;

    Material material;
    GaussianBlurPass pass;

    public override void Create()
    {
        if (shader == null)
            shader = Shader.Find("URP/PostProcess/GaussianBlur");
        if (shader == null)
            return;

        if (material == null || material.shader != shader)
        {
            CoreUtils.Destroy(material);
            material = CoreUtils.CreateEngineMaterial(shader);
        }

        pass = new GaussianBlurPass(material);
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

public class GaussianBlurPass : ScriptableRenderPass
{
    static readonly int BlurSizeId = Shader.PropertyToID("_BlurSize");

    readonly Material material;

    public GaussianBlurPass(Material material)
    {
        this.material = material;
        profilingSampler = new ProfilingSampler("Gaussian Blur");
        requiresIntermediateTexture = true;
    }

    public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
    {
        if (material == null)
            return;

        GaussianBlurVolume volume = VolumeManager.instance.stack.GetComponent<GaussianBlurVolume>();
        if (volume == null || !volume.IsActive())
            return;

        UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
        if (resourceData.isActiveTargetBackBuffer)
            return;

        TextureHandle source = resourceData.activeColorTexture;
        if (!source.IsValid())
            return;

        material.SetFloat(BlurSizeId, volume.blurSize.value);

        TextureDesc blurDesc = source.GetDescriptor(renderGraph);
        blurDesc.name = "_GaussianBlurTexture";
        blurDesc.depthBufferBits = 0;
        // 先缩小再模糊。downSample 为 2 时宽高各减半。
        blurDesc.width = Mathf.Max(1, blurDesc.width / volume.downSample.value);
        blurDesc.height = Mathf.Max(1, blurDesc.height / volume.downSample.value);

        TextureHandle blurA = renderGraph.CreateTexture(blurDesc);
        TextureHandle blurB = renderGraph.CreateTexture(blurDesc);

        RenderGraphUtils.BlitMaterialParameters downsample = new(source, blurA, material, 0);
        renderGraph.AddBlitPass(downsample, "Gaussian Blur Downsample");

        // 每次迭代先竖直模糊到 B，再水平模糊回 A，避免读写同一张纹理。
        for (int i = 0; i < volume.iterations.value; i++)
        {
            RenderGraphUtils.BlitMaterialParameters vertical = new(blurA, blurB, material, 0);
            renderGraph.AddBlitPass(vertical, "Gaussian Blur Vertical");

            RenderGraphUtils.BlitMaterialParameters horizontal = new(blurB, blurA, material, 1);
            renderGraph.AddBlitPass(horizontal, "Gaussian Blur Horizontal");
        }

        TextureDesc destinationDesc = source.GetDescriptor(renderGraph);
        destinationDesc.name = "_GaussianBlurResult";
        destinationDesc.depthBufferBits = 0;
        TextureHandle destination = renderGraph.CreateTexture(destinationDesc);

        RenderGraphUtils.BlitMaterialParameters upsample = new(blurA, destination, material, 0);
        renderGraph.AddBlitPass(upsample, "Gaussian Blur Upsample");
        resourceData.cameraColor = destination;
    }
}

[Serializable, VolumeComponentMenu("Custom-Postprocessing/Gaussian Blur")]
public class GaussianBlurVolume : VolumeComponent, IPostProcessComponent
{
    public ClampedFloatParameter blurSize = new ClampedFloatParameter(1f, 0f, 3f);
    public ClampedIntParameter iterations = new ClampedIntParameter(2, 1, 8);
    public ClampedIntParameter downSample = new ClampedIntParameter(2, 1, 4);

    public bool IsActive()
    {
        return active && blurSize.value > 0f;
    }

    public bool IsTileCompatible() => false;
}
