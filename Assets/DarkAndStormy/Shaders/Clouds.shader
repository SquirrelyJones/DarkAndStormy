Shader "Skybox/Clouds"
{
	Properties
	{
		[NoScaleOffset] _CloudTex1 ("Clouds 1", 2D) = "white" {}
		[NoScaleOffset] _DistortTex1 ("Distort Tex 1", 2D) = "grey" {}
		_Tiling1("Tiling 1", Vector) = (1,1,0,0)

		[NoScaleOffset] _CloudTex2 ("Clouds 2", 2D) = "white" {}
		[NoScaleOffset] _Tiling2("Tiling 2", Vector) = (1,1,0,0)
		_Cloud2Amount ("Cloud 2 Amount", float) = 0.5

		[NoScaleOffset] _WaveTex ("Wave", 2D) = "white" {}
		_TilingWave("Tiling Wave", Vector) = (1,1,0,0)
		_WaveAmount ("Wave Amount", float) = 0.5
		_WaveDistort ("Wave Distort", float) = 0.05

		_CloudScale ("Clouds Scale", float) = 1.0
		_CloudBias ("Clouds Bias", float) = 0.0

		[NoScaleOffset] _ColorTex ("Color Tex", 2D) = "white" {}
		_TilingColor("Tiling Color", Vector) = (1,1,0,0)
		_ColPow ("Color Power", float) = 1
		_ColFactor ("Color Factor", float) = 1

		_DistSpeed ("Distort Speed", float) = 1
		_DistAmount ("Distort Amount", float) = 1

		_Color ("Color", Color) = (1.0,1.0,1.0,1)
		_Color2 ("Color2", Color) = (1.0,1.0,1.0,1)

		_CloudDensity ("Cloud Density", float) = 5.0

		_BumpOffset ("BumpOffset", float) = 0.1
		_Steps ("Steps", float) = 10

		_CloudHeight ("Cloud Height", float) = 100
		_Scale ("Scale", float) = 10

		_Speed ("Speed", float) = 1

		_LightSpread ("Light Spread PFPF", Vector) = (2.0,1.0,50.0,3.0)
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			#define SKYBOX
			#include "FogInclude.cginc"

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 worldPos: TEXCOORD1; 
			};

			sampler2D _CloudTex1;
			sampler2D _DistortTex1;
			sampler2D _CloudTex2;
			sampler2D _WaveTex;

			float4 _Tiling1;
			float4 _Tiling2;
			float4 _TilingWave;

			float _CloudScale;
			float _CloudBias;

			float _Cloud2Amount;
			float _WaveAmount;
			float _WaveDistort;
			float _DistSpeed;
			float _DistAmount;

			sampler2D _ColorTex;
			float4 _TilingColor;

			float4 _Color;
			float4 _Color2;

			float _CloudDensity;

			float _BumpOffset;
			float _Steps;

			float _CloudHeight;
			float _Scale;

			float _Speed;

			float4 _LightSpread;

			float _ColPow;
			float _ColFactor;
			
			v2f vert (appdata_full v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.texcoord.xy;

				float3 worldPos = mul( unity_ObjectToWorld, v.vertex ).xyz;
				o.worldPos = worldPos;

				return o;
			}

			float rand3( float3 co ){
			    return frac( sin( dot( co.xyz ,float3(17.2486,32.76149, 368.71564) ) ) * 32168.47512);
			}

			float rand2( float2 co){
				return frac( sin( dot( co.xy ,float2(17.2486,32.76149) ) ) * 32168.47512);
			}

			half4 SampleClouds ( float3 uv, float4 tiling1, float4 tiling2, float4 tiling3, float4 tiling4, half3 sunTrans, half densityAdd ){

				// wave distortion
				float3 coordsWave = float3( uv.xy * tiling3.xy + tiling3.zw, 0.0 );
				half3 wave = tex2Dlod( _WaveTex, float4(coordsWave.xy,0,0) ).xyz;

				// first cloud layer
				float2 coords1 = uv.xy * tiling1.xy + tiling1.zw + ( wave.xy - 0.5 ) * _WaveDistort;
				half4 clouds = tex2Dlod( _CloudTex1, float4(coords1.xy,0,0) );
				half3 cloudsFlow = tex2Dlod( _DistortTex1, float4(coords1.xy,0,0) ).xyz;
				cloudsFlow.xy -= 0.5;

				// set up time for second clouds layer
				float speed = _DistSpeed * _Speed * 10;
				float dist = _DistAmount;
				float timeFrac1 = frac( _Time.y * speed );
				float timeFrac2 = frac( _Time.y * speed + 0.5 );
				float timeLerp  = abs( timeFrac1 * 2.0 - 1.0 );
				timeFrac1 = ( timeFrac1 * dist ) - ( 0.5 * dist );
				timeFrac2 = ( timeFrac2 * dist ) - ( 0.5 * dist );

				// second cloud layer uses flow map
				float2 coords2 = coords1 * tiling2.xy + tiling2.zw;
				half4 clouds2 = tex2Dlod( _CloudTex2, float4(coords2.xy + cloudsFlow.xy * timeFrac1,0,0)  );
				half4 clouds2b = tex2Dlod( _CloudTex2, float4(coords2.xy + cloudsFlow.xy * timeFrac2 + 0.5,0,0)  );
				clouds2 = lerp( clouds2, clouds2b, timeLerp);
				clouds += ( clouds2 - 0.5 ) * _Cloud2Amount * cloudsFlow.z;

				// add wave to cloud height
				clouds.w += ( wave.z - 0.5 ) * _WaveAmount;

				// scale and bias clouds because we are adding lots of stuff together
				// and the values cound go outside 0-1 range
				clouds.w = clouds.w * _CloudScale + _CloudBias;

				// overhead light color
				float3 coords4 = float3( uv.xy * tiling4.xy + tiling4.zw, 0.0 );
				half4 cloudColor = tex2Dlod( _ColorTex, float4(coords4.xy,0,0)  );

				// cloud color based on density
				half cloudColorMask = 1.0 - saturate( clouds.w );
				cloudColorMask = pow( cloudColorMask, _ColPow );
				clouds.xyz *= lerp( _Color2.xyz, _Color.xyz * cloudColor.xyz * _ColFactor, cloudColorMask );

				// subtract alpha based on height
				half cloudSub = 1.0 - uv.z;
				clouds.w = clouds.w - cloudSub * cloudSub;// * cloudSub;

				// multiply density
				clouds.w = saturate( clouds.w * _CloudDensity + densityAdd );

				// add extra density
				clouds.w = saturate( clouds.w + densityAdd );

				// add Sunlight
				clouds.xyz += sunTrans * cloudColorMask;

				// premultiply alpha
				clouds.xyz *= clouds.w;

				return clouds;
			}

			fixed4 frag (v2f IN) : SV_Target
			{

				float3 viewDir = normalize( IN.worldPos - _WorldSpaceCameraPos );

				// Add a little bit of up vector towards the horizon
				// this will give the illusion of a curved sky and keep the clouds 
				// from being a flat plane off into the distance
				float3 traceDir = normalize( viewDir + float3(0,lerp(0.1,0,viewDir.y),0) );

				float3 worldPos = _WorldSpaceCameraPos + traceDir * ( ( (_CloudHeight * _Scale ) - _WorldSpaceCameraPos.y ) / max( traceDir.y, 0.00001) );
				float3 uv = float3( worldPos.xz * 0.01, 0 ) *  1.0 / _Scale;

				float oneOverScale = 1.0 / _Scale;
				float4 tiling1 = float4( _Tiling1.xy, _Tiling1.zw * _Speed * _Time.y );
				float4 tiling2 = float4( _Tiling2.xy, _Tiling2.zw * _Speed * _Time.y );
				float4 tiling3 = float4( _TilingWave.xy, _TilingWave.zw * _Speed * _Time.y );
				float4 tiling4 = float4( _TilingColor.xy, _TilingColor.zw * _Speed * _Time.y );

				half viewFalloff = pow( 1.0 - saturate( viewDir.y ), 5 ) * 5.0 + 1.0;

				float lightDot = saturate( dot( _WorldSpaceLightPos0, viewDir ) * 0.5 + 0.5 );
				half3 lightTrans = _LightColor0.xyz * ( pow(lightDot,_LightSpread.x) * _LightSpread.y + pow(lightDot,_LightSpread.z) * _LightSpread.w );
				half3 lightTransTotal = lightTrans * viewFalloff;

				half4 fogColorDensity = FogColorDensitySky(viewDir);

				half3 uvStep = half3(_BumpOffset * ( 1.0 / traceDir.y),_BumpOffset * ( 1.0 / traceDir.y),1.0) * half3( traceDir.xz,1.0) * ( 1.0 / _Steps );
				uv += uvStep * rand3( IN.worldPos + _SinTime.w );

				half4 accColor = fogColorDensity;
				half4 clouds = 0;
				[loop]for( int j = 0; j < _Steps; j++ ){
					// we filled the alpha
					if( accColor.w >= 1.0 ) { break; }

					uv += uvStep;
					clouds = SampleClouds(uv, tiling1, tiling2, tiling3, tiling4, lightTransTotal, 0.0 );
					accColor += clouds * ( 1.0 - accColor.w );
				}

				// one last sample to fill gaps
				uv += uvStep;
				clouds = SampleClouds(uv, tiling1, tiling2, tiling3, tiling4, lightTransTotal, 1.0 );
				accColor += clouds * ( 1.0 - accColor.w );

				half4 finalColor = accColor;

				return finalColor;
			}
			ENDCG
		}
	}
}
