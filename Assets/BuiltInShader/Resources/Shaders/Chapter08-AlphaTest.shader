//Chapter08_透明度测试
Shader "Unity Shaders Book/Chapter08-Alpha Test"
{
    Properties
    {
        //基础颜色
        _Color("Color Tint", Color) = (1,1,1,1)
        //纹理。"white"是内置白色纹理
        _MainTex("Texture", 2D) = "white" {}
        //透明测试的判断条件
        _Cutoff("Alpha Cutoff", Range(0,1)) = 0.5
    }
    SubShader
    {
        //Queue表明该渲染放到AlphaTest队列中，RenderType表明放入提前定义的这个组中，IgnoreProjector表明不会受到投影器影响
        //通常使用了透明度测试的都应该写这3个
        Tags {"Queue" = "AlphaTest" "IgnoreProjector" = "True" "RenderType" = "TransparentCutoff"}
        Pass
        {
            //定义该pass在unity光照流水线中的角色
            Tags {"LightMode"="ForwardBase"}
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Lighting.cginc"

            fixed4 _Color;
            //主纹理
            sampler2D _MainTex;
            //纹理的缩放（Scale）和平移（Translation），所以后缀加_ST，是Unity规定的标准写法，不是随意起名的
            //其中_MainTex_ST.xy代表缩放值，_MainTex_ST.zw代表偏移值
            float4 _MainTex_ST;
            //透明度判断条件
            fixed _Cutoff;

            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                //纹理信息
                float4 texcoord : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float2 uv : TEXCOORD2;
            };
            
            v2f vert (a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));

                //采样纹理
                fixed4 texColor = tex2D(_MainTex, i.uv);
                //对纹理进行透明度测试，如果减的结果小于0，那么就会放弃该片元的颜色渲染
                clip(texColor.a - _Cutoff);
                
                //反射率。tex2D()对纹理进行采样
                fixed3 albedo = texColor.rgb * _Color.rgb;
                
                //按照光照模型，要计算漫反射，需要4个入参：入射光线的颜色+强度+方向、材质的漫反射系数、表面法线
                
                //获得环境光，根据反射率获得
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
                
                //按照公式计算漫反射。saturate()把参数截取在[0,1]范围之内；
                //_LightColor0.rgb：光照强度；_Diffuse.rgb：漫反射系数；
                fixed3 diffuse = _LightColor0.rgb * albedo * max(0,dot(worldNormal, worldLightDir));

                //环境光+漫反射
                fixed3 color = ambient + diffuse;
                
                return fixed4(color, 1);
            }
            ENDCG
        }
    }
    
    Fallback "Legacy Shaders/VertexLit"
}
