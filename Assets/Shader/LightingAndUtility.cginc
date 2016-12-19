
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
float3 OrenNayar(float3 lightDir, float3 viewDir, float3 normal, float sigma, float3 albedo)
{
	float LdotV = dot(lightDir, viewDir);
	float NdotL = dot(lightDir, normal);
	float NdotV = dot(normal, viewDir);

	float s = LdotV - NdotL * NdotV;
	float t = lerp(1.0, max(NdotL, NdotV), step(0.0, s));

	float sigma2 = sigma * sigma;
	float A = 1.0 + sigma2 * (albedo / (sigma2 + 0.13) + 0.5 / (sigma2 + 0.33));
	float B = 0.45 * sigma2 / (sigma2 + 0.09);

	return albedo * max(0.0, NdotL) * (A + B * s / t) / PI;
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
	return min(1, 2 * NdotH * NdotMin / VdotH);
}

//The power αp is the “roughness parameter” of the Phong NDF; high values represent smooth
//surfaces and low values represent rough ones.
float BlinnPhongDistribution(float3 normal, float3 halfVec, float alpha)
{
	float normalizeTerm = (alpha + 2) / (2 * PI);
	return normalizeTerm * pow(dot(normal, halfVec), alpha);
}


//http://simonstechblog.blogspot.jp/2011/12/microfacet-brdf.html
//http://blog.selfshadow.com/publications/s2012-shading-course/hoffman/s2012_pbs_physics_math_notes.pdf
float CalBlinnPhong(float3 normal, float3 viewDir, float3 lightDir, bool withFresnal, float power)
{
	float3 halfVec = normalize(viewDir + lightDir);
	float f = 1;
	if (withFresnal)
	{
		f = SchlickFresnelWithN(3, halfVec, lightDir);
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
	float3 lightDir = _WorldSpaceLightPos0.xyz;


	float4 ambient = float4(0.1f, 0.1f, 0.1f, 1.0f);
	float4 litColor = float4(0.0f, 0.0f, 0.0f, 1.0f);

	float3 albedo = float3(0.97, 0.97, 0.97);
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
	float3 diffuse = diffuseAlbedo * OrenNayar(lightDir, viewDir, normal, roughness, albedo);
	diffuse *= (1.0f -  (specularAlbedo * fresnel));

	//specular term is BlinnPhong model
	float3 specular = specularAlbedo * CalBlinnPhong(normal, viewDir, lightDir, false, specularPower);
	//they are combined with fresnel term
	specular *= fresnel;

	float3 acc_color = (ambient + diffuse + specular);
	litColor = litColor + float4(acc_color, 1.0f);

	return litColor;
}


float4 CalLighting(float3 normal,
	float3 position, //world pos
	float4 diffuseAlbedo,
	float3 specularAlbedo,
	float specularPower)
{
	float3 pos_eye = normalize(_WorldSpaceCameraPos - position);

	// Start with a sum of zero. 
	float4 ambient = float4(0.1f, 0.1f, 0.1f, 1.0f);
	float4 litColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
	{
		float4 diffuse = float4(0.0f, 0.0f, 0.0f, 0.0f);
		float4 spec = float4(0.0f, 0.0f, 0.0f, 0.0f);
		float4 light_color = float4(1.0f, 1.0f, 1.0f, 0.0f);
		float3 light_position = float3(0, 1, 0);//view_pos

		//_WorldSpaceLightPos0
		float3 light_dir = float3(1,1,0);// _WorldSpaceLightPos0;
		// The vector from the surface to the light.
		float3 pos_light;// = light_position - position;
		pos_light = light_dir;
		pos_light = normalize(pos_light);

		normal = normalize(normal);

		float4 ab = float4(1, 1, 1, 1);

		//return OrenNayar(light_dir, pos_eye, normal, 0.3, ab);

		float diffuse_angle = dot(pos_light, normal);//N * Lc
		[flatten]
		if (diffuse_angle > 0.0f)
		{

			float3 refect_vec = reflect(-pos_light, normal);

			float spec_factor = pow(max(dot(refect_vec, pos_eye), 0.0f), specularPower);

			//Cdiff * Clight * (N * Lc)
			diffuse = diffuseAlbedo * light_color * diffuse_angle;
			//diffuse = diffuseAlbedo *OrenNayar(light_dir, pos_eye, normal, 1, ab);
			diffuse *= (1.0f - SchlickFresnel(0.3, position, normal));
			//diffuse = light_color * diffuse_angle;
			//pow(R*V, alpha) * Cspec * Clight * (N * Lc)
			spec = spec_factor * float4(specularAlbedo, 1.0f) * light_color * diffuse_angle;

			//float4 spectColor = CalFresnal(spec, float4(1,0,0,1), position, normal);
			spec = CalFresnal(float4(235.0f/255, 245.0f/255, 255.0f/255, 1), spec, position, normal);
			//spec.rgb = SchlickFresnel(0, position, normal);
		}

		float4 acc_color = (ambient + diffuse + spec);
		litColor = litColor + acc_color;
	}
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

float sampleNosie(sampler2D noise, float3 viewVector, float2 uv)
{
	float p1 = tex2D(noise, uv + float2(0, viewVector.x * _Offset.x)).r;
	float p2 = tex2D(noise, uv + float2(0, viewVector.y * _Offset.y)).g;
	float p3 = tex2D(noise, uv + float2(viewVector.x * _Offset.z, 0)).b;
	float p4 = tex2D(noise, uv + float2(viewVector.y * _Offset.w, 0)).a;
	float sum = p1 + p2 + p3 + p4;
	if (sum > _NoiseMin && sum < _NoiseMax)
	{
		return 1;
	}
	return 0;
}