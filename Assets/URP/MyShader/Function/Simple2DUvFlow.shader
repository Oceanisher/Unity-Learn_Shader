//简单2D的UV流动
Shader "Custom/Simple2DUvFlow"
{
    Properties
    {
        [MainColor] _BaseColor ("Base Color(主颜色)", Color) = (1,1,1,1)
        [MainTexture] _BaseMap ("Base Map(纹理)", 2D) = "white" {}
        _USpeed ("U Speed(水平滚动速度)", float) = 0
        _VSpeed ("V Speed(竖直滚动速度)", float) = 0
        //其实可以直接使用Base Map的Tiling功能
        _UTile("U Tile(水平平铺数量)", float) = 1
        _VTile("V Tile(竖直平铺数量)", float) = 1
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

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
                float _USpeed;
                float _VSpeed;
                float _UTile;
                float _VTile;
            CBUFFER_END

            //顶点着色器
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            //片元着色器
            half4 frag(Varyings IN) : SV_Target
            {
                //不要用 % 1 手动取模，让纹理 Wrap Mode = Repeat 自动处理重复
                //手动取模会在 tile 边界处产生 UV 突变，导致 GPU 的 mipmap 选择错误从而闪烁
                //纹理在 Unity 中设置 Wrap Mode = Repeat 后，GPU 硬件会在纹理采样器层面处理 UV 的重复，这个过程不会影响 ddx/ddy 的计算，所以 mipmap级别选择正常，tile 边界不会闪烁
                float2 flowUV = float2(
                    IN.uv.x * _UTile + _Time.y * _USpeed,
                    IN.uv.y * _VTile + _Time.y * _VSpeed
                );
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, flowUV);
                half3 finalColor = baseColor.rgb * _BaseColor.rgb;
                return half4(finalColor, baseColor.a);
            }
            
            ENDHLSL
        }
    }
    
    //FallBack是一个错误Pass，会将材质绘制为紫色
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}