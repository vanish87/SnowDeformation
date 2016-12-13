Shader "Snow/RenderDepthAndObjectHeight" {
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
				float height	: TEXCOORD2;
			};
			
			float _ObjectMinHeight;
			float4x4 _SnowCameraMatrix;

			v2f vert( appdata_full v ) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex); 
				o.height = _ObjectMinHeight;
				return o;
			}

			float4 frag(v2f i) : SV_Target{
				float depthValue = i.pos.z;
				float objectHeight = i.height;
				//do not linearize depth for orthographic camera
				//if (objectHeight > 40) objectHeight = 0;
				return float4(depthValue, objectHeight, 0, 0);
			}
			ENDCG
		}	
	}
	Fallback Off
}
