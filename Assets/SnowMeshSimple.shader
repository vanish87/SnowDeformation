Shader "Snow/SnowMeshSimple"
{
	Properties
	{
		_MainTex("Albedo", 2D) = "white" {}
		_SnowColor("Snow Color", Color) = (1.0,1.0,1.0,1.0)
		_Wetness("Wetness", Range(0, 0.5)) = 0.3

		_SnowDirection("Snow Direction", Vector) = (0,1,0)
		_SnowHeight("Snow Height", Range(0, 10)) = 3
		_Snow("Snow Level", Range(0,1)) = 0

		_DeformationSacle("Deformation Sacle", Range(0, 10)) = 1
		_MaxHeightDelta("Max Height Delta", Range(3, 100)) = 20

		_SnowHeightMap("Snow Deformation Map", 2D) = "black" {}
		_SnowAccumulationMap("Snow Accumulation Map", 2D) = "black" {}

	}

	SubShader
	{
		Tags{ "RenderType" = "Opaque" }
		LOD 500

		Pass
		{
			Name "DefomationAndAccumulation"

			CGPROGRAM
			#pragma enable_d3d11_debug_symbols
			#pragma target 3.0

			#pragma vertex vert
			#pragma fragment frag
			

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex	: POSITION;
				float3 normal	: NORMAL;
				float2 uv		: TEXCOORD0;
			};

			struct v2f
			{
				float4 vertex	: SV_POSITION;
				float2 uv		: TEXCOORD0;
				float4 positionWS: POSITION1;
				float3 normalWS : NORMAL0;
				float2  Delta : TEXCOORD1;
			};

			sampler2D _MainTex;
			sampler2D _SnowHeightMap;
			sampler2D _SnowAccumulationMap;
			float4 _MainTex_ST;
			float4 _SnowDirection;
			float4 _SnowColor;
			float _Snow;
			float _SnowHeight;
			float _DeformationSacle;
			float _Wetness;

			float _MaxHeightDelta;

			float4x4 _SnowCameraMatrix;
			float4x4 _SnowAccumulationCameraMatrix;
			float _SnowCameraSize; 
			float _SnowCameraZScale;

			//calculate view space coordinate and scale xy to UV coornidates.
			float3 TransfromToTextureCoord(float4 Position, float4x4 CameraMatirx, float CameraScale)
			{
				float3 heightUV;
				float4 positionSnowCamera = mul(CameraMatirx, Position);
				heightUV.x = positionSnowCamera.x / CameraScale;
				heightUV.y = positionSnowCamera.y / CameraScale;
				heightUV.z = positionSnowCamera.z;
				heightUV.x = clamp((1 + heightUV.x) * 0.5, 0.0, 1.0);
				heightUV.y = clamp((heightUV.y + 1) * 0.5, 0.0, 1.0);
				return heightUV;
			}

			v2f vert(appdata v)
			{
				v2f o;
				float4 positionWorldSpace = mul(unity_ObjectToWorld, v.vertex);
				//Object to world space is affine transform, the Inverse Transpose Matrix is equal to itself<=>(M-1)T = M
				float3 normalWorldSpace = mul(unity_ObjectToWorld, v.normal);

				float3 heightUV		= TransfromToTextureCoord(positionWorldSpace, _SnowCameraMatrix, _SnowCameraSize);
				float3 accuHeightUV = TransfromToTextureCoord(positionWorldSpace, _SnowAccumulationCameraMatrix, _SnowCameraSize);

				//Extrac info from 2 height map texture
				float  SnowDeformationHeight = tex2Dlod(_SnowHeightMap, float4(heightUV.xy, 0, 0)).r * _SnowCameraZScale;
				float4 SnowAccumulationInfo  = tex2Dlod(_SnowAccumulationMap, float4(accuHeightUV.xy, 0, 0));

				float SnowAccumulationHeight  = SnowAccumulationInfo.a * _SnowCameraZScale;
				float3 SnowAccumulationNormal = SnowAccumulationInfo.rgb;

				float SnowMeshHeight = abs(heightUV.z);

				bool IsSnowCovered = SnowAccumulationHeight > 0;

				float Delta = 0;

				//caculate snow height delta
				if (IsSnowCovered)
				{
					if (dot(SnowAccumulationNormal, _SnowDirection) >  0.86/*cos(30)*/)
					{
						Delta = max(SnowMeshHeight - SnowAccumulationHeight, 0);
						positionWorldSpace.y += Delta* _SnowHeight;
						positionWorldSpace.xyz += SnowAccumulationNormal.xyz * float3(0.5, 1, 0.5) * _SnowDirection;
						normalWorldSpace = SnowAccumulationNormal;
						o.Delta.x = Delta;
					}
					else
					{
						//normalWorldSpace = SnowAccumulationNormal;
					}
					o.Delta.y = dot(SnowAccumulationNormal, _SnowDirection);
				}
				else
				{
					if (SnowDeformationHeight > 0 && SnowDeformationHeight < _SnowCameraZScale)
					{
						//To modify vertex and add snow deformation to this object
						Delta = max(SnowMeshHeight - SnowDeformationHeight, 0);
						positionWorldSpace.y -= Delta* _DeformationSacle;
						o.Delta.xy = -Delta;
					}
				}

				o.vertex = mul(UNITY_MATRIX_VP, positionWorldSpace);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.normalWS = normalWorldSpace;
				o.positionWS = positionWorldSpace;
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				// sample the texture
				fixed4 col = fixed4(1,0,0,1);// tex2D(_MainTex, float2(i.uv.x, i.uv.y));
				//col = tex2D(_SnowAccumulationMap, float2(i.uv.x, i.uv.y)).rgba;
				float4 positionSnowCamera = mul(_SnowCameraMatrix, i.positionWS);
				//i.Normal = UnpackNormal(tex2D(_Bump, IN.uv_Bump));
				half difference = dot(i.normalWS, _SnowDirection.xyz) - lerp(1,-1, _Snow);
				difference = saturate(difference / _Wetness);
				col.rgb = difference*_SnowColor.rgb + (1 - difference) *col;
				col.rgb = i.normalWS;
				//col.rgb = i.Delta.y;// i.Delta.y > 0.5 ? 0 : 1; //((i.Delta / 10) + 1) * 0.5;
				col.a = col.a;
				//col.a = i.Delta.y > 1 ? 0:1;
				return col;
			}
			ENDCG
		}

	}
	FallBack "VertexLit"
}
