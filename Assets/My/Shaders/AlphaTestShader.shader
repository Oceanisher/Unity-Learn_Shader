//AlphaTest裁剪，双面渲染
//关闭背面剔除
Shader "My/AlphaTestShader"
{
    Properties
    {
        _MainTex ("主纹理", 2D) = "white" {}
        _Color("颜色", Color) = (1, 1, 1, 1)
        _Cutoff("Alpha裁剪阈值", Range(0, 1)) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="TransparentCutout" "IgnoreProjector"="True" "Queue"="AlphaTest" "LightMode"="ForwardBase" }
        LOD 100
        Cull Off
        
        Pass
        {
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
            float _Cutoff;

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
                //Alpha裁剪
                clip(texColor.a - _Cutoff);
                
                //反射率
                float3 albedo = texColor.rgb * _Color.rgb;
                //环境光
                float3 ambient = UNITY_LIGHTMODEL_AMBIENT * albedo;
                //漫反射
                float3 diffuse = _LightColor0 * albedo * (0.5 * max(0, dot(i.worldNormal, worldLightDir)) + 0.5);

                //总和
                return fixed4(ambient + diffuse, 1.0);
            }
            ENDCG
        }
    }
    Fallback "Legacy Shaders/VertexLit"
}
