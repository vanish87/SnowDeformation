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
			#include "LightingAndUtility.cginc"

			struct v2f {
				float4 pos		: SV_POSITION;
				float4 uv		: TEXCOORD1;
			};

			sampler2D _NewDepthTex;// source texture
			sampler2D _CurrentDepthTexture;
			sampler2D _CurrentAccumulationTexture;

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

			//_CurrentDepthTexture stores current deormation and elevation info
			//r: deformationHeight; g: objectHeight; b: elevation
			float4 frag(v2f i) : SV_Target{
				float3 newInfo = tex2D(_NewDepthTex, i.uv.xy).rgb;
				float4 currentInfo = tex2D(_CurrentDepthTexture, i.uv.xy).rgba;
				float snowHeight = tex2D(_CurrentAccumulationTexture, i.uv.xy).a;
				float currentElevation = decodeElevation(currentInfo.z);

				float deformationHeight = newInfo.x;
				float objectHeight = newInfo.y;

				//snow height = 0.5
				float elevation = 0;
				snowHeight = 0.5;// snowHeight < 1 ? 1 - snowHeight : 0.5;
				float ratio = 0; float ElevationHeightScale = 0;
				float maxheight = 1;
				//check if this pixel is a trail pixel, trail pixel should calculate elevation
				if (deformationHeight < 1 && objectHeight < 1 &&
					deformationHeight > snowHeight && 
					snowHeight > objectHeight)
				{
					//deformationHeight > snowHeight so elevationDistance is bigger than 0
					float elevationDistance = getElevation(snowHeight, objectHeight, deformationHeight);

					//the deeper an oject got into snow, the greater ElevationHeightScale it produces.
					ElevationHeightScale = snowHeight - objectHeight;
					ratio = elevationDistance / ElevationHeightScale;
					float height = ElevationHeightScale * _ArtistScale;

					//0.7 = sqrt(2) * 0.5;
					//this equation should have two roots, one is (0,0), another is (sqrt(2), 0) and the vertex is (sqrt(2)/2, 1)
					elevation = (-2 * pow((ratio - 0.7), 2) + 1) * height;
					if (elevation > 0)
						maxheight = ratio > 0.7 ? (ratio ) / 1.4 : 0;
					else
						maxheight = 1;
					//maxheight = maxheight>0.5 ? 1 : 0;
				}
				maxheight = min(currentInfo.a, maxheight);
				//if it has current deformation, then do not make trials
				if (currentInfo.x < snowHeight)
				{
					elevation = 0;
					maxheight = 0;
				}
				//if it has current elevation, then make a greater one
				else if (currentElevation < ElevationScale)
				{
					elevation = max(elevation, currentElevation);
				}
				
				//update current deformation info too
				bool hasNewDepth = newInfo.x < currentInfo.x;
				float2 ret = hasNewDepth ? newInfo : currentInfo;
				return float4(ret, encodeElevation(elevation), maxheight);
			}
			ENDCG
		}	
	}
	Fallback Off
}
