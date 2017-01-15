Shader "Snow/DeformationPostProcess" {
	
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

			float _RecoverSpeed;
			float _ObjectMinHeight;
			float _ArtistScale;

			v2f vert(appdata_full v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.texcoord;
				return o;
			}
			


			//this post process do two things:
			//1. calculate new deformation if it has a deeper depths; refill snow deformation when it is nessceary.
			//2. calculate elevation with snow height, object height and deformation height, then write elevation value for mesh rendering.

			//_CurrentDepthTexture stores current deormation and elevation info
			//r: deformationHeight; g: objectHeight; b: elevation
			float4 frag(v2f i) : SV_Target
			{
				//r: deformationHeight; g: objectHeight;
				float3 newInfo = tex2D(_NewDepthTex, i.uv.xy).rgb;
				//r: deformationHeight; g: elevationHeight b:elevationDistance
				float4 currentInfo = tex2D(_CurrentDepthTexture, i.uv.xy).rgba;
				//rgb: normal; a:depth in Accumulation camera space
				float snowHeight = tex2D(_CurrentAccumulationTexture, i.uv.xy).a;
				//TODO: set _CurrentAccumulationTexture.a default to 0.5
				//then snowHeight = 1 - snowHeight;
				snowHeight = snowHeight > 0 ? 1 - snowHeight : 0.5;

				//_NewDepthTex is normalize
				float objectHeight = newInfo.g;
				float deformationHeight = newInfo.r > 0? newInfo.r:1;
				float2 newElevation = CalculateElevation(snowHeight, objectHeight, deformationHeight);	
				//newElevation.y is elevation height, newElevation.x is elevation distance
				//both of them could be positive or nagitive, so then should be normalize to corlor space

				//deformation Height(r value) is [0, 1]
				//elevation height(g value)   is [-camerapos, camerapos]
				//elevation distance(b value) is [-1,1]
				//so only encode/decode elevation height and elevation distance that calculated in CalculateElevation above
				currentInfo.g = decodeElevation(currentInfo.g);
				currentInfo.b = decodeFromColorSpace(currentInfo.b);

				float4 updatedInfo = UpdateSnowInfo(float4(currentInfo.rgb,0), float4(deformationHeight, newElevation.y, newElevation.x,0));
				
				updatedInfo.r += _RecoverSpeed;// *_TimeDelta;
				updatedInfo.g = encodeElevation(updatedInfo.g);
				updatedInfo.b = encodeToColorSpace(updatedInfo.b);

				return updatedInfo;
			}			
			ENDCG
		}	
	}
	Fallback Off
}
