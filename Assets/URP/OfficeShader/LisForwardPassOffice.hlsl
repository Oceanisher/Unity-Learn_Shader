#ifndef UNIVERSAL_FORWARD_LIT_PASS_INCLUDED
#define UNIVERSAL_FORWARD_LIT_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

#if defined(_PARALLAXMAP)
#define REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR
#endif

#if (defined(_NORMALMAP) || (defined(_PARALLAXMAP) && !defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR))) || defined(_DETAIL)
#define REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR
#endif

// keep this file in sync with LitGBufferPass.hlsl

struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float2 texcoord     : TEXCOORD0;
    float2 staticLightmapUV   : TEXCOORD1;//静态光照贴图UV（光照烘焙用，由 Unity 在光照贴图模式下填充）
    float2 dynamicLightmapUV  : TEXCOORD2;//动态光照贴图UV（混合光照用，由 Unity 在光照贴图模式下填充）
    UNITY_VERTEX_INPUT_INSTANCE_ID //GPU Instancing 实例ID，实际是UnityInstancing.hlsl中的宏，最终是变量uint instanceID
};

struct Varyings
{
    float2 uv                       : TEXCOORD0;

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    float3 positionWS               : TEXCOORD1;
#endif

    float3 normalWS                 : TEXCOORD2;
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
    half4 tangentWS                : TEXCOORD3;    // xyz: tangent, w: sign
#endif

    //若启用顶点光则打包为half4（x=fog,yzw=定点光），否则启用 fogFactor
    //x是雾系数，yzw是顶点光照
#ifdef _ADDITIONAL_LIGHTS_VERTEX
    half4 fogFactorAndVertexLight   : TEXCOORD5; // x: fogFactor, yzw: vertex light 
#else
    //否则的话，只取雾系数
    half  fogFactor                 : TEXCOORD5;
#endif

    //阴影坐标
#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    float4 shadowCoord              : TEXCOORD6;
#endif

    //切线空间视线，用于视差
#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirTS                : TEXCOORD7;
#endif  

    //光照贴图 UV 或球谐（由 DECLARE_LIGHTMAP_OR_SH 决定）
    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 8);
    //动态光照贴图 UV（DYNAMICLIGHTMAP_ON 时）
#ifdef DYNAMICLIGHTMAP_ON
    float2  dynamicLightmapUV : TEXCOORD9; // Dynamic lightmap UVs
#endif

    //探针遮挡
#ifdef USE_APV_PROBE_OCCLUSION
    float4 probeOcclusion : TEXCOORD10;
#endif

    float4 positionCS               : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID //GPU Instancing实例ID，实际是UnityInstancing.hlsl中的宏，最终是变量uint instanceID
    UNITY_VERTEX_OUTPUT_STEREO //VR双眼使用
};

//初始化输入数据
void InitializeInputData(Varyings input, half3 normalTS, out InputData inputData)
{
    inputData = (InputData)0;
    
#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    //写入世界空间顶点坐标
    inputData.positionWS = input.positionWS;
#endif
    
#if defined(DEBUG_DISPLAY)
    //调试模式下，写入齐次裁剪空间顶点坐标
    inputData.positionCS = input.positionCS;
#endif

    //世界空间下的视线方向
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
#if defined(_NORMALMAP) || defined(_DETAIL)
    //如果有法线贴图、或者细节贴图，那么要额外写入世界空间下的法线
    //这里先计算出来切线空间下的转换矩阵，再使用这个矩阵，把切线空间下的法线、转换到世界空间
    float sgn = input.tangentWS.w;      // should be either +1 or -1
    float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
    half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);

    #if defined(_NORMALMAP)
    inputData.tangentToWorld = tangentToWorld;
    #endif
    inputData.normalWS = TransformTangentToWorld(normalTS, tangentToWorld);
#else
    //如果没有启用法线贴图、或者细节贴图，那么世界空间的法线使用input中的数据
    inputData.normalWS = input.normalWS;
#endif

    //将法线标准化
    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = viewDirWS;

    //如果使用顶点阴影，那么从Input中获取阴影坐标
#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    inputData.shadowCoord = input.shadowCoord;
    //如果主光源开启了计算阴影，那么需要传入世界顶点坐标、进行阴影坐标计算
#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
    //否则，不使用阴影
#else
    inputData.shadowCoord = float4(0, 0, 0, 0);
#endif
    //雾与定点光打包，如果启用顶点光，那么雾效和顶点光打在一个half4中
    //x是雾系数，yzw是顶点光照
#ifdef _ADDITIONAL_LIGHTS_VERTEX
    //计算雾系数
    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactorAndVertexLight.x);
    //写入顶点光颜色
    inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
#else
    inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor);
#endif

    //标准化的屏幕空间UV坐标
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);

    #if defined(DEBUG_DISPLAY)
    #if defined(DYNAMICLIGHTMAP_ON)
    inputData.dynamicLightmapUV = input.dynamicLightmapUV;
    #endif
    #if defined(LIGHTMAP_ON)
    inputData.staticLightmapUV = input.staticLightmapUV;
    #else
    inputData.vertexSH = input.vertexSH;
    #endif
    #if defined(USE_APV_PROBE_OCCLUSION)
    inputData.probeOcclusion = input.probeOcclusion;
    #endif
    #endif
}

void InitializeBakedGIData(Varyings input, inout InputData inputData)
{
    #if defined(_SCREEN_SPACE_IRRADIANCE)
    inputData.bakedGI = SAMPLE_GI(_ScreenSpaceIrradiance, input.positionCS.xy);
    #elif defined(DYNAMICLIGHTMAP_ON)
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, inputData.normalWS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);
    #elif !defined(LIGHTMAP_ON) && (defined(PROBE_VOLUMES_L1) || defined(PROBE_VOLUMES_L2))
    inputData.bakedGI = SAMPLE_GI(input.vertexSH,
        GetAbsolutePositionWS(inputData.positionWS),
        inputData.normalWS,
        inputData.viewDirectionWS,
        input.positionCS.xy,
        input.probeOcclusion,
        inputData.shadowMask);
    #else
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);
    #endif
}

///////////////////////////////////////////////////////////////////////////////
//                  Vertex and Fragment functions                            //
///////////////////////////////////////////////////////////////////////////////

//Lit的顶点着色器
// Used in Standard (Physically Based) shader
Varyings LitPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);//GPU Instancing 渲染初始化，最终调用了UnityInstancing.hlsl中的UnitySetupInstanceID()函数
    UNITY_TRANSFER_INSTANCE_ID(input, output);//GPU实例ID从Input传递到Output，调用了UnitInstancing.hlsl中的宏，返回的是input.instanceID
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);//VR使用

    //顶点位置变换，模型 → 世界 → 视图 → 齐次裁剪
    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

    //法线位置变换，模型 → 世界，并归一化；“已在顶点归一化”可以减轻插值后再归一化的误差，并满足 SH、顶点光等对方向的要求。
    // normalWS and tangentWS already normalize.
    // this is required to avoid skewing the direction during interpolation
    // also required for per-vertex lighting and SH evaluation
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

    //顶点光，仅在启用了顶点光时有效
    //顶点光在URP中通常用于处理“附加光源”，比如点光源、聚光灯等；可以给这些附加光源指定渲染模式是“逐顶点”或者“逐像素”
    //逐顶点的光照计算能够大幅度提升性能
    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);

    //雾系数，Unity是基于距离的全局雾，不支持高度雾（例如山谷中没有雾，山顶上才有），也不支持局部雾效
    //现在雾效在Lighting中配置
    half fogFactor = 0;
    //非片元雾时在顶点计算，如果是片元雾，这里会是0
    #if !defined(_FOG_FRAGMENT)
        fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
    #endif

    //对主UV使用_BaseMap的tiling/offset
    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

    // already normalized from normal transform to WS.
    output.normalWS = normalInput.normalWS;
    //需要切线/视差时
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR) || defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    real sign = input.tangentOS.w * GetOddNegativeScale();
    half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
#endif
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
    output.tangentWS = tangentWS;
#endif

    //视差需要切线空间视线时
#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(vertexInput.positionWS);
    half3 viewDirTS = GetViewDirectionTangentSpace(tangentWS, output.normalWS, viewDirWS);
    output.viewDirTS = viewDirTS;
#endif

    //光照贴图/球谐/动态光照
    OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
#ifdef DYNAMICLIGHTMAP_ON
    output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
#endif
    OUTPUT_SH4(vertexInput.positionWS, output.normalWS.xyz, GetWorldSpaceNormalizeViewDir(vertexInput.positionWS), output.vertexSH, output.probeOcclusion);

    //雾与顶点光，如果启用顶点光，那么雾效和顶点光打在一个half4中
#ifdef _ADDITIONAL_LIGHTS_VERTEX
    output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
#else
    //否则，只使用雾系数
    output.fogFactor = fogFactor;
#endif

#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
    output.positionWS = vertexInput.positionWS;
#endif

    //阴影坐标
#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    output.shadowCoord = GetShadowCoord(vertexInput);
#endif

    output.positionCS = vertexInput.positionCS;

    return output;
}

//Lit片元着色器
// Used in Standard (Physically Based) shader
void LitPassFragment(
    Varyings input
    , out half4 outColor : SV_Target0
    //若开启 _WRITE_RENDERING_LAYERS ，还会往SV_Target1中写渲染层
    //多目标渲染技术，SV_Target0是主RT，通常是相机看到的RT；而SV_Target1写入的是每个像素对应物体的渲染层位掩码
    //在后续的处理上，比如假如后处理中需要对某个层的像素产生光晕Bloom效果，那么就可以读取这个SV_Target1，处理对应的像素
#ifdef _WRITE_RENDERING_LAYERS
    , out uint outRenderingLayers : SV_Target1
#endif
)
{
    //Instancing渲染
    UNITY_SETUP_INSTANCE_ID(input);//GPU Instancing实例化渲染，片元着色器只需要处理一次ID即可
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    //视差贴图
#if defined(_PARALLAXMAP)
#if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirTS = input.viewDirTS;
#else
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    half3 viewDirTS = GetViewDirectionTangentSpace(input.tangentWS, input.normalWS, viewDirWS);
#endif
    ApplyPerPixelDisplacement(viewDirTS, input.uv);
#endif

    //表面数据：材质外观相关的“表面属性”都在这里从贴图和参数里采样并写入 surfaceData
    SurfaceData surfaceData;
    InitializeStandardLitSurfaceData(input.uv, surfaceData);

    //LOD淡入淡出：可能对surfaceData或后续计算做混合/丢弃，保证LOD切换平滑
#ifdef LOD_FADE_CROSSFADE
    LODFadeCrossFade(input.positionCS);
#endif

    //光照输入数据：根据顶点插值+切线空间法线整理出光照和后续计算需要的InputData
    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData);
    SETUP_DEBUG_TEXTURE_DATA(inputData, UNDO_TRANSFORM_TEX(input.uv, _BaseMap));

#if defined(_DBUFFER)
    ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
#endif

    //烘焙光照与遮蔽
    InitializeBakedGIData(input, inputData);

    //PBR光照与雾效、Alpha
    half4 color = UniversalFragmentPBR(inputData, surfaceData);//完整的PBR光照计算
    color.rgb = MixFog(color.rgb, inputData.fogCoord);//混合雾效，并放入最终颜色中
    color.a = OutputAlpha(color.a, IsSurfaceTypeTransparent(_Surface));//

    outColor = color;//写入主渲染颜色

    //渲染层 SV_Target1输出
#ifdef _WRITE_RENDERING_LAYERS
    outRenderingLayers = EncodeMeshRenderingLayer();
#endif
}

#endif
