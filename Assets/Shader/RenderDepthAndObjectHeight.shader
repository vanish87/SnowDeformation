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
				float4 pos			: SV_POSITION;
				float2 heightAndDis	: TEXCOORD2;
			};
			
			float _ObjectMinHeight;
			float3 _ObjectCenter;
			float _DeformationScale;

			float4x4 localScale;

			v2f vert( appdata_full v ) {
				v2f o;
				float Scale = 1.5;
				float4 x = float4(Scale, 0, 0, 0);
				float4 y = float4(0, 1, 0, 0);
				float4 z = float4(0, 0, Scale, 0);
				float4 w = float4(0, 0, 0, 1);

				localScale = float4x4(x, y, z, w);
				v.vertex = mul(localScale, v.vertex);

				float3 posWS = mul(unity_ObjectToWorld, v.vertex);
				float2 disVec =  float2(_ObjectCenter.xz - posWS.xz);
				float dis = length(disVec);

				
				o.pos = UnityObjectToClipPos(v.vertex);
				o.heightAndDis = float2(_ObjectMinHeight, dis);
				return o;
			}

			float4 frag(v2f i) : SV_Target{
				float depthValue = i.heightAndDis.x + ((i.heightAndDis.y * i.heightAndDis.y) * _DeformationScale);
				//depthValue = i.pos.z;
				float objectHeight = i.heightAndDis.x;


				//do not linearize depth for orthographic camera
				//if (objectHeight > 40) objectHeight = 0;
				return float4(depthValue, objectHeight, 0, 0);
			}
			ENDCG
		}	
	}
	Fallback Off
}
