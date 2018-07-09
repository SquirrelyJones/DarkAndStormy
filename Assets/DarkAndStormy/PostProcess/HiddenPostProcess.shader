Shader "Hidden/PostProcess"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_BloomTex ("Texture", 2D) = "black" {}
		_BloomTex2 ("Texture", 2D) = "black" {}
		_GodRayTex ("Texture", 2D) = "black" {}
		_GodRayTexAlt ("Texture", 2D) = "black" {}

		_BlurTex ("Texture", 2D) = "grey" {}
		_BlurTex2 ("Texture", 2D) = "grey" {}
		_VignetteTex ("Texture", 2D) = "white" {}
	}

	CGINCLUDE
	
	#include "UnityCG.cginc"

	sampler2D	_MainTex;
	float4		_MainTex_ST;
	float4		_MainTex_TexelSize;
	sampler2D_float 	_CameraDepthTexture;
	
	float		_ScreenX;
	float		_ScreenY;
	float2		_OneOverScreenSize;

	sampler2D	_BloomTex;
	sampler2D	_BloomTex2;
	float		_BloomThreshold;
	float		_BloomExtra;
	float		_BloomAmount;
	float		_BlurSpread;
	float4		_BlurDir;

	float3 _ViewDirTL;
	float3 _ViewDirTR;
	float3 _ViewDirBL;
	float3 _ViewDirBR;

	float3 		_SunDir;
	sampler2D	_GodRayTex;
	sampler2D	_GodRayTexAlt;
	int			_GodRaySteps;
	float 		_GodRayLength;
	float 		_GodRayFalloff;
	float 		_GodRayAmount;
	float3 		_GodrayGlow;
	float3 		_GodRayScreenPos;

	float4x4	_CameraVPMatrix;

	//======================================================//
	//					Composit Pass						//
	//======================================================//
	
	struct v2fCompose {
		float4 pos : SV_POSITION;
		float2 uv : TEXCOORD0;
		float2 uv1 : TEXCOORD1;
		float2 uv2 : TEXCOORD2;
	};
	
	//Common Vertex Shader
	v2fCompose vertCompose( appdata_img v )
	{
		v2fCompose o;
		o.pos = UnityObjectToClipPos (v.vertex);

		float2 fixedUV = UnityStereoScreenSpaceUVAdjust(v.texcoord.xy, _MainTex_ST);
		float2 fixedUVFlipped = fixedUV;

		#if UNITY_UV_STARTS_AT_TOP
		if(_MainTex_TexelSize.y<0.0)
			fixedUVFlipped.y = 1.0 - fixedUVFlipped.y;
		#endif

		o.uv = v.texcoord.xy;
		o.uv1 = fixedUV;
		o.uv2 = fixedUVFlipped;

		return o;
	
	} 

	half4 Compose(v2fCompose IN) : SV_Target
	{		

		float2 VignetteUV = IN.uv;
		float2 ScreenUV = IN.uv1;
		float2 ScreenUV2 = IN.uv2;

		half4 Scene = tex2D( _MainTex, ScreenUV );
		half4 GodRayTex = tex2D( _GodRayTex, ScreenUV );	
		half4 BloomTex = tex2D( _BloomTex, ScreenUV2 );
		half4 BloomTex2 = tex2D( _BloomTex2, ScreenUV2 );			

		half4 finalBloom = ( 1.0 - ( 1.0 - saturate( BloomTex ) ) * ( 1.0 - saturate( BloomTex2 ) ) ) * _BloomAmount;
		half4 finalGodRay = GodRayTex * _GodRayAmount;

		// screen all the stuff together
		Scene = 1.0 - ( 1.0 - saturate( Scene ) ) * ( 1.0 - saturate( finalBloom ) ) * ( 1.0 - saturate( finalGodRay ) );		
		Scene.w = 1.0;

		return Scene;
	}
	
	//======================================================//
	//					Mipping Pass						//
	//======================================================//
	
	struct v2fMipping {
		float4 pos : SV_POSITION;
		float2 uv : TEXCOORD0;
		float2 uv1 : TEXCOORD1;
		float2 uv2 : TEXCOORD2;
		float2 uv3 : TEXCOORD3;
		float3 viewDir : TEXCOORD4;
		float2 uvMask : TEXCOORD5;
	};
	
	v2fMipping vertMipping( appdata_img v )
	{
		v2fMipping o;
		o.pos = UnityObjectToClipPos (v.vertex);

		float2 fixedUV = UnityStereoScreenSpaceUVAdjust(v.texcoord.xy, _MainTex_ST);
		float2 uvCoords = fixedUV.xy;
		float2 uvCoordsOrig = v.texcoord.xy;

		o.uvMask = v.texcoord.xy * 2.0 - 1.0;

		float oneOverScreenXY = float2( 1.0 / _ScreenX, 1.0 / _ScreenY);
		
		o.uv = uvCoords + oneOverScreenXY * float2(-0.5,-0.5);
		o.uv1 = uvCoords + oneOverScreenXY * float2(-0.5,0.5);
		o.uv2 = uvCoords + oneOverScreenXY * float2(0.5,-0.5);
		o.uv3 = uvCoords + oneOverScreenXY * float2(0.5,0.5);

		o.viewDir = lerp( lerp( _ViewDirTL, _ViewDirTR, uvCoordsOrig.x ), lerp( _ViewDirBL, _ViewDirBR, uvCoordsOrig.x ), 1.0 - uvCoordsOrig.y );
	
		return o;
	
	} 
	
	half4 Mipping(v2fMipping IN) : SV_Target
	{		
		half4 Scene = tex2D( _MainTex, IN.uv.xy );
		Scene += tex2D( _MainTex, IN.uv1.xy );
		Scene += tex2D( _MainTex, IN.uv2.xy );
		Scene += tex2D( _MainTex, IN.uv3.xy );
		Scene *= 0.25;
	  
		return clamp( Scene, 0.0001, 100.0 );
	}
	
	//======================================================//
	//						Threshold						//
	//				uses mipping vertex data				//
	//======================================================//

	
	half4 Threshold(v2fMipping IN) : SV_Target
	{		
		half4 threshold = half4( _BloomThreshold, _BloomThreshold, _BloomThreshold, 0.0 );

		// sample scenes
		half4 Scene1 = tex2D( _MainTex, IN.uv.xy );
		half4 Scene2 = tex2D( _MainTex, IN.uv1.xy );
		half4 Scene3 = tex2D( _MainTex, IN.uv2.xy );
		half4 Scene4 = tex2D( _MainTex, IN.uv3.xy );

		// sample depths
		float depth1 = Linear01Depth( SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, IN.uv.xy ) );
		float depth2 = Linear01Depth( SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, IN.uv1.xy ) );
		float depth3 = Linear01Depth( SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, IN.uv2.xy ) );
		float depth4 = Linear01Depth( SAMPLE_DEPTH_TEXTURE( _CameraDepthTexture, IN.uv3.xy ) );

		// do scene stuff
		half4 Scene = ( max( Scene1 - threshold, 0.0 ) + max( Scene2 - threshold, 0.0 ) + max( Scene3 - threshold, 0.0 ) + max( Scene4 - threshold, 0.0 ) ) * 0.25;
		half4 SceneExtra = ( Scene1 + Scene2 + Scene3 + Scene4 ) * 0.25;

		Scene += SceneExtra * SceneExtra * _BloomExtra;

		// sunlight volume light mask
		half depthMask = saturate( ( depth1 - 0.99 ) * 100 ) + saturate( ( depth2 - 0.99 ) * 100 ) + saturate( ( depth2 - 0.99 ) * 100 ) + saturate( ( depth3 - 0.99 ) * 100 );
		depthMask *= 0.25;

		float3 viewDir = normalize(IN.viewDir);
		float sunDot = saturate( -dot( viewDir, _SunDir ) );
		float2 screenMask = saturate( ( 1.0 - abs( IN.uvMask ) ) * float2( 3.0, 4.0 ) );
		sunDot = smoothstep( 0.8, 1.0, sunDot );
		Scene.w = sunDot * depthMask * screenMask.x * screenMask.y;

		return Scene;
	}
	
	//======================================================//
	//						Blur Pass						//
	//														//
	//======================================================//
	
	
	struct v2fBlur {
		float4 pos : SV_POSITION;
		float2 uv : TEXCOORD0;
	};

	v2fBlur vertBlur( appdata_img v )
	{
		v2fBlur o;
		o.pos = UnityObjectToClipPos (v.vertex);
		o.uv = UnityStereoScreenSpaceUVAdjust(v.texcoord.xy, _MainTex_ST);
		return o;
	} 
	
	half4 Blur(v2fBlur IN) : SV_Target
	{		
		float2 ScreenUV = IN.uv;
		
		float2 blurDir = _BlurDir.xy;
		float2 pixelSize = _OneOverScreenSize;
		
		float4 Scene = tex2D( _MainTex, ScreenUV ) * 0.1438749;
		
		Scene += tex2D( _MainTex, ScreenUV + ( blurDir * pixelSize * _BlurSpread ) ) * 0.1367508;
		Scene += tex2D( _MainTex, ScreenUV + ( blurDir * pixelSize * 2.0 * _BlurSpread ) ) * 0.1167897;
		Scene += tex2D( _MainTex, ScreenUV + ( blurDir * pixelSize * 3.0 * _BlurSpread ) ) * 0.08794503;
		Scene += tex2D( _MainTex, ScreenUV + ( blurDir * pixelSize * 4.0 * _BlurSpread ) ) * 0.05592986;
		Scene += tex2D( _MainTex, ScreenUV + ( blurDir * pixelSize * 5.0 * _BlurSpread ) ) * 0.02708518;
		Scene += tex2D( _MainTex, ScreenUV + ( blurDir * pixelSize * 6.0 * _BlurSpread ) ) * 0.007124048;
		
		Scene += tex2D( _MainTex, ScreenUV - ( blurDir * pixelSize * _BlurSpread ) ) * 0.1367508;
		Scene += tex2D( _MainTex, ScreenUV - ( blurDir * pixelSize * 2.0 * _BlurSpread ) ) * 0.1167897;
		Scene += tex2D( _MainTex, ScreenUV - ( blurDir * pixelSize * 3.0 * _BlurSpread ) ) * 0.08794503;
		Scene += tex2D( _MainTex, ScreenUV - ( blurDir * pixelSize * 4.0 * _BlurSpread ) ) * 0.05592986;
		Scene += tex2D( _MainTex, ScreenUV - ( blurDir * pixelSize * 5.0 * _BlurSpread ) ) * 0.02708518;
		Scene += tex2D( _MainTex, ScreenUV - ( blurDir * pixelSize * 6.0 * _BlurSpread ) ) * 0.007124048;
	  
		return Scene;
	}

	//======================================================//
	//					Zoom Blur Pass						//
	//														//
	//======================================================//

	struct v2fZoomBlur {
		float4 pos : SV_POSITION;
		float4 uv : TEXCOORD0;
		float2 grsp : TEXCOORD1;
	};
	
	v2fZoomBlur vertZoomBlur( appdata_img v )
	{
		v2fZoomBlur o;
		o.pos = UnityObjectToClipPos (v.vertex);

		float2 fixedUV = UnityStereoScreenSpaceUVAdjust(v.texcoord.xy, _MainTex_ST);
		float4 uvCoords = float4( fixedUV.xy, v.texcoord.xy );

		float2 GRSP = _GodRayScreenPos.xy;

		#if UNITY_UV_STARTS_AT_TOP
		if(_MainTex_TexelSize.y < 0.0)
		{
			uvCoords.y = 1.0 - uvCoords.y;
			uvCoords.w = 1.0 - uvCoords.w;
			GRSP.y = GRSP.y * -1.0 + 1.0;
		}
		#endif


		o.uv =  uvCoords;
		o.grsp = GRSP;

		return o;
	
	} 

	half4 ZoomBlur(v2fZoomBlur IN) : SV_Target
	{		

		float2 ScreenUV = IN.uv.xy;
		float2 ScreenUV2 = IN.uv.zw;
		float2 GRSP = IN.grsp;

		float2 GodRayOffset = ( ScreenUV2 - GRSP );
		GodRayOffset *= _MainTex_ST.xy;
		
		float2 blurDir = _BlurDir.xy;
		float2 pixelSize = _OneOverScreenSize;
		
		float4 Scene = 0;
		int i = 0;
		int passes = _GodRaySteps;
		float oneOverPasses = 1.0 / passes;
		float rayLenght = oneOverPasses * _GodRayLength;
		float alphaACC = 0;
		for( i = 0; i < passes; i++ ){
			float alpha = 1.0 - ( i * oneOverPasses * _GodRayFalloff );
			alphaACC += alpha;
			Scene += tex2Dlod( _GodRayTex, float4( ScreenUV - GodRayOffset * rayLenght * i,0,0) ) * alpha;
		}

		Scene *= 1.0 / alphaACC;
		Scene.xyz *= Scene.w;
		Scene.xyz += Scene.w * _GodrayGlow;
		Scene.w = 1.0;

		return Scene;
	}

	ENDCG

	SubShader
	{
		// No culling or depth
		Cull Off 
		ZWrite Off 
		ZTest Always

		//Pass 0 Composit of all passes
		Pass
		{
			Name "Compose"

			CGPROGRAM
			#pragma vertex vertCompose
			#pragma fragment Compose
			#pragma target 3.0
			#pragma multi_compile _ _USE_2D_IMAGE_ENHANCE
			ENDCG
		}

		//Pass 1 Mipping pass
		Pass 
		{
			Name "Mipping"
		
			CGPROGRAM
			#pragma fragmentoption ARB_precision_hint_fastest 
			#pragma vertex vertMipping
			#pragma fragment Mipping
			#pragma target 3.0
			ENDCG
		}
		
		//Pass 2 Threshold pass
		Pass 
		{
			Name "Threshold"
		
			CGPROGRAM
			#pragma fragmentoption ARB_precision_hint_fastest 
			#pragma vertex vertMipping
			#pragma fragment Threshold
			#pragma target 3.0
			ENDCG
		}
		
		//Pass 3 Blur pass
		Pass 
		{
			Name "Blur"
		
			CGPROGRAM
			#pragma fragmentoption ARB_precision_hint_fastest 
			#pragma vertex vertBlur
			#pragma fragment Blur
			#pragma target 3.0
			ENDCG
		}

		//Pass 4 ZoomBlur pass
		Pass 
		{
			Name "Blur"
		
			CGPROGRAM
			#pragma fragmentoption ARB_precision_hint_fastest 
			#pragma vertex vertZoomBlur
			#pragma fragment ZoomBlur
			#pragma target 3.0
			ENDCG
		}

	}
}
