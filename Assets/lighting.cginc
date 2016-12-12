
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

		float3 light_dir = float3(-1, 1, 1);
		// The vector from the surface to the light.
		float3 pos_light;// = light_position - position;
		pos_light = light_dir;
		pos_light = normalize(pos_light);

		normal = normalize(normal);

		float diffuse_angle = dot(pos_light, normal);//N * Lc
		[flatten]
		if (diffuse_angle > 0.0f)
		{
			float3 refect_vec = reflect(-pos_light, normal);

			float spec_factor = pow(max(dot(refect_vec, pos_eye), 0.0f), specularPower);

			//Cdiff * Clight * (N * Lc)
			diffuse = diffuseAlbedo * light_color * diffuse_angle;
			//diffuse = light_color * diffuse_angle;
			//pow(R*V, alpha) * Cspec * Clight * (N * Lc)
			spec = spec_factor * float4(specularAlbedo, 1.0f) * light_color * diffuse_angle;

			//float4 spectColor = CalFresnal(spec, float4(1,0,0,1), position, normal);
			//spec = spectColor;
		}

		float4 acc_color = (ambient + diffuse + spec);
		litColor = litColor + acc_color;
	}
	return litColor;
}