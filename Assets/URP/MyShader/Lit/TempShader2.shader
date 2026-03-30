Shader "Custom/TempShader2"
{
    Properties
    {
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        [MainColor] _BaseColor("Color", Color) = (1,1,1,1)
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5
        _SmoothnessTextureChannel("Smoothness texture channel", Float) = 0
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        _MetallicGlossMap("Metallic (R) Smoothness (A)", 2D) = "white" {}
        _BumpScale("Normal Scale", Float) = 1.0
        _BumpMap("Normal Map", 2D) = "bump" {}
        _OcclusionStrength("Occlusion Strength", Range(0.0, 1.0)) = 1.0
        _OcclusionMap("Occlusion", 2D) = "white" {}
        [HDR] _EmissionColor("Emission Color", Color) = (0,0,0)
        _EmissionMap("Emission", 2D) = "white" {}
        [ToggleUI] _ReceiveShadows("Receive Shadows", Float) = 1.0
        [ToggleUI] _AlphaClip("Alpha Clipping", Float) = 0.0
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit"
        }
        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            ZWrite On
            Cull Back

            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex Vert
            #pragma fragment Frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile_instancing
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _EMISSION

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // ---------- 材质与纹理 ----------
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_MetallicGlossMap);
            SAMPLER(sampler_MetallicGlossMap);
            TEXTURE2D(_BumpMap);
            SAMPLER(sampler_BumpMap);
            TEXTURE2D(_OcclusionMap);
            SAMPLER(sampler_OcclusionMap);
            TEXTURE2D(_EmissionMap);
            SAMPLER(sampler_EmissionMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float _Cutoff;
                half _Smoothness;
                float _SmoothnessTextureChannel;
                half _Metallic;
                half _BumpScale;
                half _OcclusionStrength;
                half4 _EmissionColor;
                float4 _BaseMap_ST;
                float4 _MetallicGlossMap_ST;
                float4 _BumpMap_ST;
                float4 _OcclusionMap_ST;
                float4 _EmissionMap_ST;
            CBUFFER_END

            #define PI 3.14159265359

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
                float2 uv         : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float3 positionWS   : TEXCOORD1;
                float3 normalWS    : TEXCOORD2;
                float3 viewDirWS   : TEXCOORD3;
                float4 shadowCoord : TEXCOORD4;
                float3 tangentWS   : TEXCOORD5;
                float3 bitangentWS : TEXCOORD6;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            // ---------- PBR: NDF GGX ----------
            float D_GGX_Temp(float NdotH, float roughness)
            {
                float a = roughness * roughness;
                float a2 = a * a;
                float d = (NdotH * a2 - NdotH) * NdotH + 1.0;
                return a2 / max(PI * d * d, 1e-7);
            }

            float G_SchlickGGX(float NdotX, float k)
            {
                return NdotX / max(NdotX * (1.0 - k) + k, 1e-7);
            }

            float G_Smith(float NdotV, float NdotL, float roughness)
            {
                float k = (roughness + 1.0) * (roughness + 1.0) * 0.125;
                return G_SchlickGGX(NdotL, k) * G_SchlickGGX(NdotV, k);
            }

            float3 F_Schlick_Temp(float3 F0, float VdotH)
            {
                return F0 + (1.0 - F0) * pow(1.0 - saturate(VdotH), 5.0);
            }

            Varyings Vert(Attributes IN)
            {
                Varyings OUT;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                VertexPositionInputs posInput = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs nrmInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);

                OUT.positionCS = posInput.positionCS;
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.positionWS = posInput.positionWS;
                OUT.normalWS = nrmInput.normalWS;
                OUT.viewDirWS = GetWorldSpaceNormalizeViewDir(posInput.positionWS);
                OUT.shadowCoord = TransformWorldToShadowCoord(posInput.positionWS);
                OUT.tangentWS = nrmInput.tangentWS;
                OUT.bitangentWS = nrmInput.bitangentWS;
                return OUT;
            }

            half4 Frag(Varyings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
                half3 albedo = baseMap.rgb;
                half alpha = baseMap.a;

                half4 metallicGloss = SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, IN.uv);
                half metallic = metallicGloss.r * _Metallic;
                half smoothness = _Smoothness;
                if (_SmoothnessTextureChannel < 0.5)
                    smoothness *= metallicGloss.a;
                else
                    smoothness *= alpha;
                smoothness = saturate(smoothness);
                half roughness = 1.0 - smoothness;
                roughness = max(roughness, 1e-4);

                float3 N = normalize(IN.normalWS);
                #ifdef _NORMALMAP
                float3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, IN.uv));
                normalTS.xy *= _BumpScale;
                normalTS = normalize(normalTS);
                float3x3 TBN = float3x3(normalize(IN.tangentWS), normalize(IN.bitangentWS), N);
                N = normalize(mul(normalTS, TBN));
                #endif

                half occlusion = lerp(1.0, SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, IN.uv).g, _OcclusionStrength);
                half3 emission = 0.0;
                #ifdef _EMISSION
                emission = _EmissionColor.rgb * SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, IN.uv).rgb;
                #endif

                #ifdef _ALPHATEST_ON
                clip(alpha - _Cutoff);
                #endif

                float3 F0 = lerp((float3)0.04, albedo, metallic);
                float3 diffuseColor = albedo * (1.0 - metallic);

                float3 V = normalize(IN.viewDirWS);

                Light mainLight = GetMainLight(IN.shadowCoord);
                half shadowAtten = mainLight.shadowAttenuation;
                float3 L = mainLight.direction;
                float3 H = normalize(V + L);

                float NdotL = saturate(dot(N, L));
                float NdotV = max(dot(N, V), 1e-5);
                float NdotH = saturate(dot(N, H));
                float VdotH = saturate(dot(V, H));

                float3 diffuseTerm = diffuseColor / PI;
                float D = D_GGX_Temp(NdotH, roughness);
                float G = G_Smith(NdotV, NdotL, roughness);
                float3 F = F_Schlick_Temp(F0, VdotH);
                float3 specularTerm = (D * G * F) / max(4.0 * NdotV * NdotL, 1e-7);

                float3 directLight = (diffuseTerm + specularTerm) * mainLight.color * mainLight.distanceAttenuation * shadowAtten * NdotL;
                // URP Lit 使用 SAMPLE_GI(vertexSH/lightmap)，这里用常数环境光近似；0.5 使亮度接近 Lit（原 0.2 会偏黑）
                float3 ambient = albedo * 0.2 * occlusion;
                float3 color = ambient + directLight + emission;

                return half4(color, 1.0);
            }
            ENDHLSL
        }
    }

    Fallback "Universal Render Pipeline/Lit"
}
