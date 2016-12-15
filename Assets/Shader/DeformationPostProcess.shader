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
			#include "lighting.cginc"

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
			//1. calculate new deformation if it has a deeper depths; refill snow deformation when it is nessceary.
			//2. calculate elevation with snow height, object height and deformation height, then write elevation value for mesh rendering.
			float4 frag(v2f i) : SV_Target{
				float3 newInfo = tex2D(_NewDepthTex, i.uv.xy).rgb;
				float3 currentInfo = tex2D(_CurrentDepthTexture, i.uv.xy).rgb;

				float deformationHeight = newInfo.x;
				float objectHeight = newInfo.y;

				//grater than 0 => elevation
				//less than 0 => deformation
				//snow height = 0.5
				float elevation = 0;
				float snowHeight = 0.5;
				//check if this pixel is a trail pixel
				if (deformationHeight < 1 && objectHeight < 1 &&
					deformationHeight > snowHeight && 
					snowHeight > objectHeight)
				{
					//deformationHeight > snowHeight so elevationDistance is bigger than 0
					float elevationDistance = getElevation(snowHeight, objectHeight, deformationHeight);

					//the deeper an oject got into snow, the greater ElevationHeightScale it produces.
					float ElevationHeightScale = snowHeight - objectHeight;
					float ratio = elevationDistance / ElevationHeightScale;
					float height = ElevationHeightScale * _ArtistScale;

					//0.7 = sqrt(2) * 0.5;
					elevation = encodeElevation((-2 * pow((ratio - 0.7), 2) + 1) * height);					
				}
				//if it has current deformation, then do not make trials
				if (currentInfo.x < snowHeight)
				{
					elevation = 0;
				}
				//if it has current elevation, then make a greater one
				else if (currentInfo.z < 1)
				{
					elevation = max(elevation, currentInfo.z);
				}
				
				//update current deformation info too
				bool hasNewDepth = newInfo.x < currentInfo.x;
				float2 ret = hasNewDepth ? newInfo : currentInfo;
				//do not linearize depth for orthographic camera
				return float4(ret, elevation, 0);
			}
			ENDCG
		}	
	}
	Fallback Off
}
