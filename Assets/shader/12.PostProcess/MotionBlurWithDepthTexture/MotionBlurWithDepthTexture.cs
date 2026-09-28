using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;

public class MotionBlurWithDepthTexture : ScriptableRendererFeature
{
    public Shader shader;
    public RenderPassEvent injectionPoint = RenderPassEvent.BeforeRenderingPostProcessing;

    Material material;
    MotionBlurWithDepthTexturePass pass;

    public override void Create()
    {
        if (shader == null)
            shader = Shader.Find("URP/PostProcess/MotionBlurWithDepthTexture");
        if (shader == null)
            return;

        if (material == null || material.shader != shader)
        {
            CoreUtils.Destroy(material);
            material = CoreUtils.CreateEngineMaterial(shader);
        }

        pass = new MotionBlurWithDepthTexturePass(material);
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

public class MotionBlurWithDepthTexturePass : ScriptableRenderPass
{
    static readonly int BlurSizeId = Shader.PropertyToID("_BlurSize");
    static readonly int CurrentViewProjectionInverseId = Shader.PropertyToID("_CurrentViewProjectionInverseMatrix");
    static readonly int PreviousViewProjectionId = Shader.PropertyToID("_PreviousViewProjectionMatrix");

    readonly Material material;
    Matrix4x4 previousViewProjection = Matrix4x4.identity;

    public MotionBlurWithDepthTexturePass(Material material)
    {
        this.material = material;
        profilingSampler = new ProfilingSampler("Motion Blur With Depth Texture");
        requiresIntermediateTexture = true;
        ConfigureInput(ScriptableRenderPassInput.Depth);
    }

    public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
    {
        if (material == null)
            return;

        MotionBlurWithDepthTextureVolume volume = VolumeManager.instance.stack.GetComponent<MotionBlurWithDepthTextureVolume>();
        if (volume == null || !volume.IsActive())
            return;

        UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
        if (resourceData.isActiveTargetBackBuffer)
            return;

        TextureHandle source = resourceData.activeColorTexture;
        if (!source.IsValid())
            return;

        UniversalCameraData cameraData = frameData.Get<UniversalCameraData>();
        Matrix4x4 currentViewProjection = cameraData.GetProjectionMatrix() * cameraData.GetViewMatrix();
        // 当前矩阵的逆用于还原世界坐标，上一帧矩阵用于计算像素移动方向。
        material.SetMatrix(CurrentViewProjectionInverseId, currentViewProjection.inverse);
        material.SetMatrix(PreviousViewProjectionId, previousViewProjection);
        previousViewProjection = currentViewProjection;
        material.SetFloat(BlurSizeId, volume.blurSize.value);

        TextureDesc destinationDesc = source.GetDescriptor(renderGraph);
        destinationDesc.name = "_MotionBlurWithDepthTexture";
        destinationDesc.depthBufferBits = 0;
        TextureHandle destination = renderGraph.CreateTexture(destinationDesc);

        RenderGraphUtils.BlitMaterialParameters blit = new(source, destination, material, 0);
        renderGraph.AddBlitPass(blit, "Motion Blur With Depth Texture");
        resourceData.cameraColor = destination;
    }
}

[Serializable, VolumeComponentMenu("Custom-Postprocessing/Motion Blur With Depth Texture")]
public class MotionBlurWithDepthTextureVolume : VolumeComponent, IPostProcessComponent
{
    public ClampedFloatParameter blurSize = new ClampedFloatParameter(1f, 0f, 5f);

    public bool IsActive()
    {
        return active && blurSize.value > 0f;
    }

    public bool IsTileCompatible() => false;
}
