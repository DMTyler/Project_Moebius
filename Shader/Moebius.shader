Shader "Custom/Moebius"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        
        _HighlightColor ("Hightlight Color", Color) = (1,1,1,1)
        _HighlightThreshold ("Hightlight Threshold", Float) = 0.98
        
        _ShowShadow ("Show Shadow", Float) = 1
    }
    SubShader
    {
        Pass
        {
            HLSLPROGRAM

            #pragma shader_feature_local_fragment _EMISSION
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #define _ADDITIONAL_LIGHT_CALCULATE_SHADOWS
            // Soft Shadows
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #pragma vertex vert
            #pragma fragment frag

            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float4 _HighlightColor;
                float _HighlightThreshold;
            CBUFFER_END

            struct vertIn
            {
                float4 positionOS : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct vertOut
            {
                float4 positionCS : SV_POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float4 shadowCoord : TEXCOORD1;
            };

            vertOut vert(vertIn input)
            {
                vertOut output;
                float3 worldPos = TransformObjectToWorld(input.positionOS);
                output.positionCS = TransformObjectToHClip(input.positionOS);
                output.normal = TransformObjectToWorldNormal(input.normal);
                output.uv = input.uv;
                output.shadowCoord = TransformWorldToShadowCoord(worldPos);
                return output;
            }

            float4 frag(vertOut input) : SV_Target
            {
                Light mainLight = GetMainLight(input.shadowCoord);
                float NdotL = dot(mainLight.direction, input.normal);
                float attenuation = mainLight.distanceAttenuation * mainLight.shadowAttenuation * saturate(NdotL);
                if (attenuation > _HighlightThreshold)
                {
                    return _HighlightColor;
                }
                return _Color;
            }

            ENDHLSL
            
        }

        Pass
        {
            Tags
            {
                "LightMode" = "OutlineInfo"
                "RenderType" = "Opaque" 
            }
            ZWrite On
            ZTest LEqual
            ZClip On
            
            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #define _ADDITIONAL_LIGHT_CALCULATE_SHADOWS
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            // Soft Shadows
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            // Shadowmask
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED

            CBUFFER_START(UnityPerMaterial)
                float _HighlightThreshold;
                float _ShowShadow;
            CBUFFER_END

            struct vertIn
            {
                float4 positionOS : POSITION;
                float3 normal : NORMAL;
            };

            struct vertOut
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float4 shadowCoord : TEXCOORD1;
                float3 normal : TEXCOORD2;
            };

            vertOut vert(vertIn input)
            {
                vertOut output;
                output.positionCS = TransformObjectToHClip(input.positionOS);
                output.positionWS = TransformObjectToWorld(input.positionOS);
                output.shadowCoord = TransformWorldToShadowCoord(output.positionWS);
                output.normal = TransformObjectToWorldNormal(input.normal);
                return output;
            }

            float4 frag(vertOut input) : SV_Target
            {
                Light mainLight = GetMainLight(input.shadowCoord);
                float NdotL = dot(mainLight.direction, input.normal) * 0.5 + 0.5;
                float attenuation = mainLight.distanceAttenuation * mainLight.shadowAttenuation * NdotL;
                float luminance = 1 - attenuation;
                NdotL = dot(mainLight.direction, input.normal);
                attenuation = mainLight.distanceAttenuation * mainLight.shadowAttenuation * NdotL;
                float highlight = (attenuation > _HighlightThreshold? 0.1 : 0);
                float depth = input.positionCS.z;
                return float4(depth, luminance * _ShowShadow, highlight, 1); // Clear color is black, so x=0: far and y=0 : completely bright
            }

            ENDHLSL
        }
        
        Pass
        {
            Tags 
            { 
                "LightMode" = "NormalOnly"
                "RenderType" = "Opaque" 
            }
            ZWrite On
            ZTest LEqual
            ZClip On
            
            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #pragma vertex vert
            #pragma fragment frag

            struct vertIn
            {
                float4 positionOS : POSITION;
                float3 normal : NORMAL;
            };

            struct vertOut
            {
                float4 positionCS : SV_POSITION;
                float3 normal : NORMAL;
            };

            vertOut vert(vertIn input)
            {
                vertOut output;
                output.positionCS = TransformObjectToHClip(input.positionOS);
                output.normal = PackNormalMaxComponent(input.normal);
                return output;
            }

            float4 frag(vertOut input) : SV_Target
            {
                return float4(input.normal, 1);
            }

            ENDHLSL
        }

        UsePass "Universal Render Pipeline/Lit/SHADOWCASTER"
    }
    FallBack "Diffuse"
}
