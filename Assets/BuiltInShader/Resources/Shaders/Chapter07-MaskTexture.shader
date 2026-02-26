//Chapter07_遮罩纹理
Shader "Unity Shaders Book/Chapter07-MaskTexture"
{
    Properties
    {
        //基础颜色
        _Color("Color Tint", Color) = (1,1,1,1)
        //纹理。"white"是内置白色纹理
        _MainTex ("Texture", 2D) = "white" {}
        //法线纹理
        _BumpMap ("Normal Map", 2D) = "bump" {}
        //控制凹凸程度
        _BumpScale ("Bump Scale", Float) = 1.0
        //控制高光反射颜色
        _Specular("Specular", Color) = (1,1,1,1)
        //遮罩纹理
        _SpecularMask("Specular Mask", 2D) = "white" {}
        //控制遮罩影响度
        _SpecularScale("Specular Scale", Float) = 1.0
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
            //主纹理
            sampler2D _MainTex;
            //纹理的缩放（Scale）和平移（Translation），所以后缀加_ST，是Unity规定的标准写法，不是随意起名的
            //其中_MainTex_ST.xy代表缩放值，_MainTex_ST.zw代表偏移值
            float4 _MainTex_ST;
            //法线纹理
            sampler2D _BumpMap;
            float _BumpScale;
            sampler2D _SpecularMask;
            float _SpecularScale;
            fixed4 _Specular;
            float _Gloss;

            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                //切线空间下的顶点切线
                float4 tangent : TANGENT;
                //纹理信息
                float4 texcoord : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float4 uv : TEXCOORD0;
                float3 lightDir : TEXCOORD1;
                float3 viewDir : TEXCOORD2;
            };
            
            v2f vert (a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                //UV的xy存储主纹理坐标
                o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;

                TANGENT_SPACE_ROTATION;

                //将光线方向从模型空间转换到切线空间
                o.lightDir = mul(rotation, ObjSpaceLightDir(v.vertex)).xyz;
                //将视角方向从模型空间转换到切线空间
                o.viewDir = mul(rotation, ObjSpaceViewDir(v.vertex)).xyz;
                
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed3 tangentLightDir = normalize(i.lightDir);
                fixed3 tangentViewDir = normalize(i.viewDir);

                //tex2D进行采样，所谓采样是指在纹理中找到该顶点所对应的纹理
                fixed4 packedNormal = tex2D(_BumpMap, i.uv.zw);
                fixed3 tangentNormal;
                //如果法线纹理在UNITY里没有存储为Normal Map类型，那么就需要自己计算
                //tangentNormal.xy = (packedNormal.xy * 2 - 1) * _BumpScale;
                //tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
                //如果法线纹理在UNITY里存储为Normal Map类型，那么可以直接调用UnpackNormal()函数来计算正确的法线方向
                tangentNormal = UnpackNormal(packedNormal);
                tangentNormal.xy *= _BumpScale;
                tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));

                //反射率。tex2D()对纹理进行采样
                fixed3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;
                
                //按照光照模型，要计算漫反射，需要4个入参：入射光线的颜色+强度+方向、材质的漫反射系数、表面法线
                
                //获得环境光，根据反射率获得
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
                
                //按照公式计算漫反射。saturate()把参数截取在[0,1]范围之内；
                //_LightColor0.rgb：光照强度；_Diffuse.rgb：漫反射系数；
                fixed3 diffuse = _LightColor0.rgb * albedo * saturate(dot(tangentNormal, tangentLightDir));


                //按照光照模型，要计算高光，需要4个入参：入射光线的颜色+强度、材质的漫反射系数、视角方向、反射方向
                //视角、光线方向相加，然后归一化
                fixed3 halfDir = normalize(tangentLightDir + tangentViewDir);
                //计算遮罩纹理，选择r分量作为遮罩，计算掩码
                fixed specularMask = tex2D(_SpecularMask, i.uv).r * _SpecularScale;
                //按照高光公式，计算高光。pow(x,y)，计算x的y次方。
                fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(tangentNormal, halfDir)), _Gloss)
                    * specularMask;

                //高光+环境光+漫反射
                fixed3 color = specular + ambient + diffuse;
                
                return fixed4(color, 1);
            }
            ENDCG
        }
    }
    
    Fallback "Specular"
}
