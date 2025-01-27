Shader "Hidden/MoebiusPP"
{
    Properties
    {
    }
    SubShader
    {
        Pass
        {
            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            #pragma vertex vert
            #pragma fragment frag

            int _Width;
            int _Height;

            TEXTURE2D(_NoiseMap);
            SAMPLER(sampler_NoiseMap);
            
            TEXTURE2D(_ShadowTex);
            SAMPLER(sampler_ShadowTex);
            
            TEXTURE2D(_OutlineInfo);
            SAMPLER(sampler_OutlineInfo);

            TEXTURE2D(_NormalOnly);
            SAMPLER(sampler_NormalOnly);

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            float4 _EdgeColor;
            float _SampleScale;
            float _EdgeThreshold;
            float _NormalThreshold;
            float _DepthThreshold;
            float _DistortionStrength;
            float _NoiseScale;
            float _ShadowScale;
            float _ShadowStrength;
            int _ShadowResolution;

            struct vertIn
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct vertOut
            {
                float4 positionCS : SV_POSITION;
                float2 uvs[9] : TEXCOORD1;
            };

            vertOut vert(vertIn input)
            {
                vertOut output;
                output.positionCS = TransformObjectToHClip(input.positionOS);
                float2 uv = input.uv;
                
                float uStep = 1.0 / _Width;
                float vStep = 1.0 / _Height;
                
                output.uvs[0] = uv + float2(-uStep, -vStep) * _SampleScale; // Top left
                output.uvs[1] = uv + float2(0, -vStep) * _SampleScale; // Top
                output.uvs[2] = uv + float2(uStep, -vStep) * _SampleScale; // Top right
                output.uvs[3] = uv + float2(-uStep, 0) * _SampleScale; // Left
                output.uvs[4] = uv; // Center                        
                output.uvs[5] = uv + float2(uStep, 0) * _SampleScale; // Right
                output.uvs[6] = uv + float2(-uStep, vStep) * _SampleScale; // Bottom left
                output.uvs[7] = uv + float2(0, vStep) * _SampleScale; // Bottom
                output.uvs[8] = uv + float2(uStep, vStep) * _SampleScale; // Bottom right

                return output;
            }

            float greyScale(float3 color)
            {
                return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b;
            }
            
            float4 frag(vertOut input) : SV_Target
            {
                float color[9];
                for (int i = 0; i < 9; i++)
                {
                    float2 distortion = SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, input.uvs[i] / _NoiseScale).rg * 2 - 1;
                    distortion *= _DistortionStrength;
                    color[i] = greyScale(SAMPLE_TEXTURE2D(_NormalOnly, sampler_NormalOnly, input.uvs[i] + distortion));
                }
                const float sobelX[9] = {
                    -1, 0, 1,
                    -2, 0, 2,
                    -1, 0, 1
                };

                const float sobelY[9] = {
                    -1, -2, -1,
                    0, 0, 0,
                    1, 2, 1
                };

                float Gx = 0;
                float Gy = 0;

                if (abs(color[1] - color[7]) > _NormalThreshold || abs(color[3] - color[5]) > _NormalThreshold)
                {
                    for (int i = 0; i < 9; i++)
                    {
                        Gx += color[i] * sobelX[i];
                        Gy += color[i] * sobelY[i];
                    }
                }

                
                float depth[9];
                for (int i = 0; i < 9; i ++)
                {
                    float2 distortion = SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, input.uvs[i] / _NoiseScale).rg * 2 - 1;
                    distortion *= _DistortionStrength;
                    depth[i] = 10 * SAMPLE_TEXTURE2D(_OutlineInfo, sampler_OutlineInfo, input.uvs[i] + distortion).r;
                }
                
                if (abs(depth[1] - depth[7]) > _DepthThreshold || abs(depth[3] - depth[5]) > _DepthThreshold)
                {
                    for (int i = 0; i < 9; i++)
                    {
                        Gx += greyScale(float3(depth[i], depth[i], depth[i])) * sobelX[i];
                        Gy += greyScale(float3(depth[i], depth[i], depth[i])) * sobelY[i];
                    }
                }

                float highLight[9];
                for (int i = 0; i < 9; i++)
                {
                    float2 distortion = SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, input.uvs[i] / _NoiseScale).rg * 2 - 1;
                    distortion *= _DistortionStrength;
                    highLight[i] = SAMPLE_TEXTURE2D(_OutlineInfo, sampler_OutlineInfo, input.uvs[i] + distortion).b;
                }
                
                for (int i = 0; i < 9; i++)
                {
                    Gx += highLight[i] * sobelX[i];
                    Gy += highLight[i] * sobelY[i];
                }

                float2 uv = float2(input.uvs[4].x * _Width / _ShadowResolution, input.uvs[4].y * _Height / _ShadowResolution);
                float4 shadowSample = SAMPLE_TEXTURE2D(_ShadowTex, sampler_ShadowTex, uv * _ShadowScale);
                float attenuation = SAMPLE_TEXTURE2D(_OutlineInfo, sampler_OutlineInfo, input.uvs[4]).g;

                float r = shadowSample.r * (attenuation > 0.5 ? 1 : 0);
                float g = shadowSample.g * (attenuation > 0.85 ? 1 : 0);
                float b = shadowSample.b * (attenuation > 0.96 ? 1 : 0);
                float maxShadow = _ShadowStrength * max(max(r,g),b);
                
                if (sqrt(Gx * Gx + Gy * Gy) > _EdgeThreshold)
                {
                    return _EdgeColor;
                }
                else
                {
                    return SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uvs[4]) * float4(1 - maxShadow, 1 - maxShadow, 1 - maxShadow, 1);
                }
            }
            ENDHLSL
        }
    }
    FallBack "Diffuse"
}
