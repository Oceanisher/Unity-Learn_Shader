//镜像
Shader "My/Mirror"
{
    Properties
    {
        _MainTex("渲染纹理", 2D) = "white" {}
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
            #include "AutoLight.cginc"

            sampler2D _MainTex;

            //输入：顶点、uv
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            //输出：顶点（裁剪空间）、UV、光照方向（切线空间）、观察方向（切线空间）
            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            //把坐标都转换到切线空间，并传递到片元着色器
            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                //镜像翻转X轴，因为是镜子
                o.uv.x = 1 - v.uv.x;
                return o;
            }

            //使用的坐标都是切线空间坐标
            fixed4 frag (v2f i) : SV_Target
            {
                return tex2D(_MainTex, i.uv);
            }
            ENDCG
        }
    }

    //如果自己不写阴影投射Pass，会在这个默认的里面找
    Fallback "Diffuse"
}
