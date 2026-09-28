using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;

// RendererFeature
public class Test : ScriptableRendererFeature
{
    // 声明参数
    public Shader shader;
    public RenderPassEvent injectionPoint = RenderPassEvent.BeforeRenderingPostProcessing;
    Material material;
    TestPass pass;

    // Create(): 找shader，创建材质，新建Pass
    public override void Create()
    {
        if (shader == null)
            shader = Shader.Find("URP/PostProcess/Test");
        if (shader == null)
            return;

        if (material == null || material.shader != shader)
        {
            CoreUtils.Destroy(material);
            material = CoreUtils.CreateEngineMaterial(shader);
        }

        pass = new TestPass(material);
        pass.renderPassEvent = injectionPoint;
    }

    // AddRenderPasses(): 检查pass和material，game/scene视图，把pass加进队列
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (pass == null || material == null)
            return;

        CameraType cameraType = renderingData.cameraData.cameraType;
        if (cameraType != CameraType.Game && cameraType != CameraType.SceneView)
            return;

        renderer.EnqueuePass(pass);
    }

    // Feature被移除时销毁material
    protected override void Dispose(bool disposing)
    {
        CoreUtils.Destroy(material);
    }
}

// RenderPass
public class TestPass : ScriptableRenderPass
{
    static readonly int BrightnessID = Shader.PropertyToID("_Brightness");
    static readonly int SaturationId = Shader.PropertyToID("_Saturation");
    static readonly int ContrastId = Shader.PropertyToID("_Contrast");

    readonly Material material; //保存一份material在这个类里使用

    // 构造函数：保存material，声明这个Pass读取当前画面到中间纹理而不是直接进BackBuffer
    public TestPass(Material material)
    {
        this.material = material;
        profilingSampler = new ProfilingSampler("Test");
        requiresIntermediateTexture = true; //  声明要读取当前画面到中间纹理 
    }

    public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
    {
        if (material == null)
            return;

        TestVolume volume = VolumeManager.instance.stack.GetComponent<TestVolume>();
        if (volume == null || !volume.IsActive())
            return;

        UniversalResourceData resourceData = frameData.Get<UniversalResourceData>(); // 取出当前的渲染资源
        if (resourceData.isActiveTargetBackBuffer) // 已经是最终画面就不做
            return;

        // 当前画面 source
        TextureHandle source = resourceData.activeColorTexture;
        if (!source.IsValid())
            return;

        // 新建大小相同的Texture
        TextureDesc destinationDesc = source.GetDescriptor(renderGraph); // 读取当前画面的纹理描述
        destinationDesc.name = "_TestTexture";
        destinationDesc.depthBufferBits = 0;
        TextureHandle destination = renderGraph.CreateTexture(destinationDesc);

        material.SetFloat(BrightnessID, volume.brightness.value);
        material.SetFloat(SaturationId, volume.saturation.value);
        material.SetFloat(ContrastId, volume.contrast.value);

        // 把绘制登记进 Render Graph
        RenderGraphUtils.BlitMaterialParameters blit = new(source, destination, material, 0);
        renderGraph.AddBlitPass(blit, "Test");

        // 交还结果
        resourceData.cameraColor = destination;

    }
}

// VolumeComponent 
[Serializable, VolumeComponentMenu("Custom-Postprocessing/Test")]
public class TestVolume : VolumeComponent,IPostProcessComponent
{
    public ClampedFloatParameter brightness = new ClampedFloatParameter(1f, 0f, 3f);
    public ClampedFloatParameter saturation = new ClampedFloatParameter(1f, 0f, 3f);
    public ClampedFloatParameter contrast = new ClampedFloatParameter(1f, 0f, 3f);

    public bool IsActive()
    {
        return active && (brightness.value != 1f || saturation.value != 1f || contrast.value != 1f);
    }

    public bool IsTileCompatible() => false;
}