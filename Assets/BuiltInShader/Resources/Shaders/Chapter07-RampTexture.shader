//Chapter07_渐变纹理
Shader "Unity Shaders Book/Chapter07-RampTexture"
{
    Properties
    {
        //基础颜色
        _Color("Color Tint", Color) = (1,1,1,1)
        //纹理。"white"是内置白色纹理
        _RampTex ("Ramp Tex", 2D) = "white" {}
        //控制高光反射颜色
        _Specular("Specular", Color) = (1,1,1,1)
        //控制高光区域大小
        _Gloss("Gloss", Range(8.0, 256)) = 20
    }
    SubShader
    {
        Pass
        {
            //定义该pass在unity光照流水线中的角色
            Tags {"LightMode"="ForwardBase"}
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Lighting.cginc"

            fixed4 _Color;
            sampler2D _RampTex;
            //纹理的缩放（Scale）和平移（Translation），所以后缀加_ST，是Unity规定的标准写法，不是随意起名的
            //其中_MainTex_ST.xy代表缩放值，_MainTex_ST.zw代表偏移值
            float4 _RampTex_ST;
            fixed4 _Specular;
            float _Gloss;

            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
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
                //先对纹理进行缩放，再进行平移
                //利用TRANSFORM_TEX内置函数来计算平铺、便宜后的纹理坐标
                o.uv = TRANSFORM_TEX(v.texcoord, _RampTex);
                //Unity提供了函数完成这个，可以用下面这个函数
                //o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //unity_WorldToObject 将顶点/法线从世界空间转换到模型空间，这里放在后面，因为对于法线来说是通过逆矩阵来计算世界空间的，那么就是反向转换、转换到世界空间
                //mul矩阵乘法，mul(M,v)：矩阵乘向量；mul(v,M)：向量乘矩阵
                fixed3 worldNormal = normalize(i.worldNormal);
                //_WorldSpaceLightPos0获取唯一光源；normalize()归一化
                fixed3 worldLight = normalize(UnityWorldSpaceLightDir(i.worldPos));

                //获得环境光，根据反射率获得
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
                
                //按照光照模型，要计算漫反射，需要4个入参：入射光线的颜色+强度+方向、材质的漫反射系数、表面法线
                fixed halfLambert = 0.5 * dot(worldNormal, worldLight) + 0.5;
                fixed3 diffuseColor = tex2D(_RampTex, fixed2(halfLambert, halfLambert)).rgb * _Color.rgb;
                
                //按照公式计算漫反射。saturate()把参数截取在[0,1]范围之内；
                //_LightColor0.rgb：光照强度；_Diffuse.rgb：漫反射系数；
                fixed3 diffuse = _LightColor0.rgb * diffuseColor;


                //按照光照模型，要计算高光，需要4个入参：入射光线的颜色+强度、材质的漫反射系数、视角方向、反射方向
                //计算视角方向。摄像机位置 - 物体位置 = 视角方向
                fixed3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                //视角、光线方向相加，然后归一化
                fixed3 halfDir = normalize(worldLight + viewDir);
                //按照高光公式，计算高光。pow(x,y)，计算x的y次方。
                fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(worldNormal, halfDir)), _Gloss);

                //高光+环境光+漫反射
                fixed3 color = specular + ambient + diffuse;
                
                return fixed4(color, 1);
            }
            ENDCG
        }
    }
    
    Fallback "Specular"
}
