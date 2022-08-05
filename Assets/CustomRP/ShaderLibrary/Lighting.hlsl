//光照计算相关库
#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED

TEXTURE2D(_RampMap);	SAMPLER(sampler_RampMap);
float _RampMapYRange;

float3 IncomingLight (Surface surface, Light light) 
{
	return saturate(dot(surface.normal, light.direction) * light.attenuation) * light.color;
}
//NPR半兰伯特ramp效果
float3 NPRIncomingLight(Surface surface, Light light)
{
	float3 halfLambert = smoothstep(0.0, 0.5, IncomingLight(surface, light));
	return SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(halfLambert.r, _RampMapYRange)).rgb;
}
//入射光乘以光照照射到表面的直接照明颜色
float3 GetLighting (Surface surface, BRDF brdf, Light light) 
{
	// return IncomingLight(surface, light) * DirectBRDF(surface, brdf, light);
	return NPRIncomingLight(surface, light) * DirectBRDF(surface, brdf, light);
}

//根据物体的表面信息和灯光属性获取最终光照结果
float3 GetLighting(Surface surfaceWS, BRDF brdf,  GI gi) 
{
	//得到表面阴影数据
	ShadowData shadowData = GetShadowData(surfaceWS);
	shadowData.shadowMask = gi.shadowMask;
	//可见光的光照结果进行累加得到最终光照结果
	float3 color = IndirectBRDF(surfaceWS, brdf, gi.diffuse, gi.specular);
	for (int i = 0; i < GetDirectionalLightCount(); i++) 
	{
		Light light = GetDirectionalLight(i, surfaceWS, shadowData);
		color += GetLighting(surfaceWS, brdf, light);
	}
	return color;
}
//new feature
Light GetMainLight(Surface surfaceWS, BRDF brdf,  GI gi)
{	
	Light light;
	ShadowData shadowData = GetShadowData(surfaceWS);
	shadowData.shadowMask = gi.shadowMask;
	float3 color = IndirectBRDF(surfaceWS, brdf, gi.diffuse, gi.specular);
	for (int i = 0; i < GetDirectionalLightCount(); i++) 
	{
		 light = GetDirectionalLight(i, surfaceWS, shadowData);
	}
	return light;
}


#endif
