Shader "Snow/SnowMeshSimple"
{
	Properties
	{
		_MainTex("Albedo", 2D) = "white" {}
		_SnowColor("Snow Color", Color) = (1.0,1.0,1.0,1.0)
		_Wetness("Wetness", Range(0, 0.5)) = 0.3

		_SnowDirection("Snow Direction", Vector) = (0,1,0)
		_SnowHeight("Snow Height", Range(0, 10)) = 1
		_Snow("Snow Level", Range(0,1)) = 0

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
				float4 positionVS: POSITION1;
				float3 normalVS : NORMAL0;
				float3 normalWS : TEXCOORD2;
				float3 normalObject : NORMAL1;
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

			float4 CalLighting(float3 normal,
				float3 position, //view_pos
				float4 diffuseAlbedo,
				float3 specularAlbedo,
				float specularPower)
			{
				float3 pos_eye = normalize(-position);

				// Start with a sum of zero. 
				float4 ambient = float4(0.0f, 0.0f, 0.0f, 0.0f);
				float4 litColor = float4(0.0f, 0.0f, 0.0f, 1.0f);
				{
					float4 diffuse = float4(0.0f, 0.0f, 0.0f, 0.0f);
					float4 spec = float4(0.0f, 0.0f, 0.0f, 0.0f);
					float4 light_color = float4(1.0f, 1.0f, 1.0f, 0.0f);
					float3 light_position = float3(0, 1, 0);//view_pos

					float3 light_dir = float3(-1, 1, 1);
					// The vector from the surface to the light.
					float3 pos_light;// = light_position - position;
					pos_light = light_dir;
					pos_light = normalize(pos_light);

					float diffuse_angle = dot(pos_light, normal);//N * Lc
					[flatten]
					if (diffuse_angle > 0.0f)
					{
						float3 refect_vec = reflect(-pos_light, normal);

						float spec_factor = pow(max(dot(refect_vec, pos_eye), 0.0f), specularPower);

						//Cdiff * Clight * (N * Lc)
						diffuse = diffuseAlbedo * light_color * diffuse_angle;
						//diffuse = light_color * diffuse_angle;
						//pow(R*V, alpha) * Cspec * Clight * (N * Lc)
						spec = spec_factor * float4(specularAlbedo, 1.0f) * light_color * diffuse_angle;
					}

					float4 acc_color = (ambient + diffuse + spec);
					litColor = litColor + acc_color;
				}
				return litColor;
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
					Delta = max(SnowMeshHeight - SnowAccumulationHeight, 0);
					if (dot(SnowAccumulationNormal, _SnowDirection) >  0.4/*cos(30)*/)
					{
						positionWorldSpace.y += Delta* _SnowHeight;
						positionWorldSpace.xyz += SnowAccumulationNormal.xyz * float3(1.5, 1, 1.5) * _SnowDirection;
						//normalWorldSpace = SnowAccumulationNormal;
					}
					//else
					{
						//normalWorldSpace = SnowAccumulationNormal;
					}

					o.Delta.x = clamp(-Delta / 25, 0, 0.5);
					//blend object normal and snow mesh normal
					normalWorldSpace = normalize(SnowAccumulationNormal + normalWorldSpace);

					//defines alpha chanel
					o.Delta.y = (dot(SnowAccumulationNormal, _SnowDirection.xyz) + 1) * 0.5;

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

					o.Delta.x = clamp(Delta / 25, -0.5, 0.5);
					o.Delta.y = (dot(normalWorldSpace, _SnowDirection.xyz) + 1) * 0.5;
				}

				o.vertex = mul(UNITY_MATRIX_VP, positionWorldSpace);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.normalVS = mul(UNITY_MATRIX_V, normalWorldSpace);
				o.normalWS = SnowAccumulationNormal;
				o.positionVS = mul(UNITY_MATRIX_V, positionWorldSpace);
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				fixed4 final;
				// sample the texture
				fixed4 textureCol = tex2D(_MainTex, i.uv.xy);
				//col = tex2D(_SnowAccumulationMap, float2(i.uv.x, i.uv.y)).rgba;
				//float4 positionSnowCamera = mul(_SnowCameraMatrix, i.positionWS);
				//i.Normal = UnpackNormal(tex2D(_Bump, IN.uv_Bump));
				float Alpha = dot(i.normalVS, _SnowDirection.xyz);
				float difference = dot(i.normalWS, _SnowDirection.xyz);
				//difference = saturate(difference / _Wetness);
				final.rgb = difference*_SnowColor.rgb + (1 - difference) *textureCol.rgb;
				//final.rgb = i.normalVS;
				//final.rgb = i.normalObject;
				//final.rgb = dot(i.normalVS, i.normalObject);

				float3 specColor = float3(1, 1, 1);
				final = CalLighting(i.normalVS, i.positionVS, textureCol, specColor, 200);
				//col.rgb = i.Delta.x/10;// i.Delta.y > 0.5 ? 0 : 1; //((i.Delta / 10) + 1) * 0.5;
				//final.rgb = textureCol.xyz;
				//final.rgb = i.normalWS;
				//final.rgb = i.Delta.x;
				final.rgb *= 1-i.Delta.x;
				final.a = i.Delta.y * 2;
				//final.rgb = difference;
				return final;
			}
			
			ENDCG
		}

	}
	FallBack "VertexLit"
}
