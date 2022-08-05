#ifndef NPRFUNTION
#define NPRFUNTION
float3 NPR_Ramp(float NdotL, float _InNight, float _RampMapYRange)
{
    float halfLambert = smoothstep(0.0, 0.5, NdotL); //只要halfLambert的一半映射Ramp

    if (_InNight > 0.0)
    {
        return SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(halfLambert, _RampMapYRange)).rgb; //晚上
    }
    else
    {
        return SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, float2(halfLambert, _RampMapYRange + 0.5)).rgb; //白天
    }
}

//高光部分
float3 NPR_Specular(float3 NdotH, float3 baseColor, float4 var_ParamTex)
{
    #if  _SHADERENUM_HAIR
        float SpecularRadius = pow(NdotH, var_ParamTex.a * 50); //将金属通道作为高光的范围控制  金属的部分高光集中  非金属的部分高光分散
    #else
    float SpecularRadius = pow(NdotH, var_ParamTex.r * 50); //将金属通道作为高光的范围控制  金属的部分高光集中  非金属的部分高光分散
    #endif

    float3 SpecularColor = var_ParamTex.b * baseColor;

    #if  _SHADERENUM_HAIR
        return smoothstep(0.3, 0.4, SpecularRadius) * SpecularColor * lerp(_HairSpecularIntensity, 1, step(0.9, var_ParamTex.b)); //头发部分的高光强度自定
    #else
    return smoothstep(0.3, 0.4, SpecularRadius) * SpecularColor * var_ParamTex.b;
    #endif
}

//头发高光
float3 NPR_Hair_Specular(float NdotH, float4 var_ParamTex)
{
    //头发高光
    float SpecularRange = smoothstep(1 - _HairSpecularRange, 1, NdotH);
    float HairSpecular = var_ParamTex.b * SpecularRange;
    float3 hairSpec = HairSpecular * _HairSpecColor;
    return hairSpec;
}

//金属部分
float3 NPR_Metal(float3 nDir, float4 var_ParamTex, float3 baseColor)
{
    float3 viewNormal = normalize(mul(UNITY_MATRIX_V, nDir)); //视空间法线向量，用于MatCap的UV采样
    float var_Matcap = SAMPLE_TEXTURE2D(_Matcap, sampler_Matcap, viewNormal * 0.5 + 0.5) * 2;
    #if  _SHADERENUM_HAIR
        return var_Matcap * baseColor * var_ParamTex.a;
    #endif
    return var_Matcap * baseColor * var_ParamTex.r;
}

//边缘光
float3 NPR_Rim(float NdotV, float NdotL, float4 baseColor)
{
    float3 rim = (1 - smoothstep(_RimRadius, _RimRadius + 0.03, NdotV)) * _RimIntensity * (1 - (NdotL * 0.5 + 0.5)) * baseColor;
    //float3 rim = (1 - smoothstep(_RimRadius, _RimRadius + 0.03, NdotV)) * _RimIntensity * baseColor;
    return rim;
}

//自发光(带有呼吸效果)
float3 NPR_Emission(float4 baseColor)
{
    return baseColor.a * baseColor * _EmissionIntensity * abs((frac(_Time.y * 0.5) - 0.5) * 2);
}

//身体部分
float3 NPR_Base(float NdotL, float NdotH, float NdotV, float3 nDir, float4 baseColor, float4 var_ParamTex, float _InNight, float _RampMapYRange)
{
    float3 RampColor = NPR_Ramp(NdotL, _InNight, _RampMapYRange);
    float3 Albedo = baseColor * RampColor;
    float3 Specular = NPR_Specular(NdotH, baseColor, var_ParamTex);
    float3 Metal = NPR_Metal(nDir, var_ParamTex, baseColor);
    float3 RimLight = NPR_Rim(NdotV, NdotL, baseColor) * var_ParamTex.g;
    float3 Emission = NPR_Emission(baseColor);
    float3 FinalColor = Albedo * (1 - var_ParamTex.r) + Specular + Metal + RimLight + Emission;
    return FinalColor;
}

//脸部
float3 NPR_Face(float4 baseColor, float4 var_ParamTex, float3 lDir, float _InNight, float _FaceShadowRangeSmooth, float _RampMapYRange)
{
    //上Y
    float3 Up = float3(0.0, 1.0, 0.0);
    //前Z
    float3 Front = unity_ObjectToWorld._12_22_32;
    // float3 Front = (0.0,0.0,1.0);
    //右X
    float3 Right = cross(Up, Front);
    //点乘得到投影范围
    float switchShadow = dot(normalize(Right.xz), lDir.xz) * 0.5 + 0.5;
    //通过SDF插值贴图平滑过渡    https://zhuanlan.zhihu.com/p/337944099
    float FaceShadow = lerp(var_ParamTex, 1 - var_ParamTex, switchShadow);
    //脸部阴影的阈值范围
    float FaceShadowRange = dot(normalize(Front.xz), normalize(lDir.xz));
    //使用阈值来计算灯光衰减后的color
    float lightAttenuation = 1 - smoothstep(FaceShadowRange - _FaceShadowRangeSmooth, FaceShadowRange + _FaceShadowRangeSmooth, FaceShadow);
    //Ramp
    float3 rampColor = NPR_Ramp(lightAttenuation, _InNight, _RampMapYRange);
    return baseColor.rgb * rampColor;
}

//头发
float3 NPR_Hair(float NdotL, float NdotH, float NdotV, float3 nDir, float4 baseColor, float4 var_ParamTex, float _InNight, float _RampMapYRange)
{
    //头发的rampColor不应该把固定阴影的部分算进去，所以这里固定阴影给定0.5 到计算ramp的时候 *2 结果等于1
    float3 RampColor = NPR_Ramp(NdotL, _InNight, _RampMapYRange);
    float3 Albedo = baseColor * RampColor;

    float3 hairSpec = NPR_Hair_Specular(NdotH, var_ParamTex);

    float3 Metal = NPR_Metal(nDir, var_ParamTex, baseColor);
    float3 RimLight = NPR_Rim(NdotV, NdotL, baseColor);
    float3 finalRGB = Albedo + hairSpec * RampColor + Metal + RimLight;
    return finalRGB;
}
#endif