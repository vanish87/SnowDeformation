Shader "Snow/RenderNormalAndDepth"
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
				float3 normalWS		: NORMAL1;
			};

			v2f vert (appdata_full v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.normalWS	 = mul(unity_ObjectToWorld, v.normal);
				return o;
			}
			float4 frag (v2f i) : SV_Target
			{
				float4 col;
				float depthValue = i.vertex.z;
				col.a	= depthValue;
				col.rgb = (normalize(i.normalWS.xyz) + 1) * 0.5;
				//col.r = depthValue<1? depthValue:0;
				return col;
			}
			ENDCG
		}
	}
}
