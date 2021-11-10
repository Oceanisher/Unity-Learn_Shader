// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

//Chapter06_BlinnPhong模型中的逐像素高光计算
Shader "Unity Shaders Book/Chapter06-SpecularBlinnPhong"
{
    Properties
    {
        _Diffuse ("Diffuse Color", Color) = (1,1,1,1)
        //控制高光反射颜色
        _Specular ("Specular Color", Color) = (1,1,1,1)
        //控制高光区域大小
        _Gloss ("Gloss", Range(8.0, 256)) = 20
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
            fixed4 _Specular;
            float _Gloss;

            //获取顶点、法线
            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            //输出裁剪空间顶点坐标、法线、位置
            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
            };
            
            v2f vert (a2v v)
            {
                v2f o;
                //顶点的裁剪空间坐标
                o.pos = UnityObjectToClipPos(v.vertex);
                //顶点的世界坐标法线
                o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);
                //顶点的世界坐标位置
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                
                //按照光照模型，要计算漫反射，需要4个入参：入射光线的颜色+强度+方向、材质的漫反射系数、表面法线
                
                //获得环境光
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
                //unity_WorldToObject 将顶点/法线从世界空间转换到模型空间，这里放在后面，因为对于法线来说是通过逆矩阵来计算世界空间的，那么就是反向转换、转换到世界空间
                //mul矩阵乘法，mul(M,v)：矩阵乘向量；mul(v,M)：向量乘矩阵
                fixed3 worldNormal = normalize(i.worldNormal);
                //_WorldSpaceLightPos0获取唯一光源；normalize()归一化
                fixed3 worldLight = normalize(_WorldSpaceLightPos0.xyz);
                //按照公式计算漫反射。saturate()把参数截取在[0,1]范围之内；
                //_LightColor0.rgb：光照强度；_Diffuse.rgb：漫反射系数；
                fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldNormal, worldLight));


                //按照光照模型，要计算高光，需要4个入参：入射光线的颜色+强度、材质的漫反射系数、视角方向、反射方向
                //计算视角方向。摄像机位置 - 物体位置 = 视角方向
                fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
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
    Fallback "Diffuse"
}
