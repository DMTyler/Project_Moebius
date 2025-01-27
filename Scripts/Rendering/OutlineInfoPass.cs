using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class OutlineInfoPassFeature : ScriptableRendererFeature
{
    private ScriptableRenderPass _normalOnlyPass;

    private class OutlineInfoPass : ScriptableRenderPass
    {
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var camera = renderingData.cameraData.camera;
            if (!camera.TryGetCullingParameters(out var cullingParameters))
                return;
            var normalCmd = CommandBufferPool.Get("NormalOnlyPass");
            var normalTarget = Shader.PropertyToID("NormalTarget");
            
            normalCmd.GetTemporaryRT(normalTarget, camera.pixelWidth, camera.pixelHeight, 16, FilterMode.Bilinear, RenderTextureFormat.ARGBFloat);
            normalCmd.SetRenderTarget(normalTarget);
            normalCmd.ClearRenderTarget(true, true, Color.clear);
            normalCmd.SetGlobalTexture("_NormalOnly", normalTarget);
            context.ExecuteCommandBuffer(normalCmd);
            
            var cullingResult = context.Cull(ref cullingParameters);
            // Draw only the normal buffer shader pass
            var drawSettings = CreateDrawingSettings(new ShaderTagId("NormalOnly"), ref renderingData, SortingCriteria.CommonOpaque);
            var filterSettings = new FilteringSettings(RenderQueueRange.opaque);
            context.DrawRenderers(cullingResult, ref drawSettings, ref filterSettings);
            
            var infoCmd = CommandBufferPool.Get("OutlineInfoPass");
            var depthTarget = Shader.PropertyToID("DepthTarget");
            
            infoCmd.GetTemporaryRT(depthTarget, camera.pixelWidth, camera.pixelHeight, 16, FilterMode.Bilinear, RenderTextureFormat.ARGBFloat);
            infoCmd.SetRenderTarget(depthTarget);
            infoCmd.ClearRenderTarget(true, true, Color.clear);
            infoCmd.SetGlobalTexture("_OutlineInfo", depthTarget);
            context.ExecuteCommandBuffer(infoCmd);
            
            // Draw only the depth & attenuation buffer shader pass
            drawSettings = CreateDrawingSettings(new ShaderTagId("OutlineInfo"), ref renderingData, SortingCriteria.CommonOpaque);
            context.DrawRenderers(cullingResult, ref drawSettings, ref filterSettings);
            
            normalCmd.Clear();
            infoCmd.Clear();
            
            CommandBufferPool.Release(normalCmd);
            CommandBufferPool.Release(infoCmd);
        }
    }

    public override void Create()
    {
        _normalOnlyPass = new OutlineInfoPass();
        _normalOnlyPass.renderPassEvent = RenderPassEvent.BeforeRenderingOpaques;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (_normalOnlyPass is null)
            return;
        renderer.EnqueuePass(_normalOnlyPass);
    }
}

