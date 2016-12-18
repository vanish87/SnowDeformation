
static const float ElevationScale = 50;
static const float PI = 3.141592653;
float _FrenalParameter;
float _FrenalBlending;

float4 OrenNayar(float3 lightDir, float3 viewDir, float3 normal, float sigma, float4 albedo)
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
			diffuse = diffuseAlbedo;// *OrenNayar(light_dir, pos_eye, normal, 0.3, ab);
			diffuse *= (1.0f - SchlickFresnel(0.3, position, normal));
			//diffuse = light_color * diffuse_angle;
			//pow(R*V, alpha) * Cspec * Clight * (N * Lc)
			spec = spec_factor * float4(specularAlbedo, 1.0f) * light_color * diffuse_angle;

			//float4 spectColor = CalFresnal(spec, float4(1,0,0,1), position, normal);
			spec = CalFresnal(float4(135.0f/255, 206.0f/255, 240.0f/255, 1), spec, position, normal);
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