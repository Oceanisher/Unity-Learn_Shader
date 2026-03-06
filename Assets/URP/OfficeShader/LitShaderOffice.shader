//官方URP的LitShader复制，主要用来解读与注释
Shader "AnnotationURP/Lit"
{
    Properties
    {
        // 镜面还是金属，0=镜面工作流，1=金属工作流
        _WorkflowMode("WorkflowMode", Float) = 1.0

        //主纹理，Unity默认主纹理的名称是_BaseMap，如果想用其他的变量名作为主纹理，需要加上[MainTexture]。这个标签多个无效。
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        //主颜色，Unity默认主纹理的名称是_Color，如果想用其他的变量名作为主颜色，需要加上[MainColor]。这个标签多个无效。
        [MainColor] _BaseColor("Color", Color) = (1,1,1,1)

        //Alpha裁剪阈值，Alpha低于此值的片元会被丢弃
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        //光滑度，控制高光锐利程度和环境反射清晰度
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5
        //光滑度从哪里取值：0=从金属/高光贴图中的Alpha获取，1=从Albedo的Alpha通道获取
        _SmoothnessTextureChannel("Smoothness texture channel", Float) = 0

        //金属度(0~1),金属工作流下控制金属感强度，仅在金属工作流下使用
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        //金属度贴图（R=金属度，A=光滑度），仅在金属工作流下使用
        _MetallicGlossMap("Metallic", 2D) = "white" {}

        //高光颜色，仅在镜面工作流下使用
        _SpecColor("Specular", Color) = (0.2, 0.2, 0.2)
        //高光贴图（RGB=高光色，A光滑度），仅在镜面工作流下使用
        _SpecGlossMap("Specular", 2D) = "white" {}

        //ToggleOff如果不写标签，那么在pragma中这个变量需要被定义为"大写名称_OFF"形式
        //是否开启高光（0=关，1=开）
        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        //是否开启环境反射（天空盒/反射探针）
        [ToggleOff] _EnvironmentReflections("Environment Reflections", Float) = 1.0

        //法线强度缩放，控制法线贴图对光照的影响强度
        _BumpScale("Scale", Float) = 1.0
        //法线贴图
        _BumpMap("Normal Map", 2D) = "bump" {}

        //高度（时差）缩放，控制高度贴图产生的时差强度
        _Parallax("Scale", Range(0.005, 0.08)) = 0.005
        //高度图，产生凹凸/深度感
        _ParallaxMap("Height Map", 2D) = "black" {}

        //环境光遮蔽AO强度
        _OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
        //环境光遮蔽AO贴图，通常是灰度图
        _OcclusionMap("Occlusion", 2D) = "white" {}

        //自发光颜色，[HDR]表示可以超过1，用于发光效果
        [HDR] _EmissionColor("Color", Color) = (0,0,0)
        //自发光贴图，与_EmissionColor相乘得到最终发光
        _EmissionMap("Emission", 2D) = "white" {}

        //细节遮罩，控制细节贴图在哪些区域显示
        _DetailMask("Detail Mask", 2D) = "white" {}
        //细节漫反射贴图强度(0~2)
        _DetailAlbedoMapScale("Scale", Range(0.0, 2.0)) = 1.0
        //细节漫反射贴图，叠加在主Albedo上
        _DetailAlbedoMap("Detail Albedo x2", 2D) = "linearGrey" {}
        //细节法线强度(0~2)
        _DetailNormalMapScale("Scale", Range(0.0, 2.0)) = 1.0
        //细节法线贴图，叠加在主法线贴图上
        [Normal] _DetailNormalMap("Normal Map", 2D) = "bump" {}

        //Lit中未使用，为SRP批处理兼容保留
        // SRP batching compatibility for Clear Coat (Not used in Lit)
        [HideInInspector] _ClearCoatMask("_ClearCoatMask", Float) = 0.0
        [HideInInspector] _ClearCoatSmoothness("_ClearCoatSmoothness", Float) = 0.0

        //------------内部/隐藏属性
        // Blending state
        //表面类型(0=Opaque, 1=Transparent)
        _Surface("__surface", Float) = 0.0
        //混合模式索引
        _Blend("__blend", Float) = 0.0
        //剔除模式（0=关，1=前，2=后）
        _Cull("__cull", Float) = 2.0
        //是否开启Alpha剔除
        [ToggleUI] _AlphaClip("__clip", Float) = 0.0
        //混合因子-源
        [HideInInspector] _SrcBlend("__src", Float) = 1.0
        //混合因子-目标
        [HideInInspector] _DstBlend("__dst", Float) = 0.0
        //Alpha通道混合因子-源
        [HideInInspector] _SrcBlendAlpha("__srcA", Float) = 1.0
        //Alpha通道混合因子-目标
        [HideInInspector] _DstBlendAlpha("__dstA", Float) = 0.0
        //是否写入深度（0=不写入，1=写入）
        [HideInInspector] _ZWrite("__zw", Float) = 1.0
        //混合模式下保留高光（0=不保留，1=保留）
        [HideInInspector] _BlendModePreserveSpecular("_BlendModePreserveSpecular", Float) = 1.0
        //是否让Alpha参与MSAA覆盖率计算。在MSAA抗锯齿计算中，片元的Alpha参数计算，会让边缘更平滑；（0=不参与，1=参与）
        //典型做法：在Alpha Test的物体中开启MSAA时，用AlphaToMask可以改善边缘锯齿，而不必开Alpha Blend
        [HideInInspector] _AlphaToMask("__alphaToMask", Float) = 0.0
        //叠加预计算速度
        [HideInInspector] _AddPrecomputedVelocity("_AddPrecomputedVelocity", Float) = 0.0
        //XR下是否参与运动矢量Pass
        [HideInInspector] _XRMotionVectorsPass("_XRMotionVectorsPass", Float) = 1.0

        //是否接受阴影（0=不接受，1=接受）
        [ToggleUI] _ReceiveShadows("Receive Shadows", Float) = 1.0
        // Editmode props
        //渲染队列偏移，用于调整绘制顺序
        _QueueOffset("Queue offset", Float) = 0.0

        //------------兼容、过时的字段，通常不会主动修改
        // ObsoleteProperties
        [HideInInspector] _MainTex("BaseMap", 2D) = "white" {}
        [HideInInspector] _Color("Base Color", Color) = (1, 1, 1, 1)
        [HideInInspector] _GlossMapScale("Smoothness", Float) = 0.0
        [HideInInspector] _Glossiness("Smoothness", Float) = 0.0
        [HideInInspector] _GlossyReflections("EnvironmentReflections", Float) = 0.0

        [HideInInspector][NoScaleOffset]unity_Lightmaps("unity_Lightmaps", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset]unity_LightmapsInd("unity_LightmapsInd", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset]unity_ShadowMasks("unity_ShadowMasks", 2DArray) = "" {}
    }

    //Lit中只有一个SubShader，里面有多个Pass
    SubShader
    {
        // Universal Pipeline tag is required. If Universal render pipeline is not set in the graphics settings
        // this Subshader will fail. One can add a subshader below or fallback to Standard built-in to make this
        // material work with both Universal Render Pipeline and Builtin Unity Pipeline
        Tags
        {
            "RenderType" = "Opaque" //不透明物体
            "RenderPipeline" = "UniversalPipeline" //URP渲染管线
            "UniversalMaterialType" = "Lit" //光照材质
            "IgnoreProjector" = "True" //忽略投射器
        }
        LOD 300

        //前向渲染Pass
        //GI全局实时光照+Emission自发光+雾，都在这一个Pass中实现
        // ------------------------------------------------------------------
        //  Forward pass. Shades all light in a single pass. GI + emission + Fog
        Pass
        {
            // Lightmode matches the ShaderPassName set in UniversalRenderPipeline.cs. SRPDefaultUnlit and passes with
            // no LightMode tag are also rendered by Universal Render Pipeline
            Name "ForwardLit"
            Tags
            {
                "LightMode" = "UniversalForward" //前向渲染模式
            }

            // -------------------------------------
            // Render State Commands
            Blend[_SrcBlend][_DstBlend], [_SrcBlendAlpha][_DstBlendAlpha]
            ZWrite[_ZWrite]
            Cull[_Cull]
            AlphaToMask[_AlphaToMask]

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

            // -------------------------------------
            // 材质关键字：这些关键字都是在材质上配置的。比如如果材质使用了法线贴图，那么就会传入 _NORMALMAP 关键字
            // shader_feature、shader_feature_local，都用于定义Shader关键字，也都会生成Shader变体
            // shader_feature定义的是全局关键字，当材质引用到包含此关键字的shader时，该shader会被保存下来；
            //      Unity判断该关键字可能会被任意脚本动态开启，所以往往打包时变体会保留、导致增大包体
            // shader_feature_local定义的是本地关键字，也会生成变体，但是如果没有任何材质使用到这个关键字，那么打包时会被自动剥离掉
            //      值得注意的是，如果没有任何材质球实例使用这个关键字，那么即使代码中动态使用了这个关键字，打包时也可能会被剥离。
            // 两者区别其实在于打包时，shader_feature_local是URP推荐的默认方式，能够有效减小包体。
            // shader_feature已经逐步被取代了
            // 带一个空的下划线，表示会生成一个默认无关键字的变体shader；如果只有一个关键字，那么省略也可以，因为会默认生成一个无关键字的shader；但是如果有多个关键字，又想要没有关键字的变体，那么就必须添加 _
            // 每一行shader_feature_local中的关键字都是互斥的
            // shader_feature_local_fragment表示仅影响片元着色器，这样只会给片元着色器生成不同的变体、不影响顶点着色器
            // shader_feature_local_fragment不会减少变体数量，但是能减少变体之间冗余代码量。他们的顶点着色器代码可以共享。
            // 也有_vertex后缀，表示仅影响顶点着色器
            //
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _PARALLAXMAP
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
            #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
            #pragma shader_feature_local_fragment _SURFACE_TYPE_TRANSPARENT
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _ _ALPHAPREMULTIPLY_ON _ALPHAMODULATE_ON
            #pragma shader_feature_local_fragment _EMISSION
            #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local_fragment _OCCLUSIONMAP
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local_fragment _SPECULAR_SETUP

            // -------------------------------------
            // 渲染管线关键字：这些关键字是渲染管线维度的，不在材质上设置
            // multi_compile、shader_feature都是声明关键字的，从而生成不同的变体
            // shader_feature是材质驱动的，而multi_compile是全局的，可以通过代码动态控制
            // 无论材质是否使用到，所有声明的组合都会在构建时包含进游戏，导致变体数量增加
            // 这些属性大部分都是在URP的配置文件中设置的
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ EVALUATE_SH_MIXED EVALUATE_SH_VERTEX
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_ATLAS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _SCREEN_SPACE_IRRADIANCE
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _LIGHT_LAYERS
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"


            // -------------------------------------
            // Unity定义的关键字，有些是在Lighting中设置的、有些是别的地方设置的；也都是全局关键字
            // Unity defined keywords
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fragment _ LIGHTMAP_BICUBIC_SAMPLING
            #pragma multi_compile_fragment _ REFLECTION_PROBE_ROTATION
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ USE_LEGACY_LIGHTMAPS
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fragment _ DEBUG_DISPLAY
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Fog.hlsl"
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ProbeVolumeVariants.hlsl"

            //--------------------------------------
            // GPU Instancing关键字
            // GPU Instancing
            #pragma multi_compile_instancing //Instancing渲染关键字，让Unity生成2个shader，一个支持Instancing、一个不支持
            #pragma instancing_options renderinglayer //提供额外的Instancing选项，是可选的
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            // -------------------------------------
            // Render State Commands
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Universal Pipeline keywords

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LOD_FADE_CROSSFADE

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            // -------------------------------------
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            // Lightmode matches the ShaderPassName set in UniversalRenderPipeline.cs. SRPDefaultUnlit and passes with
            // no LightMode tag are also rendered by Universal Render Pipeline
            Name "GBuffer"
            Tags
            {
                "LightMode" = "UniversalGBuffer"
            }

            // -------------------------------------
            // Render State Commands
            ZWrite[_ZWrite]
            ZTest LEqual
            Cull[_Cull]

            HLSLPROGRAM
            //使用4.5版本的着色器模型(Shader Model)。着色器模型是微软DirectX定义的一套GPU功能标准。Unity会确保生成的代码能够在这个版本上运行。
            #pragma target 4.5 

            // Deferred Rendering Path does not support the OpenGL-based graphics API:
            // Desktop OpenGL, OpenGL ES 3.0, WebGL 2.0.
            //剔除不支持的渲染平台
            #pragma exclude_renderers gles3 glcore

            // -------------------------------------
            // Shader Stages
            #pragma vertex LitGBufferPassVertex
            #pragma fragment LitGBufferPassFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP //法线贴图关键字
            #pragma shader_feature_local_fragment _ALPHATEST_ON //Alpha测试关键字
            //#pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON
            #pragma shader_feature_local_fragment _EMISSION //自发光关键字
            #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP //金属贴图关键字
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A 
            #pragma shader_feature_local_fragment _OCCLUSIONMAP //环境光遮蔽AO贴图关键字
            #pragma shader_feature_local _PARALLAXMAP
            #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED

            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF //关闭镜面高光反射开关
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF //关闭环境反射开关
            #pragma shader_feature_local_fragment _SPECULAR_SETUP //高光工作流
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF //关闭阴影接收开关

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            //#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            //#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #pragma multi_compile _ EVALUATE_SH_MIXED EVALUATE_SH_VERTEX
            #include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fragment _ LIGHTMAP_BICUBIC_SAMPLING
            #pragma multi_compile_fragment _ REFLECTION_PROBE_ROTATION
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ USE_LEGACY_LIGHTMAPS
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_IRRADIANCE
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ProbeVolumeVariants.hlsl"

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitGBufferPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags
            {
                "LightMode" = "DepthOnly"
            }

            // -------------------------------------
            // Render State Commands
            ZWrite On
            ColorMask R
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }

        // This pass is used when drawing to a _CameraNormalsTexture texture
        Pass
        {
            Name "DepthNormals"
            Tags
            {
                "LightMode" = "DepthNormals"
            }

            // -------------------------------------
            // Render State Commands
            ZWrite On
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _PARALLAXMAP
            #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LOD_FADE_CROSSFADE

            // -------------------------------------
            // Universal Pipeline keywords
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitDepthNormalsPass.hlsl"
            ENDHLSL
        }

        // This pass it not used during regular rendering, only for lightmap baking.
        Pass
        {
            Name "Meta"
            Tags
            {
                "LightMode" = "Meta"
            }

            // -------------------------------------
            // Render State Commands
            Cull Off

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex UniversalVertexMeta
            #pragma fragment UniversalFragmentMetaLit

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _SPECULAR_SETUP
            #pragma shader_feature_local_fragment _EMISSION
            #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
            #pragma shader_feature_local_fragment _SPECGLOSSMAP
            #pragma shader_feature EDITOR_VISUALIZATION

            // -------------------------------------
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "Universal2D"
            Tags
            {
                "LightMode" = "Universal2D"
            }

            // -------------------------------------
            // Render State Commands
            Blend[_SrcBlend][_DstBlend]
            ZWrite[_ZWrite]
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex vert
            #pragma fragment frag

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON

            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Utils/Universal2D.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "MotionVectors"
            Tags { "LightMode" = "MotionVectors" }
            ColorMask RG

            HLSLPROGRAM
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma shader_feature_local_vertex _ADD_PRECOMPUTED_VELOCITY

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ObjectMotionVectors.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "XRMotionVectors"
            Tags { "LightMode" = "XRMotionVectors" }
            ColorMask RGBA

            // Stencil write for obj motion pixels
            Stencil
            {
                WriteMask 1
                Ref 1
                Comp Always
                Pass Replace
            }

            HLSLPROGRAM
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma shader_feature_local_vertex _ADD_PRECOMPUTED_VELOCITY
            #define APPLICATION_SPACE_WARP_MOTION 1

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ObjectMotionVectors.hlsl"
            ENDHLSL
        }
    }

    //FallBack是一个错误Pass，会将材质绘制为紫色
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    //使用自定义的Inspector编辑器绘制
    CustomEditor "UnityEditor.Rendering.Universal.ShaderGUI.LitShader"
}
