﻿//灯光数据相关库
#ifndef CUSTOM_LIGHT_INCLUDED
#define CUSTOM_LIGHT_INCLUDED

#define MAX_DIRECTIONAL_LIGHT_COUNT 4
CBUFFER_START(_CustomLight)
    int _DirectionalLightCount;
    //定向光源颜色、方向、阴影等数据
    float4 _DirectionalLightColors[MAX_DIRECTIONAL_LIGHT_COUNT];
    float4 _DirectionalLightDirections[MAX_DIRECTIONAL_LIGHT_COUNT];
    //阴影数据
    float4 _DirectionalLightShadowData[MAX_DIRECTIONAL_LIGHT_COUNT];
CBUFFER_END

//灯光的属性
struct Light {
    float3 color;
    float3 direction;
    float attenuation;//衰减
};
//获取方向光源的数量
int GetDirectionalLightCount() {
	return _DirectionalLightCount;
}
//获取方向光的阴影数据
DirectionalShadowData GetDirectionalShadowData(int lightIndex, ShadowData shadowData) {
	DirectionalShadowData data;
	data.strength = _DirectionalLightShadowData[lightIndex].x;
	data.tileIndex = _DirectionalLightShadowData[lightIndex].y + shadowData.cascadeIndex;
	//法线偏差
	data.normalBias = _DirectionalLightShadowData[lightIndex].z;
	data.shadowMaskChannel = _DirectionalLightShadowData[lightIndex].w;
	return data;
}

//获取目标索引定向光的属性
Light GetDirectionalLight (int index,Surface surfaceWS, ShadowData shadowData) {
	Light light;
	light.color = _DirectionalLightColors[index].rgb;
	light.direction = _DirectionalLightDirections[index].xyz;
	//得到阴影数据
	DirectionalShadowData dirShadowData = GetDirectionalShadowData(index,shadowData);
	//得到阴影衰减
	light.attenuation = GetDirectionalShadowAttenuation(dirShadowData,shadowData, surfaceWS);

	return light;
}


#endif