Shader "CustomRP/NPRshader"
{
    Properties
    {
        [HideInInspector] _MainTex("Texture for Lightmap", 2D) = "white" {}
	   [HideInInspector] _Color("Color for Lightmap", Color) = (0.5, 0.5, 0.5, 1.0)
       //pbr
        _BaseMap("Texture", 2D) = "white" {}//_MainTex
	   _MainColor("Color", Color) = (0.5, 0.5, 0.5, 1.0)//_MainColor
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

        [Header(ShaderEnum)]
        [Space(5)]
        [KeywordEnum(Body,Face,Hair)]_ShaderEnum("Shader枚举类型",int)=0
        [Toggle(IN_NIGHT)]_InNight ("是晚上吗", int) = 0

        [Header(ParamTex)]
        [Space(5)]
        _ParamTex ("参数图（LightMap或FaceLightMap）", 2D) = "white" { }
        [Space(30)]

        [Header(Ramp)]
        [Space(5)]
        _RampMap ("Ramp图", 2D) = "white" { }
        _RampMapYRange ("Ramp图要在Y轴哪个值采样", Range(0.0,0.5)) = 1.0
        [Space(30)]

        [Header(Specular)]
        [Space(5)]
        _Matcap ("Matcap图", 2D) = "white" { }
        _MetalColor("金属颜色",Color)= (1,1,1,1)//
        _HairSpecularIntensity("头发高光强度",Range(0.0,10)) = 0.5

       [HDR]_HairSpecColor ("高光颜色",Color) = (1,1,1,1)
        _HairSpecularRange("头发高光范围",Float) =0.5
        _HairSpecularViewRange("头发高光视角范围",Float) =0.5
        [Space(30)]

        [Space(5)]
        _FaceShadowRangeSmooth ("脸部阴影转折要不要平滑", Range(0.01,1.0)) = 0.1
        [Space(30)]

        [Header(RimLight)]
        [Space(5)]
        _RimIntensity("边缘光亮度",Range(0.0,5.0)) = 0
        _RimRadius("边缘光范围",Range(0.0,1.0)) = 0.1
        [Space(30)]

        [Header(Emission)]
        [Space(5)]
        _EmissionIntensity("自发光强度",Range(0.0,25.0)) = 0.0//
        [Space(30)]

        [Header(Outline)]
        [Space(5)]
        _outlinecolor ("描边颜色", Color) = (0,0,0,1)
        _outlinewidth ("描边粗细", Range(0, 1)) = 0.01
    }
    SubShader
    {     
        HLSLINCLUDE

		#include "../ShaderLibrary/Common.hlsl"
        #include "../ShaderLibrary/Surface.hlsl"
        #include "../ShaderLibrary/Shadows.hlsl"
        #include "../ShaderLibrary/Light.hlsl"
        #include "../ShaderLibrary/BRDF.hlsl"
        #include "../ShaderLibrary/GI.hlsl"
        #include "../ShaderLibrary/Lighting.hlsl"

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
		//    #pragma multi_compile _PCF _ESM
		   #pragma multi_compile _ _DIRECTIONAL_PCF3 _DIRECTIONAL_PCF5 _DIRECTIONAL_PCF7
		   #pragma multi_compile _ _CASCADE_BLEND_SOFT _CASCADE_BLEND_DITHER
		   #pragma multi_compile _ _SHADOW_MASK_ALWAYS _SHADOW_MASK_DISTANCE
		   #pragma multi_compile _ LIGHTMAP_ON
		   #pragma multi_compile _ LOD_FADE_CROSSFADE
           #pragma multi_compile_instancing
        //    #pragma vertex LitPassVertex
        //    #pragma fragment LitPassFragment
            
        TEXTURE2D(_EmissionMap);
        TEXTURE2D(_BaseMap);SAMPLER(sampler_BaseMap);

        UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
        UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
        UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
        UNITY_DEFINE_INSTANCED_PROP(float4, _EmissionColor)
        UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
        UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
        UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)
        UNITY_DEFINE_INSTANCED_PROP(float, _Fresnel)
        // UNITY_DEFINE_INSTANCED_PROP(float, _AOmap_ST)
        UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

        //基础纹理UV转换
        float2 TransformBaseUV(float2 baseUV) {
            float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseMap_ST);
            return baseUV * baseST.xy + baseST.zw;
        }

        //获取基础纹理的采样数据
        float4 GetBase(float2 baseUV) {
            float4 map = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, baseUV);
            float4 color = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
            return map * color;
        }

        float GetCutoff(float2 baseUV) {
            return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff);
        }

        float GetMetallic(float2 baseUV) {
            return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Metallic);
        }

        float GetSmoothness(float2 baseUV) {
            return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Smoothness);
        }
        //获取自发光纹理的采样数据
        float3 GetEmission (float2 baseUV) {
            float4 map = SAMPLE_TEXTURE2D(_EmissionMap, sampler_BaseMap, baseUV);
            float4 color = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _EmissionColor);
            return map.rgb * color.rgb;
        }
        float GetFresnel (float2 baseUV) {
            return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Fresnel);
        }
        ENDHLSL
        }




		// Pass
        // {
		//    Tags {
		// 		"LightMode" = "ShadowCaster"
		// 	}
		//     ColorMask 0

        //     HLSLPROGRAM
		// 	#pragma target 3.5
		// 	#pragma shader_feature _CLIPPING
		// 	#pragma multi_compile _ LOD_FADE_CROSSFADE
		// 	#pragma multi_compile_instancing
		// 	#pragma vertex ShadowCasterPassVertex
		// 	#pragma fragment ShadowCasterPassFragment
		// 	#include "ShadowCasterPass.hlsl"
		// 	ENDHLSL
        // }
	// 	Pass
	// 	{
	// 		Tags {
	// 			"LightMode" = "Meta"
	// 		}

	// 		Cull Off

	// 		HLSLPROGRAM
	// 		#pragma target 3.5
	// 		#pragma vertex MetaPassVertex
	// 		#pragma fragment MetaPassFragment
	// 		#include "MetaPass.hlsl"
	// 		ENDHLSL
	// 	}
    }
		   CustomEditor "CustomShaderGUI"
}
