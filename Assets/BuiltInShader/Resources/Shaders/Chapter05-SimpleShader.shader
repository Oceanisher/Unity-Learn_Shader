// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

//Chapter05_简单
//定义shader名称
Shader "Unity Shaders Book/Chapter 05/Simple Shader"
{
    //Properties定义变量，可以在面板上设置；(1.0, 1.0, 1.0, 1.0)是初始值
    Properties
    {
        _Color("Color Tint", Color) = (1.0, 1.0, 1.0, 1.0)
    }
    //SubShader定义具体的Shader，可以有多个
    SubShader
    {
        //SubShader中包含Pass
        Pass
        {
            //CG代码开头
            CGPROGRAM
            //定义一个顶点着色器函数，叫做vert
            #pragma vertex vert
            //定义一个片元着色器函数，叫做frag
            #pragma fragment frag

            //如果使用Properties中的变量，需要在Pass里定义一个类型、名称都匹配的变量
            fixed4 _Color;
            
            //定义一个结构体来定义顶点着色器的输入
            struct a2v
            {
                //POSITION告知Unity该函数的输入是顶点
                float4 vertex : POSITION;
                //NORMAL告知Unity用模型空间的法线方向填充normal变量
                float3 normal : NORMAL;
                //TEXCOORD0告知Unity用模型的第一套纹理坐标填充texcoord变量
                float4 texcoord : TEXCOORD0;
            };

            //使用一个结构体来定义顶点着色器的输出
            struct v2f
            {
                //SV_POSITION告知Unity该函数的输出是裁剪空间中的顶点坐标
                float4 pos : SV_POSITION;
                //COLOR0告知颜色信息
                fixed3 color : COLOR0;
            };
            
            //顶点着色器函数。POSITION告知Unity该函数的输入是顶点，SV_POSITION告知Unity该函数的输出是裁剪空间中的顶点坐标
            v2f vert(a2v v) {
                //定义一个返回值
                v2f o;
                //将顶点从模型空间转换到裁剪空间函数
                o.pos = UnityObjectToClipPos (v.vertex);
                //设定每个点的颜色
                o.color = v.normal * 0.5 + fixed3(0.5,0.5,0.5);
                return o;
            }

            //片元着色器函数。SV_Target告知Unity渲染器，把返回结果颜色存储到一个渲染目标中，这里将输出到默认帧缓存中。
            //函数的输入是顶点着色器函数的输出
            float4 frag(v2f i) : SV_Target {
                //获取顶点中的Color
                fixed3 c = i.color;
                //用Properties中的数值调和颜色
                c *= _Color.rgb;
                //这里是颜色值，(0,0,0)是黑色，(1,1,1)是白色
                //fixed4是一个数据类型
                return fixed4(c, 1.0);
            }

            //CG代码结尾
            ENDCG
        }
    }
}