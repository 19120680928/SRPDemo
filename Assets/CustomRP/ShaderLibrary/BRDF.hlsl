//BRDF相关库
#ifndef CUSTOM_BRDF_INCLUDED
#define CUSTOM_BRDF_INCLUDED

#include "Surface.hlsl"
#include "Light.hlsl"
#include "Common.hlsl"

struct BRDF 
{
    float3 diffuse;
    float3 specular;
    float roughness;
    float perceptualRoughness;      //实际粗糙度
    float fresnel;      //菲涅尔
};

//电介质的反射率平均约0.04,或称F0
#define Ks 0.04
//计算不反射的值，将范围从 0-1 调整到 0-0.96，保持和URP中一样
float GetKd (float metallic) 
{
	return (1 - Ks) * (1 - metallic);
}

float3 GetKd(float3 F,float metallic)
{
	return (1 - F) * (1 - metallic);
}

//得到表面的BRDF数据
BRDF GetBRDF (Surface surface, bool applyAlphaToDiffuse = false) {
	BRDF brdf;
	//乘以表面颜色得到BRDF的漫反射
	float Kd = GetKd(surface.metallic);
	brdf.diffuse = surface.color * Kd;
	//透明度预乘
	if (applyAlphaToDiffuse) {
		brdf.diffuse *= surface.alpha;
	}
	brdf.specular = lerp(Ks, surface.color, surface.metallic);
	//光滑度转为实际粗糙度
	brdf.perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(surface.smoothness);
	brdf.roughness = PerceptualRoughnessToRoughness(brdf.perceptualRoughness);
	//将表面光滑度和反射率加在一起得到菲涅尔颜色
	brdf.fresnel = saturate(surface.smoothness + 1.0 - Kd);
	return brdf;
}

//获取基于BRDF的直接照明
float3 DirectBRDF (Surface surface, BRDF brdf, Light light)
{	
	float3 L = normalize(light.direction);
	//float3 V = surface.viewDirection;//LitPass片元着色器已经算好了
	float3 H = SafeNormalize(L + surface.viewDirection);

	float VdotH = max(0.001f,saturate(dot(surface.viewDirection,H)));
	float NdotV = max(0.001f,saturate(dot(surface.normal,surface.viewDirection)));
	float NdotL = max(0.001f,saturate(dot(surface.normal,L)));
	float NdotH = max(0.001f,saturate(dot(surface.normal,L)));

	//D
	float nh2 = Square(saturate(dot(surface.normal, H)));
	float lh2 = Square(saturate(dot(light.direction, H)));
	float r2 = Square(brdf.roughness);
	float d2 = Square(nh2 * (r2 - 1.0) + 1.00001);
	float normalization = brdf.roughness * 4.0 + 2.0;
	float D_GGX =  r2 / (d2 * max(0.1, lh2) * normalization);

	//F(Ks)
	float3 F_Schlick = brdf.specular + (1 - brdf.specular) * pow(1 - VdotH, 5.0);
	
	//G
	float k = Square(brdf.roughness + 1) / 8;
	float GV = NdotV / (NdotV * (1-k) + k);
	float GL = NdotL / (NdotL * (1-k) + k);
	float G_GGX = GV * GL;
	//镜面反射
	brdf.specular = F_Schlick * D_GGX * G_GGX / (4 * NdotV * NdotL);

	//漫反射
	brdf.diffuse = GetKd(F_Schlick, surface.metallic) * surface.color;
	//return 1 ;
	return brdf.specular + brdf.diffuse;
}
//获取基于BRDF的间接照明 曲线拟合，贴图都省了
float3 IndirectBRDF (Surface surface, BRDF brdf, float3 diffuse, float3 specular)
{
	float fresnelStrength =surface.fresnelStrength * Pow4(1.0 - saturate(dot(surface.normal, surface.viewDirection)));
    float3 reflection = specular * lerp(brdf.specular, brdf.fresnel, fresnelStrength);
	reflection /= brdf.roughness * brdf.roughness + 1.0;
    return diffuse * brdf.diffuse + reflection;
}

#endif
