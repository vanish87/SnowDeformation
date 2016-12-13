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

			v2f vert(appdata_full v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.texcoord;
				return o;
			}

			float getElevation(float currentSnowHeight, float currentObjectHeight,)
			{

			}

			//this post process do two things:
			//1. calculate new deformation if it has a deeper depths; fill snow deformation when it is nessceary.
			//2. calculate elevation by sampling narbor pixels, then write elevation value for mesh rendering.
			float4 frag(v2f i) : SV_Target{
				float2 newInfo = tex2D(_NewDepthTex, i.uv.xy).rg;
				float2 currentInfo = tex2D(_CurrentDepthTexture, i.uv.xy).rg;

				//depthValue = objectHeight;
				bool hasNewDepth = newInfo.x < currentInfo.x;
				//if (hasNewDepth)
				{

				}
				//else
				{
					//depthValue = currentDepthValue + _RecoverSpeed*_DeltaTime;
				}
				float2 ret = hasNewDepth ? newInfo : currentInfo;
				//do not linearize depth for orthographic camera
				return float4(ret, 0, 0);
			}
			ENDCG
		}	
	}
	Fallback Off
}
