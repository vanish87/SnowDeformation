Shader "Snow/SnowMeshSimple"
{
	Properties
	{
		_MainTex("Albedo", 2D) = "white" {}

		_SnowDirection("Snow Direction", Vector) = (0,1,0)
		_CurrentSnowHeight("Current Snow Height", Range(0, 10)) = 3

		_MaxHeightDelta("Max Height Delta", Range(3, 100)) = 20

		_DeformationSacle("Deformation Sacle", Range(0, 10)) = 1
		_SnowHeightMap("Snow Height Map", 2D) = "black" {}
		_SnowAccumulationMap("Snow Accumulation Map", 2D) = "black" {}

		_Snow("Snow Level", Range(0,1)) = 0
		_SnowColor("Snow Color", Color) = (1.0,1.0,1.0,1.0)
		_SnowDepth("Snow Depth", Range(0,0.2)) = 0.1
		_Wetness("Wetness", Range(0, 0.5)) = 0.3

		_SnowCameraSize("Snow Mesh Size",Range(0,100)) = 25
		_SnowCameraZScale("Snow Camera Z Scale",Range(0,100)) = 50

	}

	SubShader
	{
		Tags{ "RenderType" = "Opaque" }
		LOD 500


		// ------------------------------------------------------------------
		//  Base forward pass (directional light, emission, lightmaps, ...)
		Pass
		{
			Name "Defomation"

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
			};

			sampler2D _MainTex;
			sampler2D _SnowHeightMap;
			sampler2D _SnowAccumulationMap;
			float4 _MainTex_ST;
			float4 _SnowDirection;
			float4 _SnowColor;
			float _Snow;
			float _CurrentSnowHeight;
			float _DeformationSacle;
			float _SnowDepth;
			float _Wetness;

			float _MaxHeightDelta;

			float4x4 _SnowCameraMatrix;
			float4x4 _SnowAccumulationCameraMatrix;
			float _SnowCameraSize; 
			float _SnowCameraZScale;

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

			float4 SampleTexture(sampler2D TextureSampler, float4 TextureUV)
			{
				float4 TotalX = float4(0,0,0,0);
				float4 TotalY = float4(0,0,0,0);

				float WeightArray[5] = { 0.005, 0.2 , 0.5, 0.2, 0.005};
				for (int i = -2; i < 3; ++i)
				{
					float4 NewUV = float4(TextureUV.x + (0.01*i), TextureUV.yzw);
					float4 Value = tex2Dlod(TextureSampler, NewUV) ;
					//Value.x *= WeightArray[i + 2];
					TotalX += Value;
				}
				TotalX /= 5;
				for (int i = -2; i < 3; ++i)
				{
					float4 NewUV = float4(TextureUV.x, TextureUV.y + (0.01*i), TextureUV.zw);
					float4 Value = tex2Dlod(TextureSampler, NewUV)* WeightArray[i + 2];
					//Value.y *= WeightArray[i + 2];
					TotalY += Value;
				}
				TotalY /= 5;

				float4 Total = float4(TotalX.x, TotalY.y, TotalX.zw);

				return Total;
			}

			v2f vert(appdata v)
			{
				v2f o;
				float4 positionWorldSpace = mul(unity_ObjectToWorld, v.vertex);
				float3 normalWorldSpace = mul(unity_ObjectToWorld, v.normal);

				float3 heightUV		= TransfromToTextureCoord(positionWorldSpace, _SnowCameraMatrix, _SnowCameraSize);
				float3 accuheightUV = TransfromToTextureCoord(positionWorldSpace, _SnowAccumulationCameraMatrix, _SnowCameraSize);

				//heightUV.y = -heightUV.y;
				float  SnowDeformationHeight = tex2Dlod(_SnowHeightMap, float4(heightUV.xy, 0, 0)).r * _SnowCameraZScale;
				float4 SnowAccumulationInfo  = tex2Dlod(_SnowAccumulationMap, float4(accuheightUV.xy, 0, 0));

				float SnowAccumulationHeight  = SnowAccumulationInfo.a * _SnowCameraZScale;
				float3 SnowAccumulationNormal = SnowAccumulationInfo.rgb;

				float SnowMeshHeight = abs(heightUV.z);

				bool IsSnowCovered = SnowAccumulationHeight > 0;

				float Delta = 0;

				if (IsSnowCovered)
				{
					Delta = max(SnowMeshHeight - SnowAccumulationHeight, 0); 
					float RealAccumulationHeight = 25 - SnowAccumulationHeight;
					float RealMeshHeight = _SnowCameraZScale - SnowMeshHeight;
					//SnowAccumulationHeight = RealAccumulationHeight;
				}
				else
				{
					Delta = max(SnowMeshHeight - SnowDeformationHeight, 0);
				}
				
				//To modify vertex and add snow deformation to this object
				if (Delta < _MaxHeightDelta)
				{ 
					if(SnowDeformationHeight > 0 && SnowDeformationHeight < _SnowCameraZScale)
					{
						positionWorldSpace.y -= Delta* _DeformationSacle;
					}
					else
					if (IsSnowCovered)
					{
						if (dot(SnowAccumulationNormal, _SnowDirection) >  0.86)
						{
							positionWorldSpace.y += Delta* _DeformationSacle;
							positionWorldSpace.xyz += SnowAccumulationNormal.xyz * float3(0.5, 1, 0.5) * _SnowDirection;
							normalWorldSpace = SnowAccumulationNormal;
						}
					}
				}
				//positionWorldSpace.y = SnowDeformationHeight;
				//positionWorldSpace.y = SnowAccumulationHeight;


				o.vertex = mul(UNITY_MATRIX_VP, positionWorldSpace);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				normalWorldSpace = SnowAccumulationNormal;
				o.normalWS = normalWorldSpace;
				o.positionWS = positionWorldSpace;
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				// sample the texture
				//_SnowHeightMap _MainTex

				fixed4 col = tex2D(_MainTex, float2(i.uv.x, i.uv.y));
				//col = tex2D(_SnowAccumulationMap, float2(i.uv.x, i.uv.y)).rgba;
				float4 positionSnowCamera = mul(_SnowCameraMatrix, i.positionWS);
				//i.Normal = UnpackNormal(tex2D(_Bump, IN.uv_Bump));
				half difference = dot(i.normalWS, _SnowDirection.xyz) - lerp(1,-1,_Snow);
				difference = saturate(difference / _Wetness);
				col.rgb = difference*_SnowColor.rgb + (1 - difference) *col;
				col.a = col.a;
				return col;
			}
			ENDCG
		}

	}
	FallBack "VertexLit"
}
