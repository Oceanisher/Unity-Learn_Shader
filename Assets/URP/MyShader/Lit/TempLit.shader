Shader "Custom/TempLit"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap("Base Map (Albedo)", 2D) = "white" {}
        _Metallic("Metallic", Range(0.0, 1.0)) = 0
        _MetallicMap("Metallic Map", 2D) = "white" {}
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "TempLitForward"
            Tags { "LightMode" = "UniversalForward" }

            ZWrite On
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv        : TEXCOORD0;
                float3 positionWS: TEXCOORD1;
                float3 normalWS  : TEXCOORD2;
                float3 viewDirWS : TEXCOORD3;
            };

            TEXTURE2D(_BaseMap);
            TEXTURE2D(_MetallicMap);
            SAMPLER(sampler_BaseMap);
            SAMPLER(sampler_MetallicMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half _Metallic;
                half _Smoothness;
                float4 _BaseMap_ST;
                float4 _MetallicMap_ST;
            CBUFFER_END

            // ---------- PBR 核心：仅用 Core.hlsl + Lighting.hlsl，其余自实现 ----------

            #define PI 3.14159265359

            // 法线分布 NDF - GGX/Trowbridge-Reitz
            float D_GGX_TEMP(float NdotH, float roughness)
            {
                float a = roughness * roughness;
                float a2 = a * a;
                float d = (NdotH * (NdotH * (a2 - 1.0) + 1.0));
                d = d * d * PI;
                return (d > 0.0) ? (a2 / max(d, 1e-7)) : 0.0;
            }

            // 几何遮蔽 G - Smith (Schlick-GGX 近似)
            float G_SchlickGGX(float NdotX, float k)
            {
                return NdotX / max(NdotX * (1.0 - k) + k, 1e-7);
            }
            float G_Smith(float NdotV, float NdotL, float roughness)
            {
                float k = (roughness + 1.0) * (roughness + 1.0) * 0.125;
                return G_SchlickGGX(NdotL, k) * G_SchlickGGX(NdotV, k);
            }

            // 菲涅尔 F - Schlick
            float3 F_Schlick_TEMP(float3 F0, float VdotH)
            {
                return F0 + (1.0 - F0) * pow(1.0 - saturate(VdotH), 5.0);
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                VertexPositionInputs posInput = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs nrmInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);

                OUT.positionCS = posInput.positionCS;
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.positionWS = posInput.positionWS;
                OUT.normalWS = nrmInput.normalWS;
                OUT.viewDirWS = GetWorldSpaceNormalizeViewDir(posInput.positionWS);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 baseSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
                half3 albedo = baseSample.rgb;
                half alpha = baseSample.a;

                // 金属度：贴图 * 标量
                half metallic = saturate(SAMPLE_TEXTURE2D(_MetallicMap, sampler_MetallicMap, IN.uv).r * _Metallic);
                half roughness = 1.0 - _Smoothness;
                roughness = max(roughness, 1e-4);

                // 基础反射率 F0：非金属 0.04，金属用 albedo
                float3 F0 = lerp((float3)0.04, albedo, metallic);
                // 漫反射：金属无漫反射
                float3 diffuseColor = albedo * (1.0 - metallic);

                float3 N = normalize(IN.normalWS);
                float3 V = normalize(IN.viewDirWS);

                // 仅主光源，无阴影
                Light mainLight = GetMainLight();
                float3 L = mainLight.direction;
                float3 H = normalize(V + L);

                float NdotL = saturate(dot(N, L));
                float NdotV = max(dot(N, V), 1e-5);
                float NdotH = saturate(dot(N, H));
                float VdotH = saturate(dot(V, H));

                // 背光直接返回
                if (NdotL <= 0.0)
                    return half4(0.0, 0.0, 0.0, alpha);

                // 漫反射项 (Lambert)
                float3 diffuseTerm = diffuseColor / PI;

                // 镜面项 (Cook-Torrance BRDF)
                float D = D_GGX_TEMP(NdotH, roughness);
                float G = G_Smith(NdotV, NdotL, roughness);
                float3 F = F_Schlick_TEMP(F0, VdotH);
                float3 specularTerm = (D * G * F) / max(4.0 * NdotV * NdotL, 1e-7);

                float3 brdf = (diffuseTerm + specularTerm) * mainLight.color * NdotL;
                return half4(brdf, alpha);
            }
            ENDHLSL
        }
    }

    Fallback "Universal Render Pipeline/Lit"
}
