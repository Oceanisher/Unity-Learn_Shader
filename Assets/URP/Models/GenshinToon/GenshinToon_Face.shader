Shader "GenshinToon/Face"
{
    Properties
    {
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        _LightMap("Light Map", 2D) = "white" {}
        [Toggle(_USE_LIGHTMAP_AO)] _UseLightMapAO("Use Light Map AO", Range(0, 1)) = 1
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        
        Pass
        {
            HLSLPROGRAM

            #pragma multi_compile _MAIN_LIGHT_SHADOWS //主光源阴影
            #pragma multi_compile _MAIN_LIGHT_SHADOWS_CASCADE //主光源阴影级联
            #pragma multi_compile _MAIN_LIGHT_SHADOWS_SCREEN //主光源阴影屏幕空间

            #pragma multi_compile_fragment _LIGHT_LAYERS //光照层
            #pragma multi_compile_fragment _LIGHT_COOKIES //光照Cookie
            #pragma multi_compile_fragment _SCREEN_SPACE_OCCLUSION //屏幕空间遮挡
            #pragma multi_compile_fragment _ADDITIONAL_LIGHT_SHADOWS //额外光源阴影
            #pragma multi_compile_fragment _SHADOWS_SOFT //阴影软化
            
            #pragma shader_feature_local _USE_LIGHTMAP_AO //是否启用环境光遮蔽

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
                TEXTURE2D(_BaseMap);
                TEXTURE2D(_LightMap);
                SAMPLER(sampler_BaseMap);
                SAMPLER(sampler_LightMap);
                float4 _BaseMap_ST;
                float _LightMap_ST;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.normalWS.xyz = TransformObjectToWorldNormal(IN.normalOS, false);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                //主光源
                Light light = GetMainLight();
                
                //贴图
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
                half4 lightMap = SAMPLE_TEXTURE2D(_LightMap, sampler_LightMap, IN.uv);
                
                //半兰伯特模型
                half3 L = normalize(light.direction);//归一化光源方向
                half3 N = normalize(IN.normalWS);//归一化法线
                half lambert = dot(N, L);//兰伯特
                half halfLambert = lambert * 0.5 + 0.5;//半兰伯特
                
                //AO环境光遮蔽
                #if _USE_LIGHTMAP_AO
                    half ambient = lightMap.g;//环境光，使用G通道
                    half shadow = (ambient + halfLambert) * 0.5;//阴影
                #else
                    half shadow = 1;//阴影
                #endif
                
                half4 finalColor = baseColor * halfLambert * shadow;
                return finalColor;
            }
            ENDHLSL
        }
    }
}
