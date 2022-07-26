﻿#ifndef CUSTOM_LIT_INPUT_INCLUDED
#define CUSTOM_LIT_INPUT_INCLUDED

TEXTURE2D(_EmissionMap);
TEXTURE2D(_AOmap);SAMPLER(sampler_AOmap);
TEXTURE2D(_BaseMap);SAMPLER(sampler_BaseMap);
TEXTURE2D(_MaskMap);SAMPLER(sampler_MaskMap);

UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
UNITY_DEFINE_INSTANCED_PROP(float4, _EmissionColor)
UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)
UNITY_DEFINE_INSTANCED_PROP(float, _Fresnel)
UNITY_DEFINE_INSTANCED_PROP(float, _MaskMap_ST)
// UNITY_DEFINE_INSTANCED_PROP(float, _AOmap_ST)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

//基础纹理UV转换
float2 TransformBaseUV(float2 baseUV) 
{
	float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseMap_ST);
	return baseUV * baseST.xy + baseST.zw;
}

//获取基础纹理的采样数据
float4 GetBase(float2 baseUV) 
{	
	//DX需要翻转G通道，这个记得加宏判断
	float4 map = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, float2(baseUV.r, 1 - baseUV.g));
	// float4 map = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, baseUV);
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
float3 GetAo(float2 baseUV)
{	
	// float4 aoColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _AOmap_ST);
	return (SAMPLE_TEXTURE2D(_AOmap,sampler_BaseMap,baseUV)).rgb;
}
float3 GetPBRMaskMap(float2 baseUV)
{
	return (SAMPLE_TEXTURE2D(_MaskMap,sampler_MaskMap,baseUV)).rgb;
}
#endif
