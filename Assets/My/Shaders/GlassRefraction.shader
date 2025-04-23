//玻璃折射，使用渲染纹理
//反射+折射
Shader "My/GlassRefraction"
{
    Properties
    {
        _MainTex("主纹理", 2D) = "white" {}
        _BumpTex("法线纹理", 2D) = "white" {}
        _CubeMap("折射天空盒子", Cube) = "_Skybox" {}
        _Distortion("折射扭曲程度", Range(0, 100)) = 10
        _RefractionAmount("折射程度", Range(0, 1)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "LightMode"="ForwardBase" "Queue"="Transparent"}
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"

            //变量对应
            sampler2D _MainTex;
            //获取_MainTex缩放平移值
            float4 _MainTex_ST;
            sampler2D _BumpTex;
            //获取_MainTex缩放平移值
            float4 _BumpTex_ST;
            samplerCUBE _CubeMap;
            float _Distortion;
            float _RefractionAmount;

            //输入：顶点、法线、切线、纹理坐标
            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 texcoord : TEXCOORD0;
            };

            //输出：顶点（裁剪空间）、UV、光照方向（切线空间）、观察方向（切线空间）
            struct v2f
            {
                float4 pos : SV_POSITION;
                //通常主纹理、法线纹理的坐标是一样的，所以只用float2就可以了。但是这里还是先分开，xy存储主纹理、zw存储法线纹理
                float4 uv : TEXCOORD0;
                float3 lightDir : TEXCOORD1;
                float3 viewDir : TEXCOORD2;
            };

            //把坐标都转换到切线空间，并传递到片元着色器
            v2f vert (appdata v)
            {
                v2f o;
                //计算裁剪空间的顶点
                o.pos = UnityObjectToClipPos(v.vertex);
                //计算UV
                o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.uv.zw = TRANSFORM_TEX(v.texcoord, _BumpTex);
                
                //计算切线空间矩阵
                //第一种：自己计算。计算副法线，使用切线的w方向确定副法线方向；然后按照切线、副法线、法线顺序构建切线空间矩阵
                //float3 binormal = cross(normalize(v.normal), normalize(v.tangent)) * v.tangent.w;
                //float3x3 rotation = float3x3(v.tangent.xyz, binormal, v.normal);
                //第二种：使用官方宏
                TANGENT_SPACE_ROTATION;

                //光照方向转换到切线空间
                o.lightDir = normalize(mul(rotation, ObjSpaceLightDir(v.vertex)).xyz);
                //观察方向转换到切线空间
                o.viewDir = normalize(mul(rotation, ObjSpaceViewDir(v.vertex)).xyz);
                return o;
            }

            //使用的坐标都是切线空间坐标
            fixed4 frag (v2f i) : SV_Target
            {
                //计算法线纹理。由于纹理存储的数值没有负数，是个像素值，而法线的范围是[-1,1]，所以得把像素值转换一下。
                //而且纹理经过了压缩，所以得解压一下。可以自己解压、也可以通过unity的函数。
                fixed4 packedNormal = tex2D(_BumpTex, i.uv.zw);
                //计算切线空间下的法线
                fixed3 tangentNormal = UnpackNormal(packedNormal);
                //法线缩放
                tangentNormal.xy *= _BumpScale;
                //法线的z保证是正数
                tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));

                //反射率
                float3 albedo = tex2D(_MainTex, i.uv.xy) * _Color;
                //环境光
                float3 ambient = UNITY_LIGHTMODEL_AMBIENT * albedo;
                //漫反射
                float3 diffuse = _LightColor0 * albedo * (0.5 * max(0, dot(tangentNormal, i.lightDir)) + 0.5);
                //高光
                float3 halfDir = normalize(i.lightDir + i.viewDir);
                float3 specular = _LightColor0 * _Specular.rgb * pow(max(0, dot(tangentNormal, halfDir)), _Gloss);

                //总和
                return fixed4(ambient + diffuse + specular, 1.0);
            }
            ENDCG
        }
    }

    Fallback "Specular"
}
