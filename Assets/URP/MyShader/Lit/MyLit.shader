Shader "Custom/MyLit"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        //光滑度
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 1
        //金属度
        _Metallic("Metallic", Range(0.0, 1.0)) = 1
        //金属度贴图
        _MetallicMap("Metallic Map", 2D) = "white" {}
    }

    SubShader
    {
        Tags {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "MyLitForwardPass"
            Tags
            {
                "LightMode" = "UniversalForward"//前向渲染
            }
            
            ZWrite True //写入深度
            
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 viewDirWS : TEXCOORD3; //世界空间指向相机
            };

            TEXTURE2D(_BaseMap);
            TEXTURE2D(_MetallicMap);
            SAMPLER(sampler_BaseMap);
            SAMPLER(sampler_MetallicMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float _Smoothness;
                float _Metallic;
                float4 _BaseMap_ST;
                float4 _MetallicMap_ST;
            CBUFFER_END

            //PBR计算
            half4 PBRCal(Varyings IN, Light mainLight, half4 color)
            {
                
                return half4(1, 1, 1, 1);
            }

            // 法线分布函数 GGX
            float D_GGX_My(float NdotH, float roughness)
            {
                float a = roughness * roughness;
                float a2 = a * a;
                float d = (NdotH * a2 - NdotH) * NdotH + 1.0;
                return a2 / (PI * d * d);
            }

            // 几何遮蔽函数 Smith（使用分离遮蔽，与粗糙度相关）
            float G_Smith_My(float NdotV, float NdotL, float roughness)
            {
                float a = roughness * roughness;
                float k = (a + 1.0) * (a + 1.0) / 8.0;   // 对于直接光照的简化k
                float G1V = NdotV / (NdotV * (1.0 - k) + k);
                float G1L = NdotL / (NdotL * (1.0 - k) + k);
                return G1V * G1L;
            }

            // 菲涅尔项 Schlick 近似
            float3 F_Schlick_My(float3 F0, float VdotH)
            {
                return F0 + (1.0 - F0) * pow(1.0 - VdotH, 5.0);
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                VertexPositionInputs input = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                OUT.positionCS = input.positionCS;
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.positionWS = input.positionWS;
                OUT.normalWS = normalInput.normalWS;
                OUT.viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
                half3 albedo = baseMap.rgb;
                half alpha = baseMap.a;

                Light mainLight = GetMainLight();//主光源

                //金属度计算:_MetallicMap采样 * _Metallic
                half metallic = saturate(SAMPLE_TEXTURE2D(_MetallicMap, sampler_MetallicMap, IN.uv) * _Metallic);

                //FO基础反射率
                float3 F0 = lerp(0.04, albedo, metallic);//非金属的反射率是0.04
                //漫反射颜色
                float3 diffuseColor = albedo * (1 - F0);//金属没有漫反射

                //归一化向量
                float3 N = normalize(IN.normalWS);
                float3 V = normalize(IN.viewDirWS);
                float3 L = normalize(mainLight.direction); //指向光源
                float3 H = normalize(V + L); //视线方向、光源方向的中间方向

                //点乘计算，限制非负
                float NdotL = max(dot(N, L), 0.0);
                float NdotV = max(dot(N, V), 0.0);
                float NdotH = max(dot(N, H), 0.0);
                float VdotH = max(dot(V, H), 0.0);
                if (NdotL <= 0.0)//表面背对光源，剔除
                {
                    return float4(0, 0, 0, alpha); 
                }

                //-----计算BRDF
                //漫反射项
                float3 diffuseTerm = diffuseColor / PI;
                //镜面反射项
                float D = D_GGX_My(NdotH, 1 - _Smoothness);
                float G = G_Smith_My(NdotV, NdotL, 1 - _Smoothness);
                float3 F = F_Schlick_My(F0, VdotH);
                float3 specularTerm = (D * G * F) / max(4.0 * NdotV * NdotL, 0.001);   // 避免除零

                //计算最终颜色
                float3 finalColor = (diffuseTerm + specularTerm) * mainLight.color * NdotL;
                return float4(finalColor, alpha);
            }
            
            ENDHLSL
        }
    }
}
