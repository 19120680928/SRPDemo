//阴影采样相关库
#ifndef CUSTOM_SHADOWS_INCLUDED
#define CUSTOM_SHADOWS_INCLUDED
#include "../ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"

//定向光阴影的数据信息
struct DirectionalShadowData
{
    float strength;
    int tileIndex;      //在图集中的索引
    float normalBias;   //法线偏差
	int shadowMaskChannel;
};

struct ShadowMask//阴影遮罩数据信息
{
	bool always;
	bool distance;
	float4 shadows;
};

//阴影数据
struct ShadowData 
{
    int cascadeIndex;   //级联索引
    float strength;     //如果超出了最后一个级联的范围，就没有有效的阴影数据了，此时不需要采样，将 strength设为 0
    float cascadeBlend; //混合级联
	ShadowMask shadowMask;//阴影遮罩
};
//vsm
float _gVarianceBias;// 最小方差
float _gLightLeakBias;// 漏光

#if defined(_DIRECTIONAL_PCF3) //如果使用的是PCF 3X3 
	#define DIRECTIONAL_FILTER_SAMPLES 4 //需要4个过滤器样本
	#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_3x3

#elif defined(_DIRECTIONAL_PCF5)
	#define DIRECTIONAL_FILTER_SAMPLES 9
	#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_5x5

#elif defined(_DIRECTIONAL_PCF7)
	#define DIRECTIONAL_FILTER_SAMPLES 16
	#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_7x7
#endif

#define MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT 4
#define MAX_CASCADE_COUNT 4

//---------------阴影图集采样-------------------------
TEXTURE2D_SHADOW(_DirectionalShadowAtlas);
#define SHADOW_SAMPLER sampler_linear_clamp_compare
SAMPLER_CMP(SHADOW_SAMPLER);

CBUFFER_START(_CustomShadows)
int _CascadeCount;//级联数量
float4 _CascadeCullingSpheres[MAX_CASCADE_COUNT];//包围球数据
float4 _CascadeData[MAX_CASCADE_COUNT];//级联数据
float4x4 _DirectionalShadowMatrices[MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT * MAX_CASCADE_COUNT];//阴影转换矩阵
float4 _ShadowDistanceFade;//阴影过渡距离
float4 _ShadowAtlasSize;//图集大小
CBUFFER_END

//采样阴影图集
float SampleDirectionalShadowAtlas(float3 positionSTS) 
{
	return SAMPLE_TEXTURE2D_SHADOW(_DirectionalShadowAtlas, SHADOW_SAMPLER, positionSTS);
}
//PCF滤波采样定向光阴影
float PCF(float3 positionSTS) {
#if defined(DIRECTIONAL_FILTER_SETUP)
	//样本权重
	float weights[DIRECTIONAL_FILTER_SAMPLES];
	//样本位置
	float2 positions[DIRECTIONAL_FILTER_SAMPLES];
	float4 size = _ShadowAtlasSize.yyxx;//yyxx是面积
	/*第一个为float4类型的向量存储图集，其中XY分量是图集纹素大小，ZW分量是图集尺寸，第二个参数是原始样本的位置
	后两个是样本的权重和样本的位置。然后遍历所有滤波样本，将所有的样本权重进行累加*/
	DIRECTIONAL_FILTER_SETUP(size, positionSTS.xy, weights, positions);
	float shadow = 0;
	for (int i = 0; i < DIRECTIONAL_FILTER_SAMPLES; i++) {
		//遍历所有样本滤波得到权重和
		shadow += weights[i] * SampleDirectionalShadowAtlas(float3(positions[i].xy, positionSTS.z));
	}
	return shadow;
#else
	return SampleDirectionalShadowAtlas(positionSTS);
#endif
}
/*--------------------------PCSS-----------------------
float Rand_2to1(float2 uv)
{
	float a = 12.9898, b = 78.233, c = 43758.5453;
	float dt = dot(uv.xy, float2(a, b));
	float sn = fmod(dt, PI);
	return frac(sin(sn) * c);
}
#define NUM_SAMPLES 50
#define NUM_RINGS 10
#define EPS 1e-3
#define _gShadow_bias 0
float2 poissonDisk[NUM_SAMPLES];
// 泊松圆盘采样
void PoissonDiskSamples(const in float2 randomSeed)
{
	float ANGLE_STEP = 2*PI * float(NUM_RINGS) / float(NUM_SAMPLES);
	float INV_NUM_SAMPLES = 1.0 / float(NUM_SAMPLES);
	float angle = Rand_2to1(randomSeed) * 2*PI;
	float radius = INV_NUM_SAMPLES;
	float radiusStep = radius;
	UNITY_UNROLL for (int i = 0; i < NUM_SAMPLES; i++)
	{
		poissonDisk[i] = float2(cos(angle), sin(angle)) * pow(radius, 0.75);
		radius += radiusStep;
		angle += ANGLE_STEP;
	}
}
float FindBlocker(float3 positionSTS, float zReceiver)// 获取遮挡物平均深度
{
	PoissonDiskSamples(positionSTS);
	float2 filterStride = 5;
	float filterRange = positionSTS.xy * filterStride;
	// 有多少点在阴影里
	int shadowCount = 0;
	float blockDepth = 0.0;
	
	UNITY_UNROLL for (int i = 0; i < NUM_SAMPLES; i++)
	{
		float2 sampleCoord = poissonDisk[i] * filterRange + positionSTS.xy;
		float closestDepth = SampleDirectionalShadowAtlas((sampleCoord,1));
		if (zReceiver - _gShadow_bias > closestDepth)
		{
			blockDepth += closestDepth;
			shadowCount += 1;
		}	
	}
	if (shadowCount == NUM_SAMPLES)
	{
		return 2.0;
	}
	// 平均
	return blockDepth / float(shadowCount);
}

float PCSS(float3 positionSTS)
{
	float _gLightWidth = 0.5;
	float zReceiver = positionSTS.z;
	// STEP 1: blocker search
	float zBlocker = FindBlocker(positionSTS,zReceiver);
	if (zBlocker < EPS)
		return 1.0;
	if (zBlocker > 1.0)
		return 0.0;
	// STEP 2: penumbra size
	float wPenumbra = (zReceiver - zBlocker) * _gLightWidth / zBlocker;
	// STEP 3: filtering
	// 这里的步长要比 STEP 1 的步长小一些
	float filterStride = 10;
	float2 filterRange = positionSTS.xy * filterStride * wPenumbra;
	float shadow = 0;
	UNITY_UNROLL for (int i = 0; i < NUM_SAMPLES; i++)
	{
		float2 sampleCoord = poissonDisk[i] * filterRange + positionSTS.xy;
		float pcfDepth = SampleDirectionalShadowAtlas((sampleCoord,1));
		float currentDepth = positionSTS.z;
		
		shadow += currentDepth - _gShadow_bias > pcfDepth ? 0.0 : 1.0;
	}
	shadow /= float(NUM_SAMPLES);
	return shadow;
}
--------------------------PCSS END-----------------------*/

float ESM(float3 positionSTS)//指数拟合ShadowMap
{	
	int constValue = -2;
	float expDepth = SampleDirectionalShadowAtlas(positionSTS);
	float currentExpDepth = exp(positionSTS.z * constValue);
	return saturate(expDepth * currentExpDepth);
}
float VSM(float3 positionSTS)
{
	float currentDepth = positionSTS.z;
	float2 moments = SAMPLE_TEXTURE2D_SHADOW(_DirectionalShadowAtlas, SHADOW_SAMPLER, positionSTS);
	float minVariance = _gVarianceBias;
    float lightLeakBias = _gLightLeakBias;
	if (currentDepth <= moments.x)
	{
		return 1.0;
	}
	float E_x2 = moments.y;
    float Ex_2 = moments.x * moments.x;
	// variance sig^2 = E(x^2) - E(x)^2
	float variance = E_x2 - Ex_2;
	variance = max(variance, minVariance);
	float mD = currentDepth - moments.x;
	float mD_2 = mD * mD;
	// 切比雪夫不等式
	float p = variance / (variance + mD_2);

	// return p;

	p = saturate((p - lightLeakBias) / (1.0 - lightLeakBias));
	return max(p, currentDepth <= moments.x);

}

//得到级联阴影强度
float GetCascadedShadow(DirectionalShadowData directional, ShadowData global, Surface surfaceWS)
{
	//物体计算法线偏移+灯光法线斜度比例偏差
	float3 normalBias = surfaceWS.normal * (directional.normalBias * _CascadeData[global.cascadeIndex].y);
	//通过阴影转换矩阵和表面位置得到在阴影纹理(图块)空间的位置，然后对图集进行采样 
	float3 positionSTS = mul(_DirectionalShadowMatrices[directional.tileIndex], float4(surfaceWS.position + normalBias, 1.0)).xyz;

	// #if _PCF
		float shadow = PCF(positionSTS);	
		if (global.cascadeBlend < 1.0) 	//如果级联混合小于1代表在级联层级过渡区域中，必须从下一个级联中采样并在两个值之间进行插值
		{
			normalBias = surfaceWS.normal *(directional.normalBias * _CascadeData[global.cascadeIndex + 1].y);
			positionSTS = mul(_DirectionalShadowMatrices[directional.tileIndex + 1], float4(surfaceWS.position + normalBias, 1.0)).xyz;
			shadow = lerp(PCF(positionSTS), shadow, global.cascadeBlend);
		}

	// #elif _ESM
	// 	float shadow = ESM(positionSTS);
	// 	if (global.cascadeBlend < 1.0) 
	// 	{
	// 		normalBias = surfaceWS.normal *(directional.normalBias * _CascadeData[global.cascadeIndex + 1].y);
	// 		positionSTS = mul(_DirectionalShadowMatrices[directional.tileIndex + 1], float4(surfaceWS.position + normalBias, 1.0)).xyz;
	// 		shadow = lerp(ESM(positionSTS), shadow, global.cascadeBlend);

	// 	}
	// #endif

	return shadow;

}
//得到烘焙阴影的衰减值 test
float GetBakedShadow(ShadowMask mask, int channel) {
	float shadow = 1.0;
	if (mask.always || mask.distance) {
		if (channel >= 0) {
			shadow = mask.shadows[channel];
		}
	}
	return shadow;
}
float GetBakedShadow(ShadowMask mask, int channel, float strength) {
	if (mask.always || mask.distance) {
		return lerp(1.0, GetBakedShadow(mask,channel), strength);
	}
	return 1.0;
}
//混合烘焙和实时阴影
float MixBakedAndRealtimeShadows(ShadowData global, float shadow, int shadowMaskChannel, float strength)
{
	float baked = GetBakedShadow(global.shadowMask, shadowMaskChannel);
	if (global.shadowMask.always) {
		shadow = lerp(1.0, shadow, global.strength);
		shadow = min(baked, shadow);
		return lerp(1.0, shadow, strength);
	}
	if (global.shadowMask.distance) {
		shadow = lerp(baked, shadow, global.strength);
		return lerp(1.0, shadow, strength);
	}
	//最终衰减结果是阴影强度和采样衰减的线性差值
	return lerp(1.0, shadow, strength * global.strength);
}
//得到阴影衰减
float GetDirectionalShadowAttenuation(DirectionalShadowData directional, ShadowData global, Surface surfaceWS) {
	//如果材质没有定义接受阴影的宏
#if !defined(_RECEIVE_SHADOWS)
	return 1.0;
#endif
	float shadow;
	if (directional.strength * global.strength <= 0.0) {
		shadow = GetBakedShadow(global.shadowMask, directional.shadowMaskChannel, abs(directional.strength));
	}
	else 
	{
		shadow = GetCascadedShadow(directional, global, surfaceWS);
		//混合烘焙和实时阴影
		shadow = MixBakedAndRealtimeShadows(global, shadow, directional.shadowMaskChannel, directional.strength);
	}	
	
	return shadow;
}
//公式计算阴影过渡时的强度
float FadedShadowStrength (float distance, float scale, float fade) {
	return saturate((1.0 - distance * scale) * fade);
}

//得到世界空间的表面阴影数据
ShadowData GetShadowData (Surface surfaceWS) {
	ShadowData data;
	data.shadowMask.always = false;
	data.shadowMask.distance = false;
	data.shadowMask.shadows = 1.0;
	data.cascadeBlend = 1.0;
	data.strength =FadedShadowStrength(surfaceWS.depth, _ShadowDistanceFade.x, _ShadowDistanceFade.y);
	int i;
	//如果物体表面到球心的平方距离小于球体半径的平方，就说明该物体在这层级联包围球中，得到合适的级联层级索引
	for (i = 0; i < _CascadeCount; i++) {
		float4 sphere = _CascadeCullingSpheres[i];
		float distanceSqr = DistanceSquared(surfaceWS.position, sphere.xyz);
		if (distanceSqr < sphere.w) {
			//计算级联阴影的过渡强度，叠加到阴影强度上作为最终阴影强度
			float fade = FadedShadowStrength(distanceSqr, _CascadeData[i].x, _ShadowDistanceFade.z);
			//如果物体在最后一层级联中
			if (i == _CascadeCount - 1) {
				data.strength *= fade;
			}
			else {
				data.cascadeBlend = fade;
			}
			break;
		
		}
	}
	//如果超出级联层数，不进行阴影采样
	if (i == _CascadeCount) {
		data.strength = 0.0;
	}
#if defined(_CASCADE_BLEND_DITHER)
	else if (data.cascadeBlend < surfaceWS.dither) {
		i += 1;
	}
#endif
#if !defined(_CASCADE_BLEND_SOFT)
	data.cascadeBlend = 1.0;
#endif
	data.cascadeIndex = i;
	return data;
}


#endif