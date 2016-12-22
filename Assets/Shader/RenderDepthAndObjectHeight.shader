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

			float3 _ObjectCenter;
			float _ObjectMinHeight;
			float _DeformationScale;
			float _ElevationTrailScale;

			float4x4 localScale;

			v2f vert( appdata_full v ) {
				v2f o;
				//first scale object on xz plane to calculate trail elevation later in frag shader.
				//this _ElevationTrailScale is used to define the area where Trail will be rendered,
				float Scale = (0.5 - _ObjectMinHeight) * 20;// _ElevationTrailScale;
				float4 x = float4(Scale, 0, 0, 0);
				float4 y = float4(0, 1, 0, 0);
				float4 z = float4(0, 0, Scale, 0);
				float4 w = float4(0, 0, 0, 1);

				localScale = float4x4(x, y, z, w);
				v.vertex = mul(localScale, v.vertex);

				float3 posWS = mul(unity_ObjectToWorld, v.vertex);
				//object deformation height is defiend by the distance between object center and the vertex to be rendered in xz plane.
				float2 disVec =  float2(_ObjectCenter.xz - posWS.xz);
				float dis = length(disVec);
				
				o.pos = UnityObjectToClipPos(v.vertex);
				o.heightAndDis = float2(_ObjectMinHeight, dis);
				return o;
			}

			float4 frag(v2f i) : SV_Target{
				//calculate deformation height with distance: height = obj_min_height + dis * dis * _DeformationScale;
				//note this height is in camera space
				float deformationHeight = i.heightAndDis.x + ((i.heightAndDis.y * i.heightAndDis.y) * _DeformationScale);
				//note this objectHeight is in camera space
				float objectHeight = i.heightAndDis.x;

				return float4(deformationHeight, objectHeight, 0, 0);
			}
			ENDCG
		}	
	}
	Fallback Off
}
