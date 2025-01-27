using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class OutlinePassFeature : ScriptableRendererFeature
{
    private OutlinePass _edgeDetectPass;
    private static readonly int ShadowTex = Shader.PropertyToID("_ShadowTex");
    private static readonly int ShadowScale = Shader.PropertyToID("_ShadowScale");
    private static readonly int ShadowStrength = Shader.PropertyToID("_ShadowStrength");
    private static readonly int ShadowResolution1 = Shader.PropertyToID("_ShadowResolution");

    private class OutlinePass : ScriptableRenderPass
    {
        private readonly Material _material = new(Shader.Find("Hidden/MoebiusPP"));
        private RTHandle _source;
        private readonly int _target = Shader.PropertyToID("_EdgeOutline");
        
        private static readonly int EdgeColor = Shader.PropertyToID("_EdgeColor");
        private static readonly int EdgeThreshold = Shader.PropertyToID("_EdgeThreshold");
        private static readonly int SampleScale = Shader.PropertyToID("_SampleScale");
        
        private static readonly int Width = Shader.PropertyToID("_Width");
        private static readonly int Height = Shader.PropertyToID("_Height");
        
        private static readonly int DepthThreshold = Shader.PropertyToID("_DepthThreshold");
        private static readonly int NormalThreshold = Shader.PropertyToID("_NormalThreshold");
        private static readonly int NoiseMap = Shader.PropertyToID("_NoiseMap");
        private static readonly int DistortionStrength = Shader.PropertyToID("_DistortionStrength");
        private static readonly int NoiseScale = Shader.PropertyToID("_NoiseScale");
        

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            _source = renderingData.cameraData.renderer.cameraColorTargetHandle;
        }
        
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (renderingData.cameraData.cameraType != CameraType.Game)
                return;
            
            if (_source is null || _material is null)
            {
                Debug.LogWarning("OutlinePass: Missing source or material");
                return;
            }
            var volume = VolumeManager.instance.stack.GetComponent<OutlineVolume>();
            if (volume is null)
            {
                Debug.LogWarning("OutlinePass: Missing volume");
                return;
            }
            
            _material.SetTexture(ShadowTex, volume.Shadow.value);
            _material.SetTexture(NoiseMap, volume.Noise.value);
            _material.SetColor(EdgeColor, volume.EdgeColor.value);
            _material.SetFloat(EdgeThreshold, volume.EdgeThreshold.value);
            _material.SetFloat(SampleScale, volume.SampleScale.value);
            _material.SetFloat(DepthThreshold, volume.DepthThreshold.value / 100.0f);
            _material.SetFloat(NormalThreshold, volume.NormalThreshold.value);
            _material.SetFloat(DistortionStrength, volume.NoiseStrength.value / 100.0f);
            _material.SetFloat(NoiseScale, volume.NoiseScale.value);
            _material.SetFloat(ShadowScale, volume.ShadowScale.value);
            _material.SetFloat(ShadowStrength, volume.ShadowStrength.value);
            
            var camera = renderingData.cameraData.camera;
            var width = camera.pixelWidth;
            var height = camera.pixelHeight;
            
            _material.SetInt(Width, width);
            _material.SetInt(Height, height);
            if (volume.Shadow.value != null)
                _material.SetInt(ShadowResolution1, volume.Shadow.value.width);
            else
                _material.SetInt(ShadowResolution1, 128);
            
            var cmd = CommandBufferPool.Get("Edge Outline");
            cmd.SetGlobalTexture("_MainTex", _source);
            cmd.GetTemporaryRT(_target, width, height, 0, FilterMode.Bilinear, RenderTextureFormat.ARGBFloat);
            cmd.Blit(_source, _target);
            cmd.Blit(_target, _source, _material);
            cmd.ReleaseTemporaryRT(_target);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }
    
    public override void Create()
    {
        _edgeDetectPass = new OutlinePass
        {
            renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing
        };
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(_edgeDetectPass);
    }
}
