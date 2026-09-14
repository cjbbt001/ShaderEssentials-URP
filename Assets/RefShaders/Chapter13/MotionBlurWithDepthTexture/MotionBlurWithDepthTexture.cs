#region using
using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;
#endregion

#region RendererFeature
public class MotionBlurWithDepthTexture : ScriptableRendererFeature
{
    [SerializeField] private MotionBlurWithDepthTextureSettings defaultSettings;
    [SerializeField] private Shader shader;
    [SerializeField] private RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;

    private Material material;
    private Material copyMaterial;
    private MotionBlurWithDepthTextureRenderPass motionBlurRenderPass;

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

        motionBlurRenderPass = new MotionBlurWithDepthTextureRenderPass(material, copyMaterial, defaultSettings);
        motionBlurRenderPass.renderPassEvent = renderPassEvent;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer,
        ref RenderingData renderingData)
    {
        if (motionBlurRenderPass == null)
        {
            return;
        }
        if (renderingData.cameraData.cameraType == CameraType.Game || renderingData.cameraData.cameraType == CameraType.SceneView)
        {
            // 开启深度纹理
            renderingData.cameraData.camera.depthTextureMode |= DepthTextureMode.Depth;
            renderer.EnqueuePass(motionBlurRenderPass);
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
public class MotionBlurWithDepthTextureSettings
{
    [Range(0, 5.0f)] public float blurSize = 1.0f;
}

public class MotionBlurWithDepthTextureRenderPass : ScriptableRenderPass
{
    private static readonly int blurSizeID = Shader.PropertyToID("_BlurSize");
    private static readonly int currentViewProjectionInverseMatrixID = Shader.PropertyToID("_CurrentViewProjectionInverseMatrix");
    private static readonly int previousViewProjectionMatrixID = Shader.PropertyToID("_PreviousViewProjectionMatrix");
    private const string textureName = "MotionBlurTempTexture";

    private MotionBlurWithDepthTextureSettings defaultSettings;
    private Material material;
    private Material copyMaterial;

    // 保存上一帧的视图投影矩阵
    private Matrix4x4 m_PreviousViewProjection = Matrix4x4.identity;

    private TextureDesc tempTextureDescriptor;

    public MotionBlurWithDepthTextureRenderPass(Material material, Material copyMaterial, MotionBlurWithDepthTextureSettings defaultSettings)
    {
        this.material = material;
        this.defaultSettings = defaultSettings;
        this.copyMaterial = copyMaterial;
    }

    private void UpdateEffectSettings()
    {
        if (material == null) return;

        var volumeComponent = VolumeManager.instance.stack.GetComponent<MotionBlurWithDepthTextureVolumeComponent>();
        float blurSize = volumeComponent.blurSize.overrideState ? volumeComponent.blurSize.value : defaultSettings.blurSize;

        material.SetFloat(blurSizeID, blurSize);
    }

    public override void RecordRenderGraph(RenderGraph renderGraph,
    ContextContainer frameData)
    {
        UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
        UniversalCameraData cameraData = frameData.Get<UniversalCameraData>();

        if (resourceData.isActiveTargetBackBuffer)
            return;

        TextureHandle srcCamColor = resourceData.activeColorTexture;
        tempTextureDescriptor = srcCamColor.GetDescriptor(renderGraph);
        tempTextureDescriptor.name = textureName;
        tempTextureDescriptor.depthBufferBits = 0;
        var dst = renderGraph.CreateTexture(tempTextureDescriptor);

        UpdateEffectSettings();

        //计算并设置VP矩阵
        var viewMatrix = cameraData.GetViewMatrix();
        var projMatrix = cameraData.GetProjectionMatrix();
        var currentVP = projMatrix * viewMatrix;  
        var currentVPInv = currentVP.inverse;

        material.SetMatrix(currentViewProjectionInverseMatrixID, currentVPInv);
        material.SetMatrix(previousViewProjectionMatrixID, m_PreviousViewProjection);

        m_PreviousViewProjection = currentVP;

        if (!srcCamColor.IsValid() || !dst.IsValid())
            return;

        if (material == null)
        {
            Debug.LogError("material is null, skipping pass.");
            return;
        }

        //使用效果材质将源图像处理到临时纹理
        RenderGraphUtils.BlitMaterialParameters paraFirst = new(srcCamColor, dst, material, 0);
        renderGraph.AddBlitPass(paraFirst, "MotionBlurPass_First");

        //使用拷贝材质将临时纹理复制回相机颜色目标
        RenderGraphUtils.BlitMaterialParameters paraSecond = new(dst, srcCamColor, copyMaterial, 0);
        renderGraph.AddBlitPass(paraSecond, "MotionBlurPass_Second");
    }
}
#endregion RenderPass

#region VolumeComponent
[Serializable, VolumeComponentMenu("My Post-processing/MotionBlurWithDepthTexture")]
public class MotionBlurWithDepthTextureVolumeComponent : VolumeComponent
{
    public ClampedFloatParameter blurSize = new ClampedFloatParameter(1f, 0f, 5.0f);
}
#endregion VolumeComponent