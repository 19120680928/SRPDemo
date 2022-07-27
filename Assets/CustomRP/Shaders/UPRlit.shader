Shader "CustomRP/NPRLit"
{
    Properties
    {
        [HideInInspector] _MainTex("Texture for Lightmap", 2D) = "white" {}
	   [HideInInspector] _Color("Color for Lightmap", Color) = (0.5, 0.5, 0.5, 1.0)
       //pbr
        _BaseMap("Texture", 2D) = "white" {}
	   _BaseColor("Color", Color) = (0.5, 0.5, 0.5, 1.0)
	   //透明度测试的阈值
	   _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
	   [Toggle(_CLIPPING)] _Clipping("Alpha Clipping", Float) = 0
	   //阴影模式
	   [KeywordEnum(On, Clip, Dither, Off)] _Shadows ("Shadows", Float) = 0
	   //是否接受阴影
	   [Toggle(_RECEIVE_SHADOWS)] _ReceiveShadows ("Receive Shadows", Float) = 1
       //透明通道预乘
	   [Toggle(_PREMULTIPLY_ALPHA)] _PremulAlpha("Premultiply Alpha", Float) = 0
       //金属度和光滑度
	   _Metallic("Metallic", Range(0, 1)) = 0
	   _Smoothness("Smoothness", Range(0, 1)) = 0.5
	   //菲涅尔强度
	   _Fresnel ("Fresnel", Range(0, 1)) = 1
	   //自发光
	   [NoScaleOffset] _EmissionMap("Emission", 2D) = "white" {}
	   [HDR] _EmissionColor("Emission", Color) = (0.0, 0.0, 0.0, 0.0)
    }
    SubShader
    {     
        HLSLINCLUDE
		#include "../ShaderLibrary/Common.hlsl"
		#include "LitInput.hlsl"
		ENDHLSL
		
        Pass
        {
		   Tags {"LightMode" = "CustomLit"}

		   //定义混合模式
		   Blend[_SrcBlend][_DstBlend]
		   //是否写入深度
		   ZWrite[_ZWrite]
           HLSLPROGRAM
		   #pragma target 3.5
		   #pragma shader_feature _ _SHADOWS_CLIP _SHADOWS_DITHER
		   #pragma shader_feature _RECEIVE_SHADOWS
		   //是否透明通道预乘
		   #pragma shader_feature _PREMULTIPLY_ALPHA
		   #pragma multi_compile _PCF _ESM
		   #pragma multi_compile _ _DIRECTIONAL_PCF3 _DIRECTIONAL_PCF5 _DIRECTIONAL_PCF7
		   #pragma multi_compile _ _CASCADE_BLEND_SOFT _CASCADE_BLEND_DITHER
		   #pragma multi_compile _ _SHADOW_MASK_ALWAYS _SHADOW_MASK_DISTANCE
		   #pragma multi_compile _ LIGHTMAP_ON
		   #pragma multi_compile _ LOD_FADE_CROSSFADE
           #pragma multi_compile_instancing
           #pragma vertex vert
           #pragma fragment frag

        struct VertexInput //输入结构
        {
            float4 vertex : POSITION;
            float2 uv0 : TEXCOORD0;
            half4 color: COLOR;
            float4 normal : NORMAL;
        };

        struct VertexOutput //输出结构
        {
            float4 pos : POSITION;
            float2 uv0 : TEXCOORD0;
            float4 vertexColor: COLOR;
            float3 nDirWS : TEXCOORD1;
            float3 nDirVS : TEXCOORD2;
            float3 vDirWS : TEXCOORD3;
            float3 posWS : TEXCOORD4;
        };

        VertexOutput vert(VertexInput input) //顶点shader
        {
            VertexOutput output = (VertexOutput)0; // 新建输出结构
            ZERO_INITIALIZE(VertexOutput, output); //初始化顶点着色器
            output.vertexColor = input.color;
            output.uv0 = input.uv0;
            output.uv0 = float2(output.uv0.x, 1 - output.uv0.y);
            output.pos = TransformObjectToHClip(input.vertex.xyz);
            output.posWS = TransformObjectToWorld(input.vertex.xzy);
            output.nDirWS = TransformObjectToWorldNormal(input.normal.xyz);
            output.nDirVS = TransformWorldToView(output.nDirWS);
            output.vDirWS = _WorldSpaceCameraPos.xyz - output.posWS;
            return output; // 返回输出结构
        }
        float4 frag(VertexOutput input) : SV_Target
        {   
            float test = float(1) < (0);
            return float4(test,0,0,1);
            // return _BaseColor;
        }




           ENDHLSL
        }

		Pass
        {
		   Tags {
				"LightMode" = "ShadowCaster"
			}
		    ColorMask 0

            HLSLPROGRAM
			#pragma target 3.5
			#pragma shader_feature _CLIPPING
			#pragma multi_compile _ LOD_FADE_CROSSFADE
			#pragma multi_compile_instancing
			#pragma vertex ShadowCasterPassVertex
			#pragma fragment ShadowCasterPassFragment
			#include "ShadowCasterPass.hlsl"
			ENDHLSL
        }
		Pass
		{
			Tags {
				"LightMode" = "Meta"
			}

			Cull Off

			HLSLPROGRAM
			#pragma target 3.5
			#pragma vertex MetaPassVertex
			#pragma fragment MetaPassFragment
			#include "MetaPass.hlsl"
			ENDHLSL
		}
    }
		   CustomEditor "CustomShaderGUI"
}
