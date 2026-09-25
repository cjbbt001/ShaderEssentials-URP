using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;


/// 一个最基本的 URP 全屏后处理。
///
/// Built-in 只需要一个挂在相机上的脚本，在 OnRenderImage 里 Graphics.Blit。
/// URP 没有这个回调，所以同一个效果要拆成三块，三块都在这个文件里：
///
/// 1. ColorAdjustment          Renderer Feature。加到 PC_Renderer 上，负责创建材质、把 Pass 排进渲染。
/// 2. ColorAdjustmentPass      真正干活的 Pass。每帧拿当前画面，用材质 Blit 一次。
/// 3. ColorAdjustmentVolume    Volume 组件。加到场景 Volume 上，只负责提供亮度、饱和度、对比度。

public class ColorAdjustment : ScriptableRendererFeature
{
    // 留空时会按名字找下面的 Shader。也可以在 Feature 的 Inspector 里手动拖。
    public Shader shader;

    // 插入点。BeforeRenderingPostProcessing 表示在 URP 内置后处理（Bloom、调色等）之前画。
    public RenderPassEvent injectionPoint = RenderPassEvent.BeforeRenderingPostProcessing;

    Material material;
    ColorAdjustmentPass pass;

    /// Feature 被创建或 Renderer 资源变化时调用。这里只做一次性的准备工作，不要在这里 Blit。
    public override void Create()
    {
        if (shader == null)
            shader = Shader.Find("URP/PostProcess/ColorAdjustment");
        if (shader == null)
            return;

        // Shader 换了就要重建材质。CoreUtils 会正确处理编辑器和运行时的销毁。
        if (material == null || material.shader != shader)
        {
            CoreUtils.Destroy(material);
            material = CoreUtils.CreateEngineMaterial(shader);
        }

        pass = new ColorAdjustmentPass(material);
        pass.renderPassEvent = injectionPoint;
    }

    /// 每台相机渲染前调用。通过检查的相机才会执行这个 Pass。
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (pass == null || material == null)
            return;

        // 预览相机、反射探针不需要后处理。Game 和 Scene 视图需要。
        CameraType cameraType = renderingData.cameraData.cameraType;
        if (cameraType != CameraType.Game && cameraType != CameraType.SceneView)
            return;

        renderer.EnqueuePass(pass);
    }

    /// Feature 被移除或 Renderer 被销毁时调用。材质是代码创建的，必须自己销毁。
    protected override void Dispose(bool disposing)
    {
        CoreUtils.Destroy(material);
    }
}

/// 对应 Built-in 的 OnRenderImage。每帧记录“这次要怎么画”，真正的绘制由 Render Graph 稍后执行。
public class ColorAdjustmentPass : ScriptableRenderPass
{
    // 属性名转成 ID，避免每帧用字符串查找。名字必须和 Shader 里的变量一致。
    static readonly int BrightnessId = Shader.PropertyToID("_Brightness");
    static readonly int SaturationId = Shader.PropertyToID("_Saturation");
    static readonly int ContrastId = Shader.PropertyToID("_Contrast");

    readonly Material material;

    public ColorAdjustmentPass(Material material)
    {
        this.material = material;
        profilingSampler = new ProfilingSampler("ColorAdjustment");

        // 告诉 URP：这个 Pass 要读取当前画面。
        // 不写的话，URP 可能把画面直接画进 BackBuffer，下面就读不到，效果等于没执行。
        requiresIntermediateTexture = true;
    }

    public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
    {
        if (material == null)
            return;

        // VolumeManager.instance.stack 是当前相机已经混合好的 Volume 结果。
        // 场景里没加这个 Override 时，拿到的是下面声明的默认值 1, 1, 1。
        ColorAdjustmentVolume volume = VolumeManager.instance.stack.GetComponent<ColorAdjustmentVolume>();
        if (volume == null || !volume.IsActive())
            return;

        UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();

        // BackBuffer 是最终显示到屏幕的那张图，不能再当作贴图采样。
        if (resourceData.isActiveTargetBackBuffer)
            return;

        // 当前画面。相当于 Built-in 里 OnRenderImage 的 src。
        TextureHandle source = resourceData.activeColorTexture;
        if (!source.IsValid())
            return;

        // 不能又读又写同一张图，所以先建一张同样大小的临时图。
        TextureDesc destinationDesc = source.GetDescriptor(renderGraph);
        destinationDesc.name = "_ColorAdjustmentTexture";
        destinationDesc.depthBufferBits = 0;
        TextureHandle destination = renderGraph.CreateTexture(destinationDesc);

        // 把 Volume 里的数值传给 Shader。
        material.SetFloat(BrightnessId, volume.brightness.value);
        material.SetFloat(SaturationId, volume.saturation.value);
        material.SetFloat(ContrastId, volume.contrast.value);

        // 相当于 Graphics.Blit(source, destination, material)。最后一个 0 是 Shader 的 Pass 下标。
        RenderGraphUtils.BlitMaterialParameters blit = new(source, destination, material, 0);
        renderGraph.AddBlitPass(blit, "ColorAdjustment");

        // 把处理后的图交还给 URP，后面的 Pass 和内置后处理都会用这张图。
        resourceData.cameraColor = destination;
    }
}


/// 出现在 Volume 的 Add Override 菜单里。它不负责画，只保存参数。
[Serializable, VolumeComponentMenu("My Post-processing/Color Adjustment")]
public class ColorAdjustmentVolume : VolumeComponent, IPostProcessComponent
{
    // 参数必须是 VolumeParameter，不能是普通 float。
    // 这样 Volume 才能单独勾选 Override，也才能在多个 Volume 之间混合。
    // 默认 1 表示不改变画面。范围和书里的 0~3 一致。
    public ClampedFloatParameter brightness = new ClampedFloatParameter(1f, 0f, 3f);
    public ClampedFloatParameter saturation = new ClampedFloatParameter(1f, 0f, 3f);
    public ClampedFloatParameter contrast = new ClampedFloatParameter(1f, 0f, 3f);

    /// 三个值都是 1 时没必要白画一次，Pass 里会直接跳过。
    public bool IsActive()
    {
        return active
            && (brightness.value != 1f || saturation.value != 1f || contrast.value != 1f);
    }

    // 这个效果要采样整张画面，不能和 Tile-Based 的延迟渲染挤在同一次绘制里。
    public bool IsTileCompatible() => false;
}
