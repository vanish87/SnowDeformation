Shader "Snow/SnowMeshSimple"
{
	Properties
	{
		_MainTex("Albedo", 2D) = "white" {}
		_NormalMapTex("Normal Map", 2D) = "white" {}
		_SnowColor("Snow Color", Color) = (1.0,1.0,1.0,1.0)
		_Wetness("Wetness", Range(0, 0.5)) = 0.3

		_SnowDirection("Snow Direction", Vector) = (0,1,0)
		_SnowHeight("Snow Height", Range(0, 10)) = 1
		_Snow("Snow Level", Range(0,1)) = 0
		_SticknessCos("Stickness Value", Range(0, 1)) = 0.4
		_AccumulationSacle("Accumulation Sacle", Vector) = (0,1,0, 0)

		_DeformationSacle("Deformation Sacle", Range(0, 10)) = 1
		_MaxHeightDelta("Max Height Delta", Range(3, 100)) = 20

		_SnowHeightMap("Snow Deformation Map", 2D) = "black" {}
		_SnowAccumulationMap("Snow Accumulation Map", 2D) = "black" {}

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
			#include "lighting.cginc"

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
				//float3 normalVS : NORMAL0;
				float3 normalWS		: TEXCOORD2;
				float3 tangentWS	: TEXCOORD3;
				float3 binormalWS	: TEXCOORD4;
				float2 heightMapUV	: TEXCOORD6;
				
				float3 normalObject : NORMAL1;
				float3 Delta		: TEXCOORD1;//x is accumulation height delta/deformation height delta; z is alpha difference
			};

			sampler2D _MainTex;
			sampler2D _NormalMapTex;
			sampler2D _SnowHeightMap;
			sampler2D _SnowAccumulationMap;
			float4 _MainTex_ST;
			float4 _SnowDirection;
			float4 _AccumulationSacle;
			float4 _SnowColor;
			float _Snow;
			float _SnowHeight;
			float _DeformationSacle;
			float _Wetness;

			float _SticknessCos;

			float _MaxHeightDelta;

			float4x4 _SnowCameraMatrix;
			float4x4 _SnowAccumulationCameraMatrix;
			float _SnowCameraSize; 
			float _SnowCameraZScale;

			

			float Fresnel(float Bias, float Scale, float Power, float3 PositionWS, float3 NormalWS)
			{
				float3 I = normalize(PositionWS - _WorldSpaceCameraPos);
				float3 Reflect = reflect(I, NormalWS);
				float ReflectionCoefficient = Bias + Scale*pow(1 + dot(I, NormalWS), Power);
				return ReflectionCoefficient;
			}

			float4 CalFresnal(float4 ColorReflection, float4 ColorRefraction, float3 PositionWS, float3 NormalWS)
			{
				float4 FinalColor;
				float reflectionFactor = Fresnel(1, 1, 2, PositionWS, NormalWS);
				FinalColor = lerp(ColorRefraction, ColorReflection, reflectionFactor);
				return FinalColor;
			}

					

			v2f vert(appdata v)
			{
				v2f o;
				float4 positionWorldSpace = mul(unity_ObjectToWorld, v.vertex);
				//Object to world space is affine transform, the Inverse Transpose Matrix is equal to itself<=>(M-1)T = M
				float3 normalWorldSpace = mul(unity_ObjectToWorld, v.normal);

				float3 heightUV		= TransfromToTextureCoord(positionWorldSpace, _SnowCameraMatrix, _SnowCameraSize);
				float3 accuHeightUV = TransfromToTextureCoord(positionWorldSpace, _SnowAccumulationCameraMatrix, _SnowCameraSize);

				//Extract info from 2 height map texture
				float  SnowDeformationHeight = tex2Dlod(_SnowHeightMap, float4(heightUV.xy, 0, 0)).r * _SnowCameraZScale;
				float  SnowObjectHeight = tex2Dlod(_SnowHeightMap, float4(heightUV.xy, 0, 0)).g;
				float  SnowElevationHeight = tex2Dlod(_SnowHeightMap, float4(heightUV.xy, 0, 0)).b;
				float4 SnowAccumulationInfo  = tex2Dlod(_SnowAccumulationMap, float4(accuHeightUV.xy, 0, 0));

				float SnowAccumulationHeight  = SnowAccumulationInfo.a * _SnowCameraZScale;
				float3 SnowAccumulationNormal = SnowAccumulationInfo.rgb;

				float SnowMeshHeight = abs(heightUV.z);

				bool IsSnowCovered = SnowAccumulationHeight > 0;

				float Delta = 0;

				//caculate snow height delta
				if (IsSnowCovered)
				{
					Delta = min(max(SnowMeshHeight - SnowAccumulationHeight, 0), 2);
					float SnowDifference = dot(SnowAccumulationNormal, _SnowDirection);
					if (SnowDifference>  _SticknessCos)
					{
						positionWorldSpace.y += Delta* _SnowHeight;
						positionWorldSpace.xyz += SnowAccumulationNormal.xyz * _AccumulationSacle.xyz * _SnowDirection;
					}

					o.Delta.x = clamp(Delta / (_SnowCameraZScale * 0.5), 0, 0.5);
					//blend object normal and snow mesh normal
					normalWorldSpace = SnowAccumulationNormal;// normalize(SnowAccumulationNormal + normalWorldSpace);

					//defines alpha chanel
					o.Delta.z = (SnowDifference + 1) * 0.5;

					//debug
					o.normalObject = SnowAccumulationNormal;
				}
				else
				{
					Delta = max(SnowMeshHeight - SnowDeformationHeight, 0);
					if (SnowDeformationHeight > 0 && SnowDeformationHeight < _SnowCameraZScale)
					{
						//To modify vertex and add snow deformation to this object
						positionWorldSpace.y -= Delta* _DeformationSacle;
					}

					o.Delta.x = clamp(-Delta / (_SnowCameraZScale * 0.5), -0.5, 0);
					o.Delta.z = (dot(normalWorldSpace, _SnowDirection.xyz) + 1) * 0.5;
				}
				//positionWorldSpace.y = SnowElevationHeight >0?(1-SnowElevationHeight) * 50 : positionWorldSpace.y;


				o.Delta.y = SnowAccumulationInfo.a;

				o.vertex = mul(UNITY_MATRIX_VP, positionWorldSpace);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.positionWS = positionWorldSpace;
				o.normalWS	 = normalWorldSpace;
				o.heightMapUV = accuHeightUV.xy;
				//o.normalVS = mul(UNITY_MATRIX_V, normalWorldSpace);
				//o.positionVS = mul(UNITY_MATRIX_V, positionWorldSpace);


				o.tangentWS  = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
				//o.binormalWS = normalize(cross(normalWorldSpace, o.tangentWS)	* v.tangent.w); // tangent.w is specific to Unity
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				fixed4 final;
				// sample the texture
				fixed4 textureCol = tex2D(_MainTex, i.uv.xy);
				
				float3 N = normalize(i.normalWS);
				float3 T = normalize(i.tangentWS);
				float3 B = cross(N, T);
				float3x3 TtoW = float3x3(T, B, N);
				float3 normalTS = (tex2D(_NormalMapTex, i.uv.xy).rgb * 2) -1;
				float3 normalWS = mul(normalTS, TtoW);
				normalWS = i.normalWS;

				//col = tex2D(_SnowAccumulationMap, float2(i.uv.x, i.uv.y)).rgba;
				//float4 positionSnowCamera = mul(_SnowCameraMatrix, i.positionWS);
				//i.Normal = UnpackNormal(tex2D(_Bump, IN.uv_Bump));
				//float Alpha = dot(i.normalVS, _SnowDirection.xyz);
				float difference = dot(normalWS, _SnowDirection.xyz);
				//difference = saturate(difference / _Wetness);
				final.rgb = difference*_SnowColor.rgb + (1 - difference) *textureCol.rgb;
				//final.rgb = i.normalVS;
				//final.rgb = i.normalObject;
				//final.rgb = dot(i.normalVS, i.normalObject);

				float3 specColor = float3(1, 1, 1);
				final = CalLighting(normalWS, i.positionWS, textureCol, specColor, 200);
				//col.rgb = i.Delta.x/10;// i.Delta.y > 0.5 ? 0 : 1; //((i.Delta / 10) + 1) * 0.5;
				//final.rgb = textureCol.xyz;
				//final.rgb = i.normalWS;
				//final.rgb = i.Delta.x;
				float ColorScale = 1;
				ColorScale += i.Delta.x;
				final.rgb *= ColorScale;
				//final.a = i.Delta.z * 3;
				//final.rgb = i.Delta.y;
				//final.a = (1 - i.normalWS.y)>0.1 ? 1 : 0;
				return final;
			}
			
			ENDCG
		}

	}
	FallBack "VertexLit"
}
