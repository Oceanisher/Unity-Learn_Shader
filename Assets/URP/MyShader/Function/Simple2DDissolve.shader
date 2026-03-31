//简单2D的溶解
Shader "Custom/Simple2DDissolve"
{
    Properties
    {
        [MainColor] _BaseColor ("Base Color(主颜色)", Color) = (1,1,1,1)
        [MainTexture] _BaseMap ("Base Map(纹理)", 2D) = "white" {}
        [HDR]_DissolveEdgeColor ("Dissolve Edge Color(溶解颜色-边缘)", Color) = (1,1,1,1)
        [HDR]_DissolveInnerColor ("Dissolve Inner Color(溶解颜色-内部)", Color) = (1,1,1,1)
        _DissolveMap ("Dissolve Map(溶解噪声)", 2D) = "white" {}
        _Proc ("Proc(溶解进度)", Range(0, 1)) = 0
        _EdgeWidth ("Edge Width(边缘宽度)", Range(0, 0.5)) = 0.05
        _InnerWidth ("Inner Width(内部宽度)", Range(0, 0.5)) = 0.05
        _AlphaWidth ("Alpha Width(边缘透明)", Range(0, 0.5)) = 0.05
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

        Pass
        {
            Name "Simple2DDissolve"
            Tags
            {
                "LightMode"="UniversalForward"
            }
            
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            
            HLSLPROGRAM
            #pragma target 2.0

            // #pragma shader_feature_local _ALPHATEST_ON
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            #pragma vertex vert
            #pragma fragment frag

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float2 uvNoise : TEXCOORD1;
            };

            TEXTURE2D(_BaseMap);
            TEXTURE2D(_DissolveMap);
            SAMPLER(sampler_BaseMap);
            SAMPLER(sampler_DissolveMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half4 _DissolveEdgeColor;
                half4 _DissolveInnerColor;
                float4 _BaseMap_ST;
                float4 _DissolveMap_ST;
                float _Proc;
                float _EdgeWidth;
                float _InnerWidth;
                float _AlphaWidth;
            CBUFFER_END

            //顶点着色器
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.uvNoise = TRANSFORM_TEX(IN.uv, _DissolveMap);
                return OUT;
            }

            //片元着色器
            half4 frag(Varyings IN) : SV_Target
            {
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
                half4 noise = SAMPLE_TEXTURE2D(_DissolveMap, sampler_BaseMap, IN.uvNoise);
                half alpha = noise.r + _Proc;
                half clipAlpha = 1 - alpha - 0.05;
                clip(clipAlpha * step(0.01, _Proc));
                half3 finalColor = baseColor.rgb * _BaseColor.rgb;
                //内层颜色
                half edgeFactor = (1 - smoothstep(0, _InnerWidth, clipAlpha)) * step(0.001, _Proc);
                finalColor = lerp(finalColor, _DissolveInnerColor.rgb, edgeFactor);
                //外层颜色
                edgeFactor = (1 - smoothstep(0, _EdgeWidth, clipAlpha)) * step(0.001, _Proc);
                finalColor = lerp(finalColor, _DissolveEdgeColor.rgb, edgeFactor);
                //透明度
                alpha = lerp(1, smoothstep(0, _AlphaWidth, clipAlpha), step(0.001, _Proc));
                return half4(finalColor, baseColor.a * alpha);
            }
            
            ENDHLSL
        }
    }
    
    //FallBack是一个错误Pass，会将材质绘制为紫色
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}