// This shader fills the mesh shape with a color predefined in the code.
Shader "Example/URPUnlitShaderBasic"
{
    // The properties block of the Unity shader. In this example this block is empty
    // because the output color is predefined in the fragment shader code.
    Properties
    {
        //[MainColor]是一个主颜色注解，Unity使用这个来作为材质的主要颜色。由于兼容性的原因，_Color是一个保留变量名，如果使用_Color作为变量名，那么即使不使用MainColor注解，Unity也会把它作为主颜色使用
        [MainColor] _BaseColor("Base Color", Color) = (1,1,1,1)
        //[MainTexture]是一个主纹理注解，Unity使用这个来作为材质的主要纹理。由于兼容性的原因，_MainTex是一个保留变量名，如果使用_MainTex作为变量名，那么即使不使用MainTexture注解，Unity也会把它作为主纹理使用
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
    }

    // The SubShader block containing the Shader code.
    SubShader
    {
        // SubShader Tags define when and under which conditions a SubShader block or
        // a pass is executed.
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        
        Pass
        {
            // The HLSL code block. Unity SRP uses the HLSL language.
            HLSLPROGRAM
            // This line defines the name of the vertex shader.
            #pragma vertex vert
            // This line defines the name of the fragment shader.
            #pragma fragment frag

            // The Core.hlsl file contains definitions of frequently used HLSL
            // macros and functions, and also contains #include references to other
            // HLSL files (for example, Common.hlsl, SpaceTransforms.hlsl, etc.).
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // The structure definition defines which variables it contains.
            // This example uses the Attributes structure as an input structure in
            // the vertex shader.
            struct Attributes
            {
                // The positionOS variable contains the vertex positions in object
                // space.
                float4 positionOS   : POSITION;
                float2 uv : TEXCOORD0;
                half3 normal : NORMAL;
            };

            struct Varyings
            {
                //裁剪空间坐标
                // The positions in this struct must have the SV_POSITION semantic.
                float4 positionHCS  : SV_POSITION;
                float2 uv : TEXCOORD0;
                half3 normal : TEXCOORD1;
            };

            //宏定义，声明该纹理对象，相当于 Texture2D _MainTexture
            TEXTURE2D(_BaseMap);
            //宏定义，声明一个采样器状态，定义纹理的过滤、寻址模式等，相当于 SamplerState sampler_MainTexture;
            SAMPLER(sampler_BaseMap);
            //为了兼容SRP Batcher，所有Properties中的变量需要在CBUFFER中声明、并且名称为UnityPerMaterial
            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                //上面已经通过TEXTURE2D定义了_BaseMap了，这里就不用再重新定义了
                //_BaseMap_ST存储的是在Inspector中看到的纹理的平铺、偏移，xy存储平铺Tiling，zw存储偏移Offset；TRANSFORM_TEX宏会使用
                float4 _BaseMap_ST;
            CBUFFER_END

            // The vertex shader definition with properties defined in the Varyings
            // structure. The type of the vert function must match the type (struct)
            // that it returns.
            Varyings vert(Attributes IN)
            {
                // Declaring the output object (OUT) with the Varyings struct.
                Varyings OUT;
                // The TransformObjectToHClip function transforms vertex positions
                // from object space to homogenous clip space.
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                //TRANSFORM_TEX宏使用了纹理的_ST进行计算
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.normal = TransformObjectToWorldNormal(IN.normal);
                // Returning the output.
                return OUT;
            }

            // The fragment shader definition.
            half4 frag(Varyings IN) : SV_Target
            {
                // Defining the color variable and returning it.
                // half4 customColor = half4(0.5, 0, 0, 1);
                // return customColor;
                
                // return _BaseColor;

                //对纹理进行采样，获取颜色
                // half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
                // return color;

                //法线每个分量范围是-1~1，按照下面的算法，就能转到0~1，符合颜色的范围
                //直接输出法线颜色，把负值法线转换为正值；否则会有黑色的地方，因为有负值
                half4 color = 0;
                color.rgb = IN.normal * 0.5 + 0.5;
                return color;
            }
            ENDHLSL
        }
    }
}
