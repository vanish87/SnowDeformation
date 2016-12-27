Shader "Snow/SnowMeshSimple"
{
	Properties
	{
		_MainTex("Snow Albedo", 2D) = "white" {}
		_NormalMapTex("Snow Normal Map", 2D) = "white" {}
		_SnowNormalMapScale("Snow Normal Map Scale",Range(1, 30)) = 1
		_SnowSpecularMapTex("Snow Specular Map", 2D) = "white" {}
		_SnowSpecularNoiseTex("Snow Specular Noise", 2D) = "white" {}
		_Wetness("Wetness", Range(0, 0.5)) = 0.3

		_SnowDirection("Snow Direction", Vector) = (0,1,0)
		_Snow("Snow Level", Range(0,1)) = 0
		_SticknessCos("Stickness Value", Range(0, 1)) = 0.4
		_AccumulationSacle("Accumulation Sacle", Vector) = (0,1,0, 0)

		_DeformationSacle("Deformation Sacle", Range(0, 10)) = 1

		_SnowHeightMap("Snow Deformation Map", 2D) = "black" {}
		_SnowAccumulationMap("Snow Accumulation Map", 2D) = "black" {}

		_RefractiveIndex("Frenal Refractive Index", Range(0, 20)) = 3
		_Roughness("Oren Nayar Roughness", Range(0, 1.1)) = 1
		_BlinnSpecularPower("Blinn Specular Power", Range(0, 500)) = 30

		_ShadingBlendScale("Shading blend scale", Range(0, 1)) = 0.4
		_ShadingEnergyPreserve("Shading Energy Preserve", Range(0, 1)) = 0.4
		_AmbientColor("Ambient Color", Color) = (1, 1, 1, 255)
		_DiffuseShadeColor("Diffuse Shade Color", Color) = (102, 220, 250, 255)


		_Offset("Ratio 1", Vector) = (0.005, -0.006, 0.007, 0.008)
		_NoiseMin("Min ", Float) = 2.5
		_NoiseMax("Max", Float) = 2.5001
	}

	SubShader
	{
		Tags{ "Queue" = "Transparent" "RenderType" = "Transparent" }
		LOD 500
		Blend SrcAlpha OneMinusSrcAlpha // use alpha blending
		//ZWrite Off
		Pass
		{
			Name "DefomationAndAccumulation"

			CGPROGRAM
			#pragma enable_d3d11_debug_symbols
			#pragma target 3.0

			#pragma vertex vert
			#pragma fragment frag
			

			#include "UnityCG.cginc"
			#include "LightingAndUtility.cginc"

			struct appdata
			{
				float4 vertex	: POSITION;
				float4 tangent	: TANGENT;
				float3 normal	: NORMAL;
				float2 uv		: TEXCOORD0;
			};

			struct v2f
			{
				float4 vertex	: SV_POSITION;
				float2 uv		: TEXCOORD0;
				float4 positionWS: TEXCOORD5;
				float3 normalWS		: TEXCOORD2;
				float3 tangentWS	: TEXCOORD3;
				float3 binormalWS	: TEXCOORD4;
				float2 heightMapUV	: TEXCOORD6;
				
				float3 normalObject : NORMAL1;
				float3 Delta		: TEXCOORD1;//x is accumulation height delta/deformation height delta; z is alpha difference
			};


			#include "SnowSharedProperty.cginc"
			sampler2D _MainTex;
			sampler2D _NormalMapTex;
			sampler2D _SnowHeightMap;
			sampler2D _SnowAccumulationMap;

			float4 _MainTex_ST;
			float4 _AccumulationSacle;
			float _DeformationSacle;
			float _SticknessCos;
			
			float4x4 _SnowCameraMatrix;
			float4x4 _SnowAccumulationCameraMatrix;
			float _SnowCameraSize; 
			float _SnowCameraZScale;

			float _EnabldeDeformation;

			v2f vert(appdata v)
			{
				v2f o;
				float4 positionWorldSpace = mul(unity_ObjectToWorld, v.vertex);
				//Object to world space is affine transform, the Inverse Transpose Matrix is equal to itself<=>(M-1)T = M
				float3 normalWorldSpace = mul(unity_ObjectToWorld, v.normal);

				float3 heightUV = TransfromToTextureCoord(positionWorldSpace, _SnowCameraMatrix, _SnowCameraSize);
				float3 accuHeightUV = TransfromToTextureCoord(positionWorldSpace, _SnowAccumulationCameraMatrix, _SnowCameraSize);

				//Extract info from 2 height map textures
				float4 SnowDeformationInfo = tex2Dlod(_SnowHeightMap, float4(heightUV.xy, 0, 0));
				float4 SnowAccumulationInfo = tex2Dlod(_SnowAccumulationMap, float4(accuHeightUV.xy, 0, 0));

				float SnowAccumulationHeight = (1 - SnowAccumulationInfo.a);
				SnowAccumulationHeight = min(SnowAccumulationHeight, 0.7);
				float3 SnowAccumulationNormal = (SnowAccumulationInfo.rgb * 2) - 1;

				float snowHeight = abs(heightUV.z) / _SnowCameraZScale;

				float Delta = max(0, snowHeight - SnowDeformationInfo.r);
				bool HasDeformation = Delta > 0;
				float AccumulationDelta = max(0, SnowAccumulationHeight - snowHeight);
				if (_EnabldeDeformation > 0)
				{
					//first get deformation Height and compare it with snow height, make a deformation
					positionWorldSpace.y -= Delta* _DeformationSacle * _SnowCameraZScale;
					//then add accumulated snow
					positionWorldSpace.y += AccumulationDelta * _DeformationSacle * _SnowCameraZScale * 1.5;
					//if there is no deformation, then try to make a trail
					positionWorldSpace.y += HasDeformation?0: max(0, decodeElevation(SnowDeformationInfo.g));
				}

				//also have deformation delta and elevation dis as a texture coord
				o.Delta.x = lerp(1, 0, Delta * 2);
				o.Delta.y = 0;
				o.Delta.z = AccumulationDelta;
				
				if (AccumulationDelta > 0 && !HasDeformation)
				{
					normalWorldSpace.xyz = BlendNormal(normalWorldSpace.xyz, SnowAccumulationNormal); 
				}
				if (!HasDeformation && decodeElevation(SnowDeformationInfo.g) > 0)
				{
					o.Delta.y = decodeFromColorSpace(SnowDeformationInfo.b);
				}

				o.vertex = mul(UNITY_MATRIX_VP, positionWorldSpace);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.positionWS = positionWorldSpace;
				o.normalWS = normalWorldSpace;
				o.heightMapUV = accuHeightUV.xy;


				o.tangentWS = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				fixed4 final;
				// sample the texture
				fixed4 snowShadeColor = tex2D(_MainTex, i.uv.xy);
				float4 snowSpecularColor = tex2D(_SnowSpecularMapTex, i.uv);
				
				float3 N = normalize(i.normalWS);
				float3 T = normalize(i.tangentWS);
				float3 B = cross(N, T);
				float3x3 TtoW = float3x3(T, B, N);
				float4 normalTS = tex2D(_NormalMapTex, i.uv * _SnowNormalMapScale);
				float3 normalWS = mul(normalize(UnpackNormal(normalTS)), TtoW);
				//normalWS = i.normalWS;

				normalWS = normalize(normalWS);

				//col = tex2D(_SnowAccumulationMap, float2(i.uv.x, i.uv.y)).rgba;
				//float4 positionSnowCamera = mul(_SnowCameraMatrix, i.positionWS);
				//i.Normal = UnpackNormal(tex2D(_Bump, IN.uv_Bump));
				//float Alpha = dot(i.normalVS, _SnowDirection.xyz);
				float difference = dot(normalWS, _SnowDirection.xyz);
				//difference = saturate(difference / _Wetness);
				//final.rgb = difference*_SnowColor.rgb + (1 - difference) *snowShadeColor.rgb;
				//final.rgb = i.normalVS;
				//final.rgb = i.normalObject;
				//final.rgb = dot(i.normalVS, i.normalObject);

				float3 pos_eye = normalize(_WorldSpaceCameraPos - i.positionWS.xyz);
				//snowSpecularColor = float4(0, 0, 1,1);
				//snowShadeColor = float4(1, 1, 1, 1);
				//if(snowSpecularColor.r > 0.5) snowSpecularColor *= 2;
				final = CalLighting_OrenNayarBlinn(normalWS, i.positionWS.xyz, snowShadeColor, snowSpecularColor, _BlinnSpecularPower, difference);

				float SpecularNoise = SampleNosie(_SnowSpecularNoiseTex, pos_eye, i.uv);
				if (SpecularNoise > 0)
				{
					final.rgb = SpecularNoise + 0.8;
				}

				final.rgb *= i.Delta.x;

				if (i.Delta.y > 0.3 && i.Delta.y < 0.7)
				{
					//final.rgb *= clamp((i.Delta.y-0.1) / 0.3, 0, 1);
					float x = (i.Delta.y - 0.3) / 0.4;
					x = 0.9 + (x*0.1);
					final.rgb *= x;
				}
				else
				if(i.Delta.y > 0 && i.Delta.y < 0.3)
				{
					float x = (0.3 - i.Delta.y) / 0.3;
					x = 0.9 + (0.1 * x);
					final.rgb *= x;
				}
				//final.a *= normalWS.y;
				//final.rgb = i.Delta.y;
				//final.rgb = i.Delta.y;// < 1 && i.Delta.y  > 0 ? i.Delta.y : 0;
				//final.rgb *= (cos(4 * PI*i.Delta.y) + 1.25) *0.5;
				//final.a = i.Delta.z * 3;
				//final.a = (1 - i.normalWS.y)>0.1 ? 1 : 0;
				return final;
			}
			
			ENDCG
		}

	}
	FallBack "VertexLit"
}
