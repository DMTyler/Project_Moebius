using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class OutlineVolume : VolumeComponent, IPostProcessComponent
{
    public Texture2DParameter Noise = new(null);
    public FloatParameter NoiseScale = new(1.0f);
    
    public Texture2DParameter Shadow = new(null);
    public FloatParameter ShadowScale = new(1.0f);
    public FloatParameter ShadowStrength = new(4f);
    
    public ColorParameter EdgeColor = new(Color.black);
    public FloatParameter EdgeThreshold = new(0.1f);
    public FloatParameter SampleScale = new(3.0f);
    public FloatParameter DepthThreshold = new(0.1f);
    public FloatParameter NormalThreshold = new(0.1f);
    public FloatParameter NoiseStrength = new(0.1f);
    
    
    public bool IsActive() => true;
    public bool IsTileCompatible() => false;
}
