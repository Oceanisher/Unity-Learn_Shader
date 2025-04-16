//反射纹理，多光源，加入其他光源的法线方向考虑
//加入阴影。由于Fallback中的shader已经包含了阴影Caster的pass，所以这里只需要实现读取阴影纹理并写入颜色即可。
Shader "My/Reflection"
{
    Properties
    {
        _Color("颜色", Color) = (1.0, 1.0, 1.0, 1.0)
        _ReflectionColor("反射颜色", Color) = (1.0, 1.0, 1.0, 1.0)
        _ReflectionAmount("反射程度", Range(0, 1)) = 1.0
        _CubeMap("反射纹理", Cube) = "_Skybox" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        //基础Pass，渲染平行光
        Pass
        {
            //前向Base Pass
            Tags {"LightMode"="ForwardBase"}
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"
            #include "AutoLight.cginc"

            float4 _Color;
            float4 _ReflectionColor;
            float _ReflectionAmount;
            samplerCUBE _CubeMap;

            //输入：顶点、法线、切线、纹理坐标
            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            //输出：顶点（裁剪空间）、UV、光照方向（切线空间）、观察方向（切线空间）
            struct v2f
            {
                float4 pos : SV_POSITION;
                float4 posWorld : TEXCOORD0;
                float3 normalWorld : TEXCOORD1;
                float3 lightDir : TEXCOORD2;
                float3 viewDir : TEXCOORD3;
                float3 reflectDir : TEXCOORD4;
                //阴影纹理
                SHADOW_COORDS(5)
            };

            //把坐标都转换到切线空间，并传递到片元着色器
            v2f vert (appdata v)
            {
                v2f o;
                //计算裁剪空间的顶点
                o.pos = UnityObjectToClipPos(v.vertex);
                o.posWorld = mul(UNITY_MATRIX_M, v.vertex);
                o.normalWorld = UnityObjectToWorldNormal(v.normal);
                o.lightDir = UnityObjectToWorldDir(ObjSpaceLightDir(v.vertex));
                o.viewDir = UnityObjectToWorldDir(ObjSpaceViewDir(v.vertex));
                //计算反射光线
                o.reflectDir = reflect(-o.viewDir, o.normalWorld);
                //计算阴影纹理
                TRANSFER_SHADOW(o)
                return o;
            }

            //使用的坐标都是切线空间坐标
            fixed4 frag (v2f i) : SV_Target
            {
                float3 worldLightDir = normalize(i.lightDir);
                float3 worldViewDir = normalize(i.viewDir);
                float3 worldReflectDir = normalize(i.reflectDir);
                float3 worldNormal = normalize(i.normalWorld);
                
                //反射盒子采样
                float3 reflectColor = texCUBE(_CubeMap, worldReflectDir).rgb * _ReflectionColor * _ReflectionAmount;
                
                //阴影
                fixed shadow = SHADOW_ATTENUATION(i);
                //环境光
                float3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
                //漫反射
                float3 diffuse = _LightColor0 * _Color * reflectColor * (0.5 * max(0, dot(worldNormal, worldLightDir)) + 0.5);

                //总和，环境光不需要乘以阴影
                return fixed4(ambient + diffuse * shadow, 1.0);
            }
            ENDCG
        }
    }

    //如果自己不写阴影投射Pass，会在这个默认的里面找
    Fallback "Diffuse"
}
