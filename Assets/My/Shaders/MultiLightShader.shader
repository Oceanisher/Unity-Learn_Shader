//多光源，加入其他光源的法线方向考虑
//加入阴影。由于Fallback中的shader已经包含了阴影Caster的pass，所以这里只需要实现读取阴影纹理并写入颜色即可。
Shader "My/MultiLight"
{
    Properties
    {
        _Color("颜色", Color) = (1.0, 1.0, 1.0, 1.0)
        _MainTex("主纹理", 2D) = "white" {}
        _BumpTex("法线纹理", 2D) = "white" {}
        _BumpScale("凹凸程度", float) = 1.0
        _Specular("高光颜色", Color) = (1.0, 1.0, 1.0, 1.0)
        _Gloss("高光锐度", Range(8.0, 256)) = 20
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
            #pragma multi_compile_fwdbase
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"
            #include "AutoLight.cginc"

            float4 _Color;
            //变量对应
            sampler2D _MainTex;
            //获取_MainTex缩放平移值
            float4 _MainTex_ST;
            sampler2D _BumpTex;
            //获取_MainTex缩放平移值
            float4 _BumpTex_ST;
            float _BumpScale;
            float4 _Specular;
            float _Gloss;

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
                //阴影纹理
                SHADOW_COORDS(3)
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
                //计算阴影纹理
                TRANSFER_SHADOW(o)
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

                //阴影
                fixed shadow = SHADOW_ATTENUATION(i);
                //反射率
                float3 albedo = tex2D(_MainTex, i.uv.xy) * _Color;
                //环境光
                float3 ambient = UNITY_LIGHTMODEL_AMBIENT * albedo;
                //漫反射
                float3 diffuse = _LightColor0.rgb * albedo * (0.5 * max(0, dot(tangentNormal, i.lightDir)) + 0.5);
                //高光
                float3 halfDir = normalize(i.lightDir + i.viewDir);
                float3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(tangentNormal, halfDir)), _Gloss);

                //总和，环境光不需要乘以阴影
                return fixed4(ambient + (diffuse + specular) * shadow, 1.0);
            }
            ENDCG
        }

        //附加Pass，渲染其他类型的光源
        //不再关注环境光
        Pass
        {
            //前向Additional Pass
            Tags {"LightMode"="ForwardAdd"}
            //附加光源的颜色直接叠加到Base上
            Blend One One
            
            CGPROGRAM
            #pragma multi_compile_fwdadd
            //开启其他光源阴影
            // #pragma multi_compile_fwdadd_fullshadows
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"
            #include "AutoLight.cginc"

            float4 _Color;
            //变量对应
            sampler2D _MainTex;
            //获取_MainTex缩放平移值
            float4 _MainTex_ST;
            sampler2D _BumpTex;
            //获取_MainTex缩放平移值
            float4 _BumpTex_ST;
            float _BumpScale;
            float4 _Specular;
            float _Gloss;

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
                float3 posWorld : TEXCOORD3;
                //阴影纹理
                SHADOW_COORDS(4)
            };

            //把坐标都转换到切线空间，并传递到片元着色器
            v2f vert (appdata v)
            {
                v2f o;
                //计算裁剪空间的顶点
                o.pos = UnityObjectToClipPos(v.vertex);
                //世界空间顶点
                o.posWorld = mul(UNITY_MATRIX_M, v.vertex).xyz;
                //计算UV
                o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.uv.zw = TRANSFORM_TEX(v.texcoord, _BumpTex);
                
                //计算切线空间矩阵
                //第一种：自己计算。计算副法线，使用切线的w方向确定副法线方向；然后按照切线、副法线、法线顺序构建切线空间矩阵
                //float3 binormal = cross(normalize(v.normal), normalize(v.tangent)) * v.tangent.w;
                //float3x3 rotation = float3x3(v.tangent.xyz, binormal, v.normal);
                //第二种：使用官方宏
                TANGENT_SPACE_ROTATION;
                
                //光照方向转换到切线空间，ObjSpaceLightDir内部已经考虑了不同类型的光源问题了
                o.lightDir = normalize(mul(rotation, ObjSpaceLightDir(v.vertex)).xyz);
                //观察方向转换到切线空间
                o.viewDir = normalize(mul(rotation, ObjSpaceViewDir(v.vertex)).xyz);
                //计算阴影纹理
                TRANSFER_SHADOW(o)
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

                //计算光源的强度
                #ifdef USING_DIRECTIONAL_LIGHT
                fixed atten = 1.0;
                #else
                    //非平行光还要看法线和光源的方向，如果夹角超过90，那么不受影响
                    #if defined (POINT)
                    float3 lightCoord = mul(unity_WorldToLight, float4(i.posWorld, 1)).xyz;
                    //点乘的结果是点到光源距离的平方，避免开方。dot().rr的意思是，用点乘的值构建一个新的向量(r,r)；UNITY_ATTEN_CHANNEL表示使用衰减通道
                    fixed atten = (dot(i.lightDir, tangentNormal) > 0) * tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
                    #elif defined (SPOT)
                    float4 lightCoord = mul(unity_WorldToLight, float4(i.posWorld, 1));
                    fixed atten = (dot(i.lightDir, tangentNormal) > 0) * (lightCoord.z > 0) * tex2D(_LightTexture0, lightCoord.xy / lightCoord.w + 0.5).w * tex2D(_LightTextureB0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
                    #else
                    fixed atten = 1.0;
                    #endif
                #endif

                //阴影
                fixed shadow = SHADOW_ATTENUATION(i);

                //也可以用内置函数直接同时计算阴影、光照衰减
                //第一个参数不用自己定义，这个函数里会定义出来，也叫atten；第二个参数是v2f，第三个参数是世界空间顶点
                // UNITY_LIGHT_ATTENUATION(atten, i, i.posWorld);
                
                //反射率
                float3 albedo = tex2D(_MainTex, i.uv.xy) * _Color.rgb;
                //漫反射
                float3 diffuse = _LightColor0 * albedo * (0.5 * max(0, dot(tangentNormal, i.lightDir)) + 0.5);
                //高光
                float3 halfDir = normalize(i.lightDir + i.viewDir);
                float3 specular = _LightColor0 * _Specular.rgb * pow(max(0, dot(tangentNormal, halfDir)), _Gloss);

                //总和
                return fixed4((diffuse + specular) * atten * shadow, 1.0);
            }
            ENDCG
        }
    }

    //如果自己不写阴影投射Pass，会在这个默认的里面找
    Fallback "Diffuse"
}
