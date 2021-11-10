// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

//Chapter06_标准光照模型中的逐像素漫反射计算
Shader "Unity Shaders Book/Chapter06-DiffusePixelLevel"
{
    Properties
    {
        _Diffuse ("Diffuse Color", Color) = (1,1,1,1)
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

            //包含UNITY的头文件，为了使用_LightColor0等变量
            #include "Lighting.cginc"

            fixed4 _Diffuse;

            //获取顶点、法线
            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            //输出裁剪空间顶点坐标、法线
            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
            };
            
            v2f vert (a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                //获取顶点法线的世界空间坐标
                o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                
                //按照光照模型，要计算漫反射，需要4个入参：入射光线的颜色+强度+方向、材质的漫反射系数、表面法线
                
                //获得环境光
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
                //顶点的法线
                fixed3 worldNormal = normalize(i.worldNormal);
                //_WorldSpaceLightPos0获取唯一光源；normalize()归一化
                fixed3 worldLight = normalize(_WorldSpaceLightPos0.xyz);
                //按照公式计算漫反射。saturate()把参数截取在[0,1]范围之内；
                //_LightColor0.rgb：光照强度；_Diffuse.rgb：漫反射系数；
                fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldNormal, worldLight));
                //环境光+漫反射
                fixed3 color = ambient + diffuse;
                return fixed4(color,1.0);
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
}
