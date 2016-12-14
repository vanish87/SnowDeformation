Shader "Snow/DeformationPostProcess" {

	Properties
	{
		_RecoverSpeed("RecoverSpeed", Range(0, 0.5)) = 0
	}
	SubShader 
	{
		Tags{ "RenderType" = "Opaque" }
		Pass {
			ZWrite On ZTest LEqual Cull Off
			CGPROGRAM
			#pragma target 3.0
			#pragma vertex vert
			#pragma fragment frag
			#pragma enable_d3d11_debug_symbols
			#include "UnityCG.cginc"

			struct v2f {
				float4 pos		: SV_POSITION;
				float4 uv		: TEXCOORD1;
			};

			sampler2D _NewDepthTex;// source texture
			sampler2D _CurrentDepthTexture;

			float _DeltaTime;
			float _RecoverSpeed;
			float _ObjectMinHeight;
			float _ArtistScale;

			v2f vert(appdata_full v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.texcoord;
				return o;
			}

			float getElevation(float currentSnowHeight, float currentObjectHeight, float deformationHeight )
			{
				float depressinDis = sqrt(currentSnowHeight - currentObjectHeight);
				float distanceFromFoot = sqrt(deformationHeight - currentObjectHeight);
				float elevationDistance = distanceFromFoot - depressinDis;
				return elevationDistance;
			}


			//this post process do two things:
			//1. calculate new deformation if it has a deeper depths; fill snow deformation when it is nessceary.
			//2. calculate elevation by sampling narbor pixels, then write elevation value for mesh rendering.
			float4 frag(v2f i) : SV_Target{
				float3 newInfo = tex2D(_NewDepthTex, i.uv.xy).rgb;
				float3 currentInfo = tex2D(_CurrentDepthTexture, i.uv.xy).rgb;

				//grater than 0 => elevation
				//less than 0 => deformation
				//snow height = 0.5
				float elevation = 0;
				if (newInfo.x < 1 && newInfo.x > 0.5)
				{
					float snowHeight = 0.5;
					float elevationDistance = getElevation(snowHeight, newInfo.y, newInfo.x);

					float maxElevationDistance = snowHeight - newInfo.y;
					float ratio = elevationDistance / (maxElevationDistance > 0 ? maxElevationDistance : 1);//scale * 2
					float height = maxElevationDistance * _ArtistScale;// 0.05;// max(elevationDistance, 0.3);

					//float elevation = ((-pow((0.5 - (2 * ratio)), 2) + 1) * height);
					elevation = (-2 * pow((ratio - 0.7), 2) + 1) * height / 100;
					//float2 target = sampleToOffset(_NewDepthTex, i.uv, 10);
					//if (target.r > 0 && target.r < 1)
					//{
					//	return float4(1, 0, 0, 0);
					//}

					
				}
				//depthValue = objectHeight;
				if (currentInfo.x < 0.5)
				{
					elevation = 0;
				}
				else if (currentInfo.z < 1)
				{
					elevation = max(elevation, currentInfo.z);
				}
				
				//if (hasNewDepth)
				{

				}
				//else
				{
					//depthValue = currentDepthValue + _RecoverSpeed*_DeltaTime;
				}
				bool hasNewDepth = newInfo.x < currentInfo.x;
				float2 ret = hasNewDepth ? newInfo : currentInfo;

				//if (newInfo.x < 1 && newInfo.x > 0.5)
				//	ret.x = 0.4;
				//do not linearize depth for orthographic camera
				return float4(ret, elevation, 0);
			}
			ENDCG
		}	
	}
	Fallback Off
}
