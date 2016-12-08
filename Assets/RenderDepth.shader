Shader "Snow/RenderDepth" {

	Properties
	{
		_RecoverSpeed("RecoverSpeed", Range(0, 0.5)) = 0.1
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
				float4 pos : SV_POSITION;
				float4 uv  : TEXCOORD1;
			};

			sampler2D _CameraDepthTexture;
			sampler2D _CurrentDepthTexture;

			float _DeltaTime;
			float _RecoverSpeed;

			v2f vert( appdata_full v ) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv  = v.texcoord;
				return o;
			}

			float4 frag(v2f_img i) : SV_Target{
				float depthValue = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv.xy);
				float currentDepthValue = SAMPLE_DEPTH_TEXTURE(_CurrentDepthTexture, i.uv.xy);

				bool hasNewDepth = depthValue < currentDepthValue;
				if (hasNewDepth)
				{
					depthValue = currentDepthValue>0 ? min(depthValue, currentDepthValue) : 1;
				}
				else
				{
					depthValue = currentDepthValue + _RecoverSpeed*_DeltaTime;
				}
				//do not linearize depth for orthographic camera
				return float4(depthValue, 0, 0, 0);
			}
			ENDCG
			}
	}
	Fallback Off
}
