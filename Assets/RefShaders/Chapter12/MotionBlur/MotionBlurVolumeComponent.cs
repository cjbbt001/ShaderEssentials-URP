#region VolumeComponent
using System;
using UnityEngine.Rendering;

[Serializable, VolumeComponentMenu("My Post-processing/MotionBlur")]
public class MotionBlurVolumeComponent : VolumeComponent
{
    public ClampedFloatParameter blurAmount = new ClampedFloatParameter(0.5f, 0f, 0.9f);
}
#endregion VolumeComponent