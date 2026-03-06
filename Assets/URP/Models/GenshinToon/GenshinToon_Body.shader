Shader "GenshinToon/Body"
{
    Properties
    {
        //主纹理
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        
        //LightMap光照纹理，G通道存储AO信息、A通道存储Ramp色阶类型
        _LightMap("Light Map", 2D) = "white" {}
        //是否启用环境光遮蔽AO
        [Toggle(_USE_LIGHTMAP_AO)] _UseLightMapAO("Use Light Map AO", Range(0, 1)) = 1
        
        //Ramp色阶纹理，是一行一行的、每行颜色不同；同一行中从左到右颜色逐渐减淡
        //也就是说每行的左边代表在阴影中的颜色，右边代表面向光的颜色
        _RampTex("Ramp Tex", 2D) = "white" {}
        //是否使用色阶阴影
        //使用色阶阴影取代光照阴影，从而形成卡通化的渲染
        [Toggle(_USE_RAMP_SHADOW)] _UseRampShadow("Use Ramp Shadow", Range(0, 1)) = 1
        //阴影边缘宽度
        _ShadowRampWidth("Shadow Ramp Width", Float) = 1
        //阴影边界值，小于该值则是处于阴影区域
        _ShadowPosition("Shadow Position", Float) = 0.55
        //阴影柔和度
        _ShadowSoftness("Shadow Softness", Float) = 0.5
        //是否启用Ramp色阶纹理的第2行颜色
        [Toggle]_UseRamp2("Use Ramp2", Range(0, 1)) = 1
        //是否启用Ramp色阶纹理的第3行颜色
        [Toggle]_UseRamp3("Use Ramp3", Range(0, 1)) = 1
        //是否启用Ramp色阶纹理的第4行颜色
        [Toggle]_UseRamp4("Use Ramp4", Range(0, 1)) = 1
        //是否启用Ramp色阶纹理的第5行颜色
        [Toggle]_UseRamp5("Use Ramp5", Range(0, 1)) = 1
        //白天还是夜晚
        [Header(Light Options)]
        [Toggle]_NightOrDay("Night Or Day", Range(0, 1)) = 1
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        
        Pass //渲染通道
        {
            Name "UniversalForward"
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            
            Cull Off //双面绘制，为了布料
            
            HLSLPROGRAM

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN//主光源阴影、主光源阴影级联、主光源阴影屏幕空间

            #pragma multi_compile_fragment _LIGHT_LAYERS //光照层
            #pragma multi_compile_fragment _LIGHT_COOKIES //光照Cookie
            #pragma multi_compile_fragment _SCREEN_SPACE_OCCLUSION //屏幕空间遮挡
            #pragma multi_compile_fragment _ADDITIONAL_LIGHT_SHADOWS //额外光源阴影
            #pragma multi_compile_fragment _SHADOWS_SOFT //阴影软化
            
            #pragma shader_feature_local _USE_LIGHTMAP_AO //是否启用环境光遮蔽
            #pragma shader_feature_local _USE_RAMP_SHADOW //是否启用色阶阴影

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            //所有变量写到CBUFFER中，这样能够满足SRP的合批
            //SRP能够对不同材质、相同变体，进行合批处理，原因就是SRP把材质的变量属性放在CBUFFER中，减少了设置变量的时间，从而进行合批
            //UnityPerMaterial是每个材质设置
            CBUFFER_START(UnityPerMaterial)
                TEXTURE2D(_BaseMap);
                TEXTURE2D(_LightMap);
                TEXTURE2D(_RampTex);
                SAMPLER(sampler_BaseMap);
                SAMPLER(sampler_LightMap);
                SAMPLER(sampler_RampTex);
                float4 _BaseMap_ST;
                float4 _LightMap_ST;
                float4 _RampTex_ST;
                float _ShadowRampWidth;
                float _ShadowPosition;
                float _ShadowSoftness;
                float _UseRamp2;
                float _UseRamp3;
                float _UseRamp4;
                float _UseRamp5;
                float _NightOrDay;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv0 : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float4 color : COLOR0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv0 : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float4 color : TEXCOORD3;
                float4 shadowCoords : TEXCOORD4;
            };

            // 官方版本的RampShadowID函数
            //根据输入的LightMap的α通道值、以及开关控制，选择不同的色阶阴影
            //实际上就是计算在Ramp贴图中，选择哪一行的颜色，也就是计算UV中的V
            float RampShadowID(float input, float useShadow2, float useShadow3, float useShadow4, float useShadow5, 
                float shadowValue1, float shadowValue2, float shadowValue3, float shadowValue4, float shadowValue5)
            {
                // 根据input值将模型分为5个区域
                float v1 = step(0.6, input) * step(input, 0.8); // 0.6-0.8区域
                float v2 = step(0.4, input) * step(input, 0.6); // 0.4-0.6区域
                float v3 = step(0.2, input) * step(input, 0.4); // 0.2-0.4区域
                float v4 = step(input, 0.2);                    // 0-0.2区域

                // 根据开关控制是否使用不同材质的值
                float blend12 = lerp(shadowValue1, shadowValue2, useShadow2);
                float blend15 = lerp(shadowValue1, shadowValue5, useShadow5);
                float blend13 = lerp(shadowValue1, shadowValue3, useShadow3);
                float blend14 = lerp(shadowValue1, shadowValue4, useShadow4);

                // 根据区域选择对应的材质值
                float result = blend12;                // 默认使用材质1或2
                result = lerp(result, blend15, v1);    // 0.6-0.8区域使用材质5
                result = lerp(result, blend13, v2);    // 0.4-0.6区域使用材质3
                result = lerp(result, blend14, v3);    // 0.2-0.4区域使用材质4
                result = lerp(result, shadowValue1, v4); // 0-0.2区域使用材质1

                return result;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                VertexPositionInputs inputs = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionHCS = inputs.positionCS;
                OUT.uv0 = TRANSFORM_TEX(IN.uv0, _BaseMap);
                OUT.uv1 = TRANSFORM_TEX(IN.uv1, _BaseMap);
                OUT.normalWS.xyz = TransformObjectToWorldNormal(IN.normalOS, false);
                OUT.color = IN.color;
                OUT.shadowCoords = GetShadowCoord(inputs);
                return OUT;
            }

            half4 frag(Varyings IN, float face : VFACE) : SV_Target
            {
                //主光源
                Light light = GetMainLight();
                
                //贴图，为了支持布料的双面渲染，需要根据朝向面的不同，选择不同的UV。正面使用UV0，反面使用UV1
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, lerp(IN.uv0, IN.uv1, step(face, 0)));
                half4 lightMap = SAMPLE_TEXTURE2D(_LightMap, sampler_LightMap, lerp(IN.uv0, IN.uv1, step(face, 0)));
                
                //半兰伯特模型
                half3 L = normalize(light.direction);//归一化光源方向，这里的direction是反方向，也就是从顶点到光源的方向
                half3 N = normalize(IN.normalWS);//归一化法线
                half lambert = dot(N, L);//兰伯特
                half halfLambert = lambert * 0.5 + 0.5;//半兰伯特
                halfLambert *= pow(halfLambert, 2);
                half lambertStep = smoothstep(0.01, 0.4, halfLambert);//平滑取值
                half shadowFactor = lerp(0, halfLambert, lambertStep);//阴影因子，主要是用来处理阴影边界，使其平滑过渡；原先使用halfLambert的地方，现在就使用这个阴影因子了
                
                //AO环境光遮蔽
                #if _USE_LIGHTMAP_AO
                    half ambient = lightMap.g;//环境光，使用G通道
                #else
                    half ambient = halfLambert;//环境光，直接使用halfLambert
                #endif

                //阴影，加入了主光源阴影投射
                half shadowAtten = MainLightRealtimeShadow(IN.shadowCoords);//主光源阴影，接受来自其他物体的阴影投射
                half shadow = (ambient + halfLambert) * 0.5;//阴影，因为ambient、halfLambert的值范围都是0~1，所以相加之后乘以0.5就能把shadow控制在0~1的范围中
                shadow *= shadowAtten;
                shadow = lerp(shadow, 1, step(0.95, ambient));//非常亮的区域直接赋值为1
                shadow = lerp(shadow, 0, step(ambient, 0.05));//非常暗的区域直接赋值为0
                
                //色阶
                half isShadowArea = step(shadow, _ShadowPosition);//是否是阴影区域，小于_ShadowPosition，是在阴影区域
                half shadowDepth = saturate((_ShadowPosition - shadow) / _ShadowPosition);//阴影深度，其实就是shadow值越远离_ShadowPosition，那么这个Depth就越大；由于可能有负值，所以需要限制在0~1之间
                shadowDepth = min(pow(shadowDepth, _ShadowSoftness), 1);//阴影深度值使用阴影柔和度，并限制不超过1；用来决定在色阶纹理的U
                half rampWidthFactor = IN.color.g * 2 * _ShadowRampWidth;//读取顶点中的G通道，计算出Ramp边缘影响因子
                // half shadowPosition = (_ShadowPosition - shadowFactor) / _ShadowPosition;//使用阴影因子计算阴影边界值

                half rampU = 1 - saturate(shadowDepth / rampWidthFactor);//计算在Ramp贴图UV中的U
                half rampID = RampShadowID(lightMap.a, _UseRamp2, _UseRamp3, _UseRamp4, _UseRamp5, 1, 2, 3, 4, 5);//计算在Ramp贴图UV中的编号
                half rampV = 0.45 - (rampID - 1) * 0.1;//计算在Ramp贴图UV中的V，官方计算方法，rampID的取值是1~5整数
                half2 rampUV = half2(rampU, lerp(rampV, rampV + 0.5, _NightOrDay));//计算RampUV
                half4 rampColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, rampUV);

                 #if _USE_RAMP_SHADOW
                    //色阶阴影
                    half3 finalColor = baseColor.rgb * rampColor.rgb * smoothstep(1.2, 1, isShadowArea);
                #else
                    //普通阴影
                    half3 finalColor = baseColor.rgb * halfLambert * (shadow + 0.2);
                #endif
                
                return float4(finalColor.rgb, 1);
                // return float4(shadowAtten, shadowAtten, shadowAtten, 1);
            }
            ENDHLSL
        }

        //使用URP自身的阴影投射Pass
        UsePass "Universal Render Pipeline/Lit/SHADOWCASTER"

//        Pass //阴影投射
//        {
//            Name "ShadowCaster"
//            Tags
//            {
//                "LightMode" = "ShadowCaster"
//            }
//            
//            //通常阴影投射都如此
//            ZWrite On //深度写入打开
//            ZTest LEqual //深度测试：小于等于
//            ColorMask 0 //不写入颜色缓冲区
//            Cull Off //关闭裁剪，正反两面都渲染
//            
//            HLSLPROGRAM
//                #pragma multi_compile_instancing //启用GPU实例化编译
//                #pragma multi_compile _ DOTS_INSTANCING_ON //启用DOTS实例化编译
//                #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW //启用点光源阴影
//
//                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
//                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
//
//                #pragma vertex ShadowVS
//                #pragma fragment ShadowFS
//
//                float3 _LightDirection;//光源方向，编译器自动赋值
//                float3 _LightPosition;//光源位置
//
//                struct Attributes
//                {
//                    float4 positionOS : POSITION;
//                    float3 normalOS : NORMAL;
//                };
//
//                struct Varyings
//                {
//                    float4 positionHCS : SV_POSITION;
//                };
//
//                // 将阴影的世界空间顶点位置转换为适合阴影投射的裁剪空间位置
//                float4 GetShadowPositionHClip(Attributes input)
//                {
//                    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz); // 将本地空间顶点坐标转换为世界空间顶点坐标
//                    float3 normalWS = TransformObjectToWorldNormal(input.normalOS); // 将本地空间法线转换为世界空间法线
//
//                    #if _CASTING_PUNCTUAL_LIGHT_SHADOW // 点光源
//                        float3 lightDirectionWS = normalize(_LightPosition - positionWS); // 计算光源方向
//                    #else // 平行光
//                        float3 lightDirectionWS = _LightDirection; // 使用预定义的光源方向
//                    #endif
//
//                    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS)); // 应用阴影偏移
//
//                    // 根据平台的Z缓冲区方向调整Z值
//                    #if UNITY_REVERSED_Z // 反转Z缓冲区
//                        positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE); // 限制Z值在近裁剪平面以下
//                    #else // 正向Z缓冲区
//                        positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE); // 限制Z值在远裁剪平面以上
//                    #endif
//
//                    return positionCS; // 返回裁剪空间顶点坐标
//                }
//
//                Varyings ShadowVS(Attributes IN)
//                {
//                    Varyings OUT;
//                    OUT.positionHCS = GetShadowPositionHClip(IN);
//                    return OUT;
//                }
//
//                half4 ShadowFS(Varyings IN) : SV_Target
//                {
//                    return 0;
//                }
//                
//            ENDHLSL
//        }
    }
}
