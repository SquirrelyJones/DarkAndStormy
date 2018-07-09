#ifdef SKYBOX
	float4 _LightColor0;
#endif

float CalcFogFalloff( float3 viewDir )
{
	half fogFalloff = 1.0 - saturate( dot( float3(0,1,0), viewDir ) );
	return 1.0 - ( ( 1.0 - fogFalloff * fogFalloff ) * 0.9 );
}

fixed3 CalcFogColor( float3 viewDir, float dist )
{
	#ifdef UNITY_PASS_FORWARDADD
		return float3(0,0,0); 
	#else
		float lightDot = saturate( dot( _WorldSpaceLightPos0.xyz, viewDir ) * 0.5 + 0.5 );
		half3 lightTrans = _LightColor0.xyz * pow( lightDot, 10.0 );
		return unity_FogColor.xyz + lightTrans * saturate( dist * 0.001 );
	#endif
}

half4 FogColorDensity ( float3 worldPos )
{
	float3 viewDir = worldPos - _WorldSpaceCameraPos;
	float dist = length( viewDir );
	viewDir = normalize( viewDir );

	half fogFalloff = CalcFogFalloff( viewDir );

	float fogDensity = 1.0 - saturate( 1.0 / exp( ( dist * unity_FogParams.x * 0.01 ) * ( dist * unity_FogParams.x * 0.01 ) ) ); // Exponential fog!
	fogDensity = min( fogFalloff, fogDensity );

	return half4( CalcFogColor(viewDir, dist) * fogDensity, fogDensity );
}


half4 FogColorDensitySky ( float3 viewDir )
{
	half fogFalloff = CalcFogFalloff( viewDir );
	return half4( CalcFogColor(viewDir, 1000) * fogFalloff, fogFalloff );
}


half3 CalcFogSurface( half3 color, float3 worldPos ){

	half4 fcd = FogColorDensity( worldPos );
	return color * ( 1.0 - fcd.w ) + fcd.xyz;
}