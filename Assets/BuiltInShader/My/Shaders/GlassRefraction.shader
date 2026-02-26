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
        Tags { "RenderType"="Opaque" "LightMode"="ForwardBase" "Queue"="Transparent"}
        LOD 100
        
        GrabPass {"_RefractionTex"}

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
            sampler2D _RefractionTex;
            float4 _RefractionTex_TexelSize;

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
                float4 srcPos : TEXCOORD0;
                float4 uv : TEXCOORD1;
                //w存放顶点的世界坐标
                float4 TtoW0 : TEXCOORD2;
                float4 TtoW1 : TEXCOORD3;
                float4 TtoW2 : TEXCOORD4;
            };

            //把坐标都转换到切线空间，并传递到片元着色器
            v2f vert (appdata v)
            {
                v2f o;
                //计算裁剪空间的顶点
                o.pos = UnityObjectToClipPos(v.vertex);
                o.srcPos = ComputeGrabScreenPos(o.pos);
                //计算UV
                o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.uv.zw = TRANSFORM_TEX(v.texcoord, _BumpTex);
                
                //切线空间需要的3个向量，切线、副切线、法线，按照顺序存放。并把顶点的世界坐标放在w中。
                float3 worldPos = mul(UNITY_MATRIX_M, v.vertex).xyz;
                float3 worldNormal = UnityObjectToWorldNormal(v.normal);
                float3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                float3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w;
                o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
                o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
                o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);
                return o;
            }

            //使用的坐标都是切线空间坐标
            fixed4 frag (v2f i) : SV_Target
            {
                //顶点的世界坐标
                float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
                //世界空间下的视线
                float3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
                //世界空间下的光线
                float3 worldLightDir = normalize(UnityWorldSpaceLightDir(worldPos));
                
                //计算法线纹理。由于纹理存储的数值没有负数，是个像素值，而法线的范围是[-1,1]，所以得把像素值转换一下。
                //而且纹理经过了压缩，所以得解压一下。可以自己解压、也可以通过unity的函数。
                fixed4 packedNormal = tex2D(_BumpTex, i.uv.zw);
                //计算切线空间下的法线
                fixed3 tangentNormal = UnpackNormal(packedNormal);
                //法线的z保证是正数
                tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));

                //折射偏移
                float2 offset = tangentNormal.xy * _Distortion * _RefractionTex_TexelSize.xy;
                i.srcPos.xy += offset;
                //折射颜色
                fixed3 refrCol = tex2D(_RefractionTex, i.srcPos.xy / i.srcPos.w).rgb;
                
                //计算世界空间下的法线
                float3 worldNormal = float3(dot(i.TtoW0, tangentNormal), dot(i.TtoW1, tangentNormal), dot(i.TtoW2, tangentNormal));
                float3 reflDir = reflect(-worldViewDir, worldNormal);
                float3 texCol = tex2D(_MainTex, i.uv.xy);
                float3 reflCol = texCUBE(_CubeMap, reflDir).rgb * texCol.rgb;
                fixed3 finalColor = reflCol * (1 - _RefractionAmount) + refrCol * _RefractionAmount;
                
                //总和
                return fixed4(finalColor, 1.0);
            }
            ENDCG
        }
    }

    Fallback "Specular"
}
