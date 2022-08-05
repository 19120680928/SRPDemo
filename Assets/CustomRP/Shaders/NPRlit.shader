Shader "CustomRP/NPRLit"
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
		#include "LitInput.hlsl"

        // #include "NPRinput.hlsl"
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
		   #pragma multi_compile _PCF _ESM
		   #pragma multi_compile _ _DIRECTIONAL_PCF3 _DIRECTIONAL_PCF5 _DIRECTIONAL_PCF7
		   #pragma multi_compile _ _CASCADE_BLEND_SOFT _CASCADE_BLEND_DITHER
		   #pragma multi_compile _ _SHADOW_MASK_ALWAYS _SHADOW_MASK_DISTANCE
		   #pragma multi_compile _ LIGHTMAP_ON
		   #pragma multi_compile _ LOD_FADE_CROSSFADE
           #pragma multi_compile_instancing
           #pragma vertex vert
           #pragma fragment frag
           #pragma shader_feature _SHADERENUM_BODY _SHADERENUM_FACE _SHADERENUM_HAIR
           

            
        struct VertexInput //输入结构
        {
            float4 vertex : POSITION;
            float2 uv0 : TEXCOORD0;
            half4 color: COLOR;
            float4 normalOS : NORMAL;
            GI_ATTRIBUTE_DATA
	        UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        struct VertexOutput //输出结构
        {
            float4 posCS : POSITION;
            float2 uv0 : VAR_BASE_UV;
            float4 vertexColor: COLOR;
            float3 nDirWS : TEXCOORD1;
            float3 nDirVS : TEXCOORD2;
            float3 vDirWS : TEXCOORD3;
            float3 posWS : TEXCOORD4;
            float4 positionCS : TEXCOORD5;
            float3 normalWS : VAR_NORMAL;
            GI_VARYINGS_DATA
	        UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        VertexOutput vert(VertexInput input) //顶点shader
        {
            VertexOutput output = (VertexOutput)0; 
            TRANSFER_GI_DATA(input, output);
            UNITY_TRANSFER_INSTANCE_ID(input, output);
            output.vertexColor = input.color;
            output.uv0 = input.uv0;
            output.uv0 = float2(output.uv0.x, 1 - output.uv0.y);
            output.posCS = TransformObjectToHClip(input.vertex.xyz);
            output.posWS = TransformObjectToWorld(input.vertex.xzy);
            output.nDirWS = TransformObjectToWorldNormal(input.normalOS.xyz);
            output.nDirVS = TransformWorldToView(output.nDirWS);
            output.vDirWS = _WorldSpaceCameraPos.xyz - output.posWS;
            output.normalWS = TransformObjectToWorldNormal(input.normalOS.xyz);
            return output; // 返回输出结构
        }
        float4 frag(VertexOutput input) : SV_Target
        {   
            UNITY_SETUP_INSTANCE_ID(input);
            float4 base = GetBase(input.uv0);
            Surface surface;
            surface.position = input.posWS;
            surface.normal = normalize(input.normalWS);
            surface.viewDirection = normalize(_WorldSpaceCameraPos - input.posWS);

            surface.depth = -TransformWorldToView(input.posWS).z;
            surface.color = base.rgb;
            surface.alpha = base.a;
            surface.metallic = GetMetallic(input.uv0);
            surface.smoothness = GetSmoothness(input.uv0);
            surface.fresnelStrength = GetFresnel(input.uv0);
            //计算抖动值
            surface.dither = InterleavedGradientNoise(input.positionCS.xy, 0);
            BRDF brdf = GetBRDF(surface);
            GI gi = GetGI(GI_FRAGMENT_DATA(input), surface, brdf);
            Light light = GetMainLight(surface, brdf, gi);

            float3 N = normalize(input.nDirWS);
            float3 V = normalize(input.vDirWS);
            float3 L = normalize(light.direction);
            float3 H = normalize(V + L);
            
            float3 NdotL = dot(N,L);
            float3 NdotH = dot(N,H);
            float3 NdotV = dot(N,V);

            float3 FinalColor = GetLighting(surface,brdf,gi);

            // #if _SHADERENUM_BASE
            //     FinalColor = NPR_Base(NdotL, NdotH, NdotV, N, baseColor, var_ParamTex, _InNight, _RampMapYRange);
            // #elif  _SHADERENUM_FACE
            //     FinalColor = NPR_Face(baseColor, var_ParamTex, lDir, _InNight, _FaceShadowRangeSmooth, _RampMapYRange);
            // #elif _SHADERENUM_HAIR
            //     FinalColor = NPR_Hair(NdotL, NdotH, NdotV, N, baseColor, var_ParamTex, _InNight,_RampMapYRange);
            // #endif

            return float4(FinalColor, 1.0);
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
