//透明混合，写入深度值，双面渲染
//先一个Pass写入深度值，再一个Pass绘制背面，再一个Pass绘制正面
Shader "My/AlphaBlendWithZWrite"
{
    Properties
    {
        _MainTex ("主纹理", 2D) = "white" {}
        _Color("颜色", Color) = (1, 1, 1, 1)
        _Cutoff("Alpha裁剪阈值", Range(0, 1)) = 0.5
        _AlphaScale("透明度", Range(0, 1)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "IgnoreProjector"="True" "Queue"="Transparent" "LightMode"="ForwardBase" }
        LOD 100
        
        //用一个单独的pass来写入深度值
        Pass
        {
            ZWrite On
            ColorMask 0
        }
        
        //绘制背面
        Pass
        {
            Cull Front
            ZWrite Off
            //正常透明叠加
            Blend SrcAlpha OneMinusSrcAlpha
//            Blend DstColor Zero
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float2 uv : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _Color;
            float _AlphaScale;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(UNITY_MATRIX_M, v.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //世界空间下的光线
                float3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                //纹理采样
                fixed4 texColor = tex2D(_MainTex, i.uv);
                
                //反射率
                float3 albedo = texColor.rgb * _Color.rgb;
                //环境光
                float3 ambient = UNITY_LIGHTMODEL_AMBIENT * albedo;
                //漫反射
                float3 diffuse = _LightColor0 * albedo * (0.5 * max(0, dot(i.worldNormal, worldLightDir)) + 0.5);

                //总和
                return fixed4(ambient + diffuse, texColor.a * _AlphaScale);
            }
            ENDCG
        }

        //绘制正面
        Pass
        {
            Cull Back
            ZWrite Off
            //正常透明叠加
            Blend SrcAlpha OneMinusSrcAlpha
//            Blend DstColor Zero
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float2 uv : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _Color;
            float _AlphaScale;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(UNITY_MATRIX_M, v.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //世界空间下的光线
                float3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                //纹理采样
                fixed4 texColor = tex2D(_MainTex, i.uv);
                
                //反射率
                float3 albedo = texColor.rgb * _Color.rgb;
                //环境光
                float3 ambient = UNITY_LIGHTMODEL_AMBIENT * albedo;
                //漫反射
                float3 diffuse = _LightColor0 * albedo * (0.5 * max(0, dot(i.worldNormal, worldLightDir)) + 0.5);

                //总和
                return fixed4(ambient + diffuse, texColor.a * _AlphaScale);
            }
            ENDCG
        }
    }
    Fallback "Legacy Shaders/Diffuse"
}
