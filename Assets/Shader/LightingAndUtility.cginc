
static const float ElevationScale = 50;
static const float PI = 3.141592653;
static const float E = 2.7182818;

float _FrenalParameter;
float _FrenalBlending;

float _NoiseMin;
float _NoiseMax;
static float4 _Offset = float4(0.005, -0.006, 0.007, 0.008);


float4 _AmbientColor = float4(0.1f, 0.1f, 0.1f, 1.0f);
float4 _DiffuseShadeColor = float4(102 / 255.0f, 220 / 255.0f, 250 / 255.0f, 255);

float _Roughness = 1;
float _RefractiveIndex = 1;
float _ArtistElevationScale = 1;
float _ShadingBlendScale = 0.4;
float _ShadingEnergyPreserve = 0.4;
float _ShadingHG = 0.4;

//http://mimosa-pudica.net/improved-oren-nayar.html
//http://shaderjvo.blogspot.jp/2011/08/van-ouwerkerks-rewrite-of-oren-nayar.html
float3 OrenNayar(float3 lightDir, float3 viewDir, float3 normal, float sigma, float3 albedo, float3 shadingColor, float shdadingCorlorScale)
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

	float result = (cos_theta.x * (oren_nayar.x + oren_nayar.y * diffuse_oren_nayar));

	return (albedo * result * (1 - (_ShadingBlendScale * _ShadingEnergyPreserve)) ) + ((1- result) * _ShadingBlendScale * shadingColor * shdadingCorlorScale);
}

//reflection R
float SchlickFresnelWithN(float n, float3 halfVec, float3 viewDir/*or LightDir*/)
{
	float3 FresnelFactor = pow((1 - n) / (1 + n), 2);	
	float  VdotH = dot(halfVec, viewDir);
	return FresnelFactor + ((1 - FresnelFactor) * pow(1 - VdotH, 5));
}

//refrection T
float FresnelT(float n, float3 normal, float3 In)
{
	return 1 - SchlickFresnelWithN(n, normal, In);
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

float HenyeyGreensteinPhaseFunction(float3 inDir, float3 outDir, float g)
{
	float ret = 0;
	float gSqur = g * g;
	float cosTheta = dot(inDir, outDir);
	ret = (1 / (4 * PI)) * ((1 - gSqur) / pow(1 + gSqur - ((2 * g) * cosTheta), 1.5));
	return ret;
}

float ReducedIntensity(float s, float sigmaT)
{
	return pow(E, -sigmaT*s);
}

float IntensityAtOmigaDir(float phiX, float dir, float sigmaTReduced, float3 Nebla)
{
	float D = 1 / (3 * sigmaTReduced);
	float3 Ex = -D * Nebla * phiX;
	return (1 / (4 * PI) * phiX) + (3 / (4* PI) * dot(dir, Ex));
}

float SingleScatterTerm(float l, float v, float g/*HG phase g*/, float n, float sigmaS, float sigmaA)
{
	float3 halfVec = normalize(v + l);

	float F = FresnelT(n, halfVec, l) * FresnelT(n, halfVec, v);

	float sigmaT = sigmaA + sigmaS;
	float sigmaSReduced = sigmaS * (1 - g);
	float sigmaTReduced = sigmaA + sigmaSReduced;

	float3 refractedIn = l;//refract(l, halfVec, n);
	float3 refractedOut = float3(0, 0, 0);

	float distanceToLight = 1;
	float phiX = 1;
	float3 Nebla;

	float Q1 = 0;
	for (int i = 0; i < 50; ++i)
	{
		//random a light
		float3 dir = float3(1, 0, 1);
		refractedOut = dir;
		float phase = HenyeyGreensteinPhaseFunction(refractedIn, refractedOut, g);
		float Lri = ReducedIntensity(distanceToLight, sigmaT) * IntensityAtOmigaDir(phiX, refractedOut, sigmaTReduced, Nebla);
		float Q = sigmaS * F * phase * Lri;
		Q1 += Q;
	}
	return Q1;
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
	float specularPower,
	float shdadingCorlorScale = 0)
{
	float3 viewDir = normalize(_WorldSpaceCameraPos - position);
	float3 lightDir = normalize(float3(1, 1, 0));// normalize(_WorldSpaceLightPos0.xyz);
	normal = normalize(normal);

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
	float3 diffuse =  OrenNayar(lightDir, viewDir, normal, roughness, diffuseAlbedo, _DiffuseShadeColor, shdadingCorlorScale);
	diffuse *= (1.0f -  (specularAlbedo * fresnel));

	//specular term is BlinnPhong model
	float3 specular = specularAlbedo * CalBlinnPhong(normal, viewDir, lightDir, false, specularPower);
	//they are combined with fresnel term
	specular *= fresnel;

	float3 acc_color = (_AmbientColor + diffuse + specular);
	litColor = litColor + float4(acc_color, 1.0f);

	return litColor;
}

float4 CalLighting_OrenNayarBlinnNew(float3 normal,
	float3 position, //world pos
	float3 diffuseAlbedo,
	float3 specularAlbedo,
	float specularPower,
	float shdadingCorlorScale = 0)
{
	float3 viewDir = normalize(_WorldSpaceCameraPos - position);
	float3 lightDir = normalize(float3(1, 1, 0));// normalize(_WorldSpaceLightPos0.xyz);
	normal = normalize(normal);

	float4 litColor = float4(0.0f, 0.0f, 0.0f, 1.0f);

	float roughness = _Roughness;
	//overwrite invalid _Roughness
	if (_Roughness > 1)
	{
		roughness = sqrt(2 / (2 + specularPower));
	}
	float refractiveIndex = _RefractiveIndex;

	float3 halfVec = normalize(viewDir + lightDir);
	//diffuse term is OrenNayar model
	float3 diffuse = OrenNayar(lightDir, viewDir, normal, roughness, diffuseAlbedo, _DiffuseShadeColor, shdadingCorlorScale);
	diffuse += _DiffuseShadeColor * HenyeyGreensteinPhaseFunction(viewDir, lightDir, _ShadingHG);

	//specular term is BlinnPhong model
	float3 specular = specularAlbedo * CalBlinnPhong(normal, viewDir, lightDir, true, specularPower);

	float3 acc_color = (_AmbientColor + diffuse + specular);
	litColor = litColor + float4(acc_color, 1.0f);

	return litColor;
}



float4 CalLighting_BSSRDF(float3 normal,
	float3 position, //world pos
	float3 diffuseAlbedo,
	float3 specularAlbedo,
	float specularPower)
{
	float3 viewDir = normalize(_WorldSpaceCameraPos - position);
	float3 lightDir = normalize(float3(1, 1, 0));// normalize(_WorldSpaceLightPos0.xyz);
	normal = normalize(normal);



	float4 litColor = float4(0.0f, 0.0f, 0.0f, 1.0f); 
	float3 diffuse, specular;
	
	float3 acc_color = (_AmbientColor + diffuse + specular);
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
	return ((elevation / ElevationScale) + 1)* 0.5;
}
float decodeElevation(float elevation)
{
	return (elevation-0.5) * 2 * ElevationScale;
}

//set value to normalize color value
float encodeToColorSpace(float value)
{
	return (value + 1)* 0.5;
}
float decodeFromColorSpace(float value)
{
	return (value - 0.5) * 2;
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

float3 BlendNormal(float3 n1, float3 n2)
{
	//UDN blending
	float3 r = normalize(float3(n1.xy + n2.xy, n1.z));
	return r;
}

//deformationHeight in deformation camera space and normalize to [0,1]
//elevationHeight is reletive to snow height
float4 UpdateSnowInfo(float4 currentInfo, float4 newInfo)
{
	float deformationHeight= min(currentInfo.x, newInfo.x);
	float elevationHeight  = max(currentInfo.y, newInfo.y);
	float elevationDis	   = max(currentInfo.z, newInfo.z);
	//elevationDis = newInfo.z < 0 ? elevationDis :0;

	float4 ret = float4(0, 0, 0, 0);
	ret.r = deformationHeight;
	ret.g = elevationHeight;
	ret.b = elevationDis;

	return ret;
}

float getElevationDistance(float currentSnowHeight, float currentObjectHeight, float deformationHeight)
{
	float depressinDis = sqrt(currentSnowHeight - currentObjectHeight);
	float distanceFromFoot = sqrt(deformationHeight - currentObjectHeight);
	float elevationDistance = distanceFromFoot - depressinDis;
	return elevationDistance;
}

float2 CalculateElevation(float snowHeight, float objectHeight, float deformationHeight)
{
	float elevation = 0;
	//this object is above snow or is deformation pixel, early return
	if (snowHeight < objectHeight) return float2(0, elevation);

	float elevationDistance = getElevationDistance(snowHeight, objectHeight, deformationHeight);

	float ElevationHeightScale = snowHeight - objectHeight;
	float ratio = elevationDistance / ElevationHeightScale;
	float height = ElevationHeightScale * _ArtistElevationScale;

	//0.7 = sqrt(2) * 0.5;
	//this equation should have two roots, one is (0,0), another is (sqrt(2), 0) and the vertex is (sqrt(2)/2, 1)
	elevation = (-2 * pow((ratio - 0.7), 2) + 1) * height;
	//ratio normalize to sqrt(2) => /1.4 => *0.714
	return float2(ratio * 0.714, elevation);
}

float MapTextureCoordToShadeColor()
{

}