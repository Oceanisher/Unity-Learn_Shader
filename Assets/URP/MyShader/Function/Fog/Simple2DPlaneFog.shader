//2D平面高度雾
//URP的设置中需要开启Depth Texture，并且在Asset_Renderer中设置 Depth Texture Mode为 After Opaques
Shader "Custom/Simple2DPlaneFog"
{
    Properties
    {
        _BrightColor ("Bright Color(亮处颜色)", Color) = (1,1,1,1)
        _DarkColor ("Dark Color(暗处颜色)", Color) = (1,1,1,1)
        [MainTexture] _BaseMap ("Base Map(主纹理)", 2D) = "white" {}
        _MaskMap ("Mask Map(Mask纹理)", 2D) = "white" {}
        _NoisyMap ("Noisy Map(Noisy纹理)", 2D) = "white" {}
        _Speed ("U Speed(滚动速度)", Vector) = (0, 0, 0, 0)
        _TopLimit ("TopLimit(最大高度)", Float) = 1
        _BottomLimit ("BottomLimit(最大高度)", Float) = 0
        _Noisy ("Noisy(噪声调节)", Range(0, 1)) = 1
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Transparent"
            "Queue" = "Transparent"
            "RenderPipeline"="UniversalPipeline"
            "IgnoreProjector" = "True"
        }
        LOD 200
        
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            Name "Simple2DUvFlow"
            Tags
            {
                "LightMode"="UniversalForward"
            }
            
            HLSLPROGRAM
            #pragma target 2.0

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 texcoord : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 texcoord : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float4 positionSS : TEXCOORD2;
            };

            TEXTURE2D(_BaseMap);
            TEXTURE2D(_MaskMap);
            TEXTURE2D(_NoisyMap);
            SAMPLER(sampler_BaseMap);
            SAMPLER(sampler_MaskMap);
            SAMPLER(sampler_NoisyMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BrightColor;
                half4 _DarkColor;
                float4 _BaseMap_ST;
                float4 _MaskMap_ST;
                float4 _NoisyMap_ST;
                vector _Speed;
                float _TopLimit;
                float _BottomLimit;
                float _Noisy;
            CBUFFER_END

            //顶点着色器
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                //显示高度要往上显示到Top上
                half4 os = IN.positionOS;
                os.y += _TopLimit;
                OUT.positionCS = TransformObjectToHClip(os);
                OUT.positionWS = TransformObjectToWorld(IN.positionOS);
                OUT.positionSS = ComputeScreenPos(OUT.positionCS);
                OUT.texcoord = IN.texcoord;
                return OUT;
            }

            //片元着色器
            half4 frag(Varyings IN) : SV_Target
            {
                //UV流动，分2个，取小数部分，将值限定在0~1
                half2 uv = TRANSFORM_TEX(IN.texcoord, _BaseMap);
                half phase1 = _Time.y;
                half phase2 = _Time.y + 0.5;
                half2 uv1 = uv + _Speed.xy * phase1;
                half2 uv2 = uv + _Speed.zw * phase2;
                
                //主纹理采样
                half sample1 = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv1).r;
                half sample2 = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv2).r;
                half main = (sample1 + sample2) * 0.5;

                //高度计算
                float2 positionNDC = IN.positionSS.xy / IN.positionSS.w;
                #if UNITY_REVERSED_Z
                    float rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, positionNDC).r;
                #else
                    float rawDepth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, positionNDC).r);
                #endif
                float3 worldPos = ComputeWorldSpacePosition(positionNDC, rawDepth, UNITY_MATRIX_I_VP);
                float depthAlpha = 1 - saturate((worldPos.y - (IN.positionWS.y - _BottomLimit)) / (_TopLimit - _BottomLimit));
                
                //Mask采样
                half mask = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, TRANSFORM_TEX(IN.texcoord, _MaskMap)).r;
                
                //Noisy采样
                half noise = SAMPLE_TEXTURE2D(_NoisyMap, sampler_NoisyMap, TRANSFORM_TEX(IN.texcoord, _NoisyMap)).r;
                
                half3 finalColor = lerp(_DarkColor.rgb, _BrightColor.rgb, smoothstep(0,1,main));
                half alpha = saturate(mask + mask * noise * _Noisy) * depthAlpha;
                return half4(finalColor, alpha);
            }
            
            ENDHLSL
        }
    }
    
    //FallBack是一个错误Pass，会将材质绘制为紫色
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}