Shader "Snow/RenderDepth"
{
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 500

		Pass
		{
			ZWrite On ZTest LEqual Cull Off
			CGPROGRAM
			#pragma target 3.0
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			struct v2f
			{
				float4 vertex		: SV_POSITION;
			};

			v2f vert (appdata_full v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				return o;
			}
			float4 frag (v2f i) : SV_Target
			{
				float4 col = float4(0,0,0,0);
				float depthValue = i.vertex.z;
				col.rgba	= depthValue;
				//col.r = depthValue;
				return col;
			}
			ENDCG
		}
	}
}
