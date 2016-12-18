Shader "Custom/GlitterShader2"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
	_NoiseTex("Noise Texture", 2D) = "white" {}
	_Offset("Ratio 1", Vector) = (0.005, -0.006, 0.007, 0.008)
		_Min("Min ", Float) = 2.5
		_Max("Max", Float) = 2.51

	}
		SubShader
	{
		Tags{ "RenderType" = "Opaque" }
		LOD 100

		Pass
	{
		CGPROGRAM
#pragma vertex vert
#pragma fragment frag

#include "UnityCG.cginc"

		struct appdata
	{
		float4 vertex : POSITION;
		float2 uv : TEXCOORD0;
	};

	struct v2f
	{
		float2 uv : TEXCOORD0;
		float2 uv2: TEXCOORD1;
		float4 vertex : SV_POSITION;
	};

	float4 _Offset;
	float _Min;
	float _Max;

	sampler2D _MainTex;
	float4 _MainTex_ST;

	sampler2D _NoiseTex;
	float4 _NoiseTex_ST;

	v2f vert(appdata v)
	{
		v2f o;
		o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
		o.uv = TRANSFORM_TEX(v.uv, _MainTex);
		o.uv2 = TRANSFORM_TEX(v.uv, _NoiseTex);
		return o;
	}

	fixed4 frag(v2f i) : SV_Target
	{
		// sample the texture
		fixed4 col = tex2D(_MainTex, i.uv);
	float p1 = tex2D(_NoiseTex, i.uv2 + float2(0             , _WorldSpaceCameraPos.x * _Offset.x)).r;
	float p2 = tex2D(_NoiseTex, i.uv2 + float2(0             , _WorldSpaceCameraPos.y * _Offset.y)).g;
	float p3 = tex2D(_NoiseTex, i.uv2 + float2(_WorldSpaceCameraPos.x * _Offset.z, 0)).b;
	float p4 = tex2D(_NoiseTex, i.uv2 + float2(_WorldSpaceCameraPos.y * _Offset.w, 0)).a;
	float sum = p1 + p2 + p3 + p4;
	if (sum > _Min && sum < _Max) {
		col = fixed4(1,1,1,1);
	}

	return col;
	}
		ENDCG
	}
	}
}