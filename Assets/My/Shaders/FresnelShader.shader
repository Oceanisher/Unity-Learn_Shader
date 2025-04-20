//菲涅尔反射
//加入阴影。由于Fallback中的shader已经包含了阴影Caster的pass，所以这里只需要实现读取阴影纹理并写入颜色即可。
Shader "My/Fresnel"
{
    Properties
    {
        _Color("颜色", Color) = (1.0, 1.0, 1.0, 1.0)
        _FresnelScale("菲涅尔缩放", Range(0, 1)) = 1
        _CubeMap("立方体盒", Cube) = "_Skybox" {}
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
            float _FresnelScale;
            samplerCUBE _CubeMap;

            //输入：顶点、法线
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
                float3 reflectWorld : TEXCOORD4;
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
                o.lightDir = UnityWorldSpaceLightDir(o.posWorld);
                o.viewDir = UnityWorldSpaceViewDir(o.posWorld);
                o.reflectWorld = reflect(-o.viewDir, o.normalWorld);
                //计算阴影纹理
                TRANSFER_SHADOW(o)
                return o;
            }

            //使用的坐标都是切线空间坐标
            fixed4 frag (v2f i) : SV_Target
            {
                float3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.posWorld));
                float3 worldNormal = normalize(i.normalWorld);
                float3 worldViewDir = normalize(i.viewDir);

                //反射盒子采样
                float3 reflectColor = texCUBE(_CubeMap, i.reflectWorld).rgb;
                //计算菲涅尔反射
                fixed fresnel = _FresnelScale + (1 - _FresnelScale) * pow(1 - dot(worldViewDir, worldNormal), 5);
                
                //环境光
                float3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
                UNITY_LIGHT_ATTENUATION(atten, i, i.posWorld);
                //漫反射
                float3 diffuse = _LightColor0.rgb * _Color.rgb * (0.5 * max(0, dot(worldNormal, worldLightDir)) + 0.5);
                
                return fixed4(ambient + lerp(diffuse, reflectColor, saturate(fresnel)) * atten, 1.0);
            }
            ENDCG
        }
    }

    //如果自己不写阴影投射Pass，会在这个默认的里面找
    Fallback "Diffuse"
}
