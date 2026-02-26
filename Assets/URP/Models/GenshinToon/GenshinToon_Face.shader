Shader "GenshinToon/Face"
{
    Properties
    {
        //主纹理
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        //是否使用SDF阴影纹理
        [Toggle(_USE_SDF_SHADOW)] _UseSdfShadow("Use Sdf Shadow", Range(0, 1)) = 1
        //SDF纹理
        _SDF("SDF", 2D) = "white" {}
        //阴影遮罩纹理
        _ShadowMask("Shadow Mask", 2D) = "white" {}
        //阴影颜色，默认肉色
        _ShadowColor("Shadow Color", Color) = (1, 0.87, 0.87, 1)
        
        //头部朝向，脚本中赋值
        [HideInInspector]_HeadForward("Head Forward", Vector) = (0, 0, 1, 0)
        //头部右侧，脚本中赋值
        [HideInInspector]_HeadRight("Head Right", Vector) = (1, 0, 0, 0)
        //头部上侧，脚本中赋值
        [HideInInspector]_HeadUp("Head Left", Vector) = (0, 1, 0, 0)
        
        //腮红强度
        _FaceFlushStrength("Face Flush Strength", Range(0, 1)) = 1
        //腮红颜色
        _FaceFlushColor("Face Flush Color", Color) = (1, 1, 1, 1)
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        
        Pass
        {
            Name "UniversalForward"
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            HLSLPROGRAM

            #pragma multi_compile _MAIN_LIGHT_SHADOWS //主光源阴影
            #pragma multi_compile _MAIN_LIGHT_SHADOWS_CASCADE //主光源阴影级联
            #pragma multi_compile _MAIN_LIGHT_SHADOWS_SCREEN //主光源阴影屏幕空间

            #pragma multi_compile_fragment _LIGHT_LAYERS //光照层
            #pragma multi_compile_fragment _LIGHT_COOKIES //光照Cookie
            #pragma multi_compile_fragment _SCREEN_SPACE_OCCLUSION //屏幕空间遮挡
            #pragma multi_compile_fragment _ADDITIONAL_LIGHT_SHADOWS //额外光源阴影
            #pragma multi_compile_fragment _SHADOWS_SOFT //阴影软化
            
            #pragma shader_feature_local _USE_SDF_SHADOW //是否启用SDF阴影纹理

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
                TEXTURE2D(_BaseMap);
                TEXTURE2D(_SDF);
                TEXTURE2D(_ShadowMask);
                SAMPLER(sampler_BaseMap);
                SAMPLER(sampler_SDF);
                SAMPLER(sampler_ShadowMask);
                float4 _BaseMap_ST;
                float4 _SDF_ST;
                float4 _ShadowMask_ST;
                float3 _HeadForward;
                float3 _HeadRight;
                float3 _HeadUp;
                float3 _ShadowColor;
                float _FaceFlushStrength;
                float3 _FaceFlushColor;
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
                half4 shadowMask = SAMPLE_TEXTURE2D(_ShadowMask, sampler_ShadowMask, IN.uv);

                //面部朝向
                half3 headUpDir = normalize(_HeadUp);
                half3 headForwardDir = normalize(_HeadForward);
                half3 headRightDir = normalize(_HeadRight);
                
                //半兰伯特模型
                half3 L = normalize(light.direction);//归一化光源方向
                half3 N = normalize(IN.normalWS);//归一化法线
                half lambert = dot(N, L);//兰伯特
                half halfLambert = lambert * 0.5 + 0.5;//半兰伯特
                halfLambert *= pow(halfLambert, 2);

                //面部阴影
                half3 LpU = dot(L, headUpDir) / pow(length(headUpDir), 2) * headUpDir; // 计算光源方向在面部上方的投影
                half3 LpHeadHorizon = normalize(L- LpU); // 光照方向在头部水平面上的投影
                half value = acos(dot(LpHeadHorizon, headRightDir)) / 3.141592654; // 计算光照方向与面部右方的夹角
                half exposeRight = step(value, 0.5); // 判断光照是来自右侧还是左侧
                half valueR = pow(1 - value * 2, 3); // 右侧阴影强度
                half valueL = pow(value * 2 - 1, 3); // 左侧阴影强度
                half mixValue = lerp(valueL, valueR, exposeRight); // 混合阴影强度
                half sdfLeft = SAMPLE_TEXTURE2D(_SDF, sampler_SDF, half2(1 - IN.uv.x, IN.uv.y)).r; // 左侧距离场
                half sdfRight = SAMPLE_TEXTURE2D(_SDF, sampler_SDF, IN.uv).r; // 右侧距离场
                half mixSdf = lerp(sdfRight, sdfLeft, exposeRight); // 采样SDF纹理
                half sdf = step(mixValue, mixSdf); // 计算硬边界阴影
                sdf = lerp(0, sdf, step(0, dot(LpHeadHorizon, headForwardDir))); // 计算右侧阴影
                sdf *= shadowMask.g; // 使用G通道控制阴影强度
                sdf = lerp(sdf, 1, shadowMask.a); // 使用A通道作为阴影遮罩

                #if _USE_SDF_SHADOW
                    half3 finalColor = lerp(_ShadowColor.rgb * baseColor.rgb, baseColor.rgb, sdf);
                #else
                    half3 finalColor = baseColor.rgb * halfLambert;
                #endif

                //腮红
                half flushStrength = lerp(0, baseColor.a, _FaceFlushStrength);//BaseMap的α通道保存了面部腮红的信息
                finalColor = lerp(finalColor, finalColor * _FaceFlushColor, flushStrength);
                
                return half4(finalColor, 1);
            }
            ENDHLSL
        }

        Pass //阴影投射
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }
            
            //通常阴影投射都如此
            ZWrite On //深度写入打开
            ZTest LEqual //深度测试：小于等于
            ColorMask 0 //不写入颜色缓冲区
            Cull Off //关闭裁剪，正反两面都渲染
            
            HLSLPROGRAM
                #pragma multi_compile_instancing //启用GPU实例化编译
                #pragma multi_compile _ DOTS_INSTANCING_ON //启用DOTS实例化编译
                #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW //启用点光源阴影

                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

                #pragma vertex ShadowVS
                #pragma fragment ShadowFS

                float3 _LightDirection;//光源方向，编译器自动赋值
                float3 _LightPosition;//光源位置

                struct Attributes
                {
                    float4 positionOS : POSITION;
                    float3 normalOS : NORMAL;
                };

                struct Varyings
                {
                    float4 positionHCS : SV_POSITION;
                };

                // 将阴影的世界空间顶点位置转换为适合阴影投射的裁剪空间位置
                float4 GetShadowPositionHClip(Attributes input)
                {
                    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz); // 将本地空间顶点坐标转换为世界空间顶点坐标
                    float3 normalWS = TransformObjectToWorldNormal(input.normalOS); // 将本地空间法线转换为世界空间法线

                    #if _CASTING_PUNCTUAL_LIGHT_SHADOW // 点光源
                        float3 lightDirectionWS = normalize(_LightPosition - positionWS); // 计算光源方向
                    #else // 平行光
                        float3 lightDirectionWS = _LightDirection; // 使用预定义的光源方向
                    #endif

                    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS)); // 应用阴影偏移

                    // 根据平台的Z缓冲区方向调整Z值
                    #if UNITY_REVERSED_Z // 反转Z缓冲区
                        positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE); // 限制Z值在近裁剪平面以下
                    #else // 正向Z缓冲区
                        positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE); // 限制Z值在远裁剪平面以上
                    #endif

                    return positionCS; // 返回裁剪空间顶点坐标
                }

                Varyings ShadowVS(Attributes IN)
                {
                    Varyings OUT;
                    OUT.positionHCS = GetShadowPositionHClip(IN);
                    return OUT;
                }

                half4 ShadowFS(Varyings IN) : SV_Target
                {
                    return 0;
                }
                
            ENDHLSL
        }
    }
}
