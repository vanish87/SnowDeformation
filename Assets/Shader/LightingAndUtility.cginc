
static const float ElevationScale = 50;
static const float PI = 3.141592653;

float _FrenalParameter;
float _FrenalBlending;

float _NoiseMin;
float _NoiseMax;
static float4 _Offset = float4(0.005, -0.006, 0.007, 0.008);

float _Roughness = 1;
float _RefractiveIndex = 1;

//http://mimosa-pudica.net/improved-oren-nayar.html
//http://shaderjvo.blogspot.jp/2011/08/van-ouwerkerks-rewrite-of-oren-nayar.html
float3 OrenNayar(float3 lightDir, float3 viewDir, float3 normal, float sigma, float3 albedo)
{
	float roughness = sigma;
	float roughness2 = roughness*roughness;
	float2 oren_nayar_fraction = roughness2 / (roughness2 + float2(0.33, 0.09));
	float2 oren_nayar = float2(1, 0) + float2(-0.5, 0.45) * oren_nayar_fraction;

	//Theta and phi
	float2 cos_theta = saturate(float2(dot(normal, lightDir), dot(normal, viewDir)));
	float2 cos_theta2 = cos_theta * cos_theta;
	float sin_theta = sqrt((1 - cos_theta2.x)*(1 - cos_theta2.y));
	float3 light_plane = normalize(lightDir - cos_theta.x*normal);
	float3 view_plane = normalize(viewDir - cos_theta.y*normal);
	float cos_phi = saturate(dot(light_plane, view_plane));

	//composition

	float diffuse_oren_nayar = cos_phi * sin_theta / max(cos_theta.x, cos_theta.y);

	return albedo * (cos_theta.x * (oren_nayar.x + oren_nayar.y * diffuse_oren_nayar));
}

float3 OrenNayar1(float3 lightDir, float3 viewDir, float3 normal, float sigma, float3 albedo)
{
	float sigma2 = sigma*sigma;
	float VdotN = dot(viewDir, normal);
	float LdotN = dot(lightDir, normal);
	float cos_theta_i = LdotN;
	float theta_r = acos(VdotN);
	float theta_i = acos(cos_theta_i);
	float cos_phi_diff = dot(normalize(viewDir-normal*VdotN), normalize(lightDir-normal*LdotN));
	float alpha = max(theta_i, theta_r);
	float beta = min(theta_i, theta_r);
	float A = 1.0 - 0.5 * sigma2 / (sigma2 + 0.33);
	float B = 0.45 * sigma2 / (sigma2 + 0.09);

	if (cos_phi_diff >= 0)
		B *= sin(alpha) * tan(beta);
	else
		B *= 0;

	return albedo * (cos_theta_i * (A+B));
}

float SchlickFresnel(float R0, float3 positionWS, float3 normalWS)
{
	float3 I = normalize(_WorldSpaceCameraPos - positionWS);
	float NdotI = max(0, dot(I, normalWS));
	float ReflectionCoefficient = R0 + ((1 - R0) * pow(1 - NdotI, 5));
	return ReflectionCoefficient;
}

float4 CalFresnal(float4 ColorFresnel, float4 ColorReflection, float3 PositionWS, float3 NormalWS)
{
	float4 FinalColor;
	float reflectionFactor = SchlickFresnel(_FrenalParameter, PositionWS, NormalWS);
	FinalColor = lerp(ColorReflection, ColorFresnel, reflectionFactor * _FrenalBlending);
	return FinalColor;
}

float SchlickFresnelWithN(float n, float3 halfVec, float3 viewDir/*or LightDir*/)
{
	float3 FresnelFactor = pow((1 - n) / (1 + n), 2);	
	float  VdotH = dot(halfVec, viewDir);
	return FresnelFactor + ((1 - FresnelFactor) * pow(1 - VdotH, 5));
}

float CookTorranceGeometry(float3 normal, float3 halfVec, float3 viewDir, float3 lightDir)
{
	float NdotH = dot(normal, halfVec);
	float VdotH = dot(viewDir, halfVec);
	float NdotMin = min(dot(normal, viewDir), dot(normal, lightDir));
	return min(1.0f, 2.0f * NdotH * NdotMin / VdotH);
}

//The power αp is the “roughness parameter” of the Phong NDF; high values represent smooth
//surfaces and low values represent rough ones.
float BlinnPhongDistribution(float3 normal, float3 halfVec, float alpha)
{
	float normalizeTerm = (alpha + 2) / (2 * PI);
	return normalizeTerm * pow(max(0,dot(normal, halfVec)), alpha);
}


//http://simonstechblog.blogspot.jp/2011/12/microfacet-brdf.html
//http://blog.selfshadow.com/publications/s2012-shading-course/hoffman/s2012_pbs_physics_math_notes.pdf
float CalBlinnPhong(float3 normal, float3 viewDir, float3 lightDir, bool withFresnal, float power)
{
	float3 halfVec = normalize(viewDir + lightDir);
	float f = 1;
	if (withFresnal)
	{
		f = SchlickFresnelWithN(_RefractiveIndex, halfVec, lightDir);
	}

	float g = CookTorranceGeometry(normal, halfVec, viewDir, lightDir);
	//BlinnPhong distribution
	float d = BlinnPhongDistribution(normal, halfVec, power);

	float NdotL = dot(normal, lightDir);
	float NdotV = dot(normal, viewDir);
	return f * g * d / (4 * NdotL * NdotV);
}

float4 CalLighting_OrenNayarBlinn(float3 normal,
	float3 position, //world pos
	float3 diffuseAlbedo,
	float3 specularAlbedo,
	float specularPower)
{
	float3 viewDir = normalize(_WorldSpaceCameraPos - position);
	float3 lightDir = normalize(float3(1, 1, 0));// normalize(_WorldSpaceLightPos0.xyz);
	normal = normalize(normal);


	float4 ambient = float4(0.1f, 0.1f, 0.1f, 1.0f);
	float4 litColor = float4(0.0f, 0.0f, 0.0f, 1.0f);

	float roughness = _Roughness;
	//overwrite invalid _Roughness
	if (_Roughness > 1)
	{
		roughness = sqrt(2 / (2 + specularPower));
	}
	float refractiveIndex = _RefractiveIndex;

	float3 halfVec = normalize(viewDir + lightDir);
	//normal or halfVec here to get best result
	//half is correct term.
	float fresnel = SchlickFresnelWithN(refractiveIndex, halfVec, viewDir);

	//diffuse term is OrenNayar model
	float3 diffuse =  OrenNayar(lightDir, viewDir, normal, roughness, diffuseAlbedo);
	diffuse *= (1.0f -  (specularAlbedo * fresnel));

	//specular term is BlinnPhong model
	float3 specular = specularAlbedo * CalBlinnPhong(normal, viewDir, lightDir, false, specularPower);
	//specular = BlinnPhongDistribution(normal, halfVec, 500);
	//they are combined with fresnel term
	specular *= fresnel;

	float3 acc_color = (ambient + diffuse + specular);
	litColor = litColor + float4(acc_color, 1.0f);

	return litColor;
}

//calculate view space coordinate and scale xy to UV coornidates.
float3 TransfromToTextureCoord(float4 Position, float4x4 CameraMatirx, float CameraScale)
{
	float3 heightUV;
	float4 positionSnowCamera = mul(CameraMatirx, Position);
	heightUV.x = positionSnowCamera.x / CameraScale;
	heightUV.y = positionSnowCamera.y / CameraScale;
	heightUV.z = positionSnowCamera.z;
	heightUV.x = clamp((1 + heightUV.x) * 0.5, 0.0, 1.0);
	heightUV.y = clamp((heightUV.y + 1) * 0.5, 0.0, 1.0);
	return heightUV;
}

//set elevation to normalize value
float encodeElevation(float elevation)
{
	return elevation / ElevationScale;
}
float decodeElevation(float elevation)
{
	return elevation * ElevationScale;
}

float SampleNosie(sampler2D noise, float3 viewVector, float2 uv)
{
	float p1 = tex2D(noise, uv + float2(0, viewVector.x * _Offset.x)).r;
	float p2 = tex2D(noise, uv + float2(0, viewVector.y * _Offset.y)).g;
	float p3 = tex2D(noise, uv + float2(viewVector.x * _Offset.z, 0)).b;
	float p4 = tex2D(noise, uv + float2(viewVector.y * _Offset.w, 0)).a;
	float sum = p1 + p2 + p3 + p4;
	if (sum > _NoiseMin && sum < _NoiseMax)
	{
		return sum / (_NoiseMax - _NoiseMin);
	}
	return 0;
}