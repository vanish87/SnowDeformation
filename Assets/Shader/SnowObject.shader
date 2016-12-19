Shader "Snow/SnowObject"
{
	Properties
	{
		_MainTex("Albedo", 2D) = "white" {}
		_SnowShadeMapTex("Snow Shade Map", 2D) = "white" {}
		_SnowNormalMapTex("Snow Normal Map", 2D) = "white" {}
		_SnowSpecularMapTex("Snow Specular Map", 2D) = "white" {}
		_SnowSpecularNoiseTex("Snow Specular Noise", 2D) = "white" {}
		_SnowSpecularGlitTex("Snow Specular glit", 2D) = "white" {}

		_NormalMapTex("Normal Map", 2D) = "white" {}


		_Snow("Snow Level", Range(0,1)) = 0
		_SnowColor("Snow Color", Color) = (1.0,1.0,1.0,1.0)
		_SnowDirection("Snow Direction", Vector) = (0,1,0)
		_SnowDepth("Snow Depth", Range(0,0.2)) = 0.1
		_Wetness("Wetness", Range(0, 0.5)) = 0.3

		_RefractiveIndex("Frenal Refractive Index", Range(0, 20)) = 1
		_Roughness("Oren Nayar Roughness", Range(0, 1)) = 1
		_BlinnSpecularPower("Blinn Specular Power", Range(0, 200)) = 1

		_Offset("Ratio 1", Vector) = (0.005, -0.006, 0.007, 0.008)
		_NoiseMin("Min ", Float) = 2.5
		_NoiseMax("Max", Float) = 2.51
	}
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
			#include "LightingAndUtility.cginc"
			
			struct v2f
			{
				float4 vertex		: SV_POSITION;
				float4 positionWS	: TEXCOORD1;
				float2 uv			: TEXCOORD2;
				float3 normalWS		: TEXCOORD3;
				float3 tangentWS	: TEXCOORD4;
				float3 bitangentWS	: TEXCOORD5;
			};
	
			sampler2D _MainTex;
			sampler2D _NormalMapTex;
			sampler2D _SnowShadeMapTex;
			sampler2D _SnowNormalMapTex;
			sampler2D _SnowSpecularMapTex;
			sampler2D _SnowSpecularNoiseTex;
			sampler2D _SnowSpecularGlitTex;


			float _Snow;
			float4 _SnowColor;
			float4 _SnowDirection;
			float _SnowDepth;
			float _Wetness;

			float _BlinnSpecularPower;


			v2f vert (appdata_full v)
			{
				v2f o;
				float4 positionWorldSpace = mul(unity_ObjectToWorld, v.vertex);
				//Object to world space is affine transform, the Inverse Transpose Matrix is equal to itself<=>(M-1)T = M
				float4 normalWorldSpace   = mul(unity_ObjectToWorld, v.normal);
				if (dot(normalWorldSpace, _SnowDirection.xyz) >= lerp(1, -1, (_Snow * 2) / 3))
				{
					positionWorldSpace.xyz += float3(0.5, 1, 0.5) * (_SnowDirection.xyz + normalWorldSpace) * _SnowDepth * _Snow * 10;
				}

				o.vertex = mul(UNITY_MATRIX_VP, positionWorldSpace);
				o.positionWS = positionWorldSpace;
				o.uv		= v.texcoord;
				o.normalWS	= normalize(normalWorldSpace);
				o.tangentWS = normalize(mul(unity_ObjectToWorld, v.tangent));
				o.bitangentWS = normalize(cross(o.normalWS, o.tangentWS) * v.tangent.w);
				return o;
			}

			float4 frag (v2f i) : SV_Target
			{
				float4 col;

				float3 N = normalize(i.normalWS);
				float3 T = normalize(i.tangentWS);
				float3 B = normalize(i.bitangentWS);// cross(N, T);
				float3x3 TtoW = float3x3(T, B, N);


				float4 normalMap = tex2D(_SnowNormalMapTex, i.uv * 100);
				float3 normalDir = normalize(UnpackNormal(normalMap));

				float3 normalDirection =  normalize(mul(float4(normalDir,0), TtoW));

				float3 snowNormalWS = normalDirection;
				//snowNormalWS.y += snowSpecularNoise.r;
				//snowNormalWS = i.normalWS;

				half difference = dot(snowNormalWS, _SnowDirection.xyz) - lerp(1, -1, _Snow);
				difference = saturate(difference / _Wetness);

				col = tex2D(_MainTex, i.uv.xy);

				float3 pos_eye = normalize(_WorldSpaceCameraPos - i.positionWS.xyz);
				float3 specColor = float3(1, 1, 1);
				float4 snowShadeColor = tex2D(_SnowShadeMapTex, i.uv);
				float4 snowSpecularColor = tex2D(_SnowSpecularMapTex, i.uv);

				float4 snowSpecularNoise = tex2D(_SnowSpecularNoiseTex, i.uv);
				//not used
				float4 snowSpecularGlit = tex2D(_SnowSpecularGlitTex, i.uv);

				float SpecularNoise = sampleNosie(_SnowSpecularNoiseTex, pos_eye, i.uv);
				col = CalLighting_OrenNayarBlinn(snowNormalWS, i.positionWS.xyz, snowShadeColor, snowSpecularColor, _BlinnSpecularPower);
				if (SpecularNoise > 0)
				{
					col.rgb += 1 * ( SpecularNoise) ;
				}
				// sample texture and return it
				//col.rgb = difference*_SnowColor.rgb*snowShadeColor.rgb + (1 - difference) *col;

				//float depthValue = abs(i.vertex.z);
				//col.a	= depthValue;
				//col.rgb = normalize(i.normalWS.xyz);
				//col.rgb = normalWS;
				return col;
			}
			ENDCG
		}
	}
}
