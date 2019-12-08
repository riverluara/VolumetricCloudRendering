﻿Shader "FinalProject/CloudRendering"
{
    Properties
    {
		[Header(Textures)]
        _CloudBase("Cloud Base Texture", 3D) = "white"{}
		_CloudBaseScale("Cloud Base Shape Scale", Range(0.4, 3.8)) = 1

		_CloudDetail("Cloud Detail Texture", 3D) = "white"{}
		_CloudDetailScale("Cloud Detail Shape Scale", Range(0.2, 1.2)) = 1

		_CloudWeather("Cloud Coverage Texture", 2D) = "white"{}

		_CloudWeatherScale("Cloud Weather Scale", Range(0.7, 10)) = 1

		[Header(Shaping)]
		_NoiseTex("Texture for Random", 2D) = "white"{}
		_CloudCoverage("Cloud Coverage", Range(0.0,1)) = 0.5
		_DensityClampLow("Density Clamping Low Value" ,Range(0,1)) = 0.1
		_DensityClampHigh("Density Clamping Hight Value" ,Range(1.1,2)) = 1.5
		_ThicknessDebug("Thickness Debug",Range(0.3,5)) = 1
		_DensityCutoff("Density Cutoff", Range(0, 1)) = 0.1
		_DetailErodeStrength("Detail Erode Strength", Range(0.00,0.6)) = 0.3

		[Header(Environment)]
		_LowerHeight("Lower Height", float) = 500
		_UpperHeight("Higher Height", float) = 7000
		_EarthRadius("Earth Radius", float) = 6400000
		_ViewRange("Cloud View Range" ,float) = 200000

		[Header(Lighting)]
		_AmbientColor("Ambient Color", Color) = (0.2,0.2,0.2,1.0)
		_DirectionalSpread("Directional Spread", Range(0,50)) = 30
		_DirectionalStrength("Directional Strength", Range(0,10)) = 4
		_CloudTransmittance("Cloud Overall Transmittance", Range(0.0010,0.0250)) = 0.010
		_AmbientStrength("Skylight Strength", Range(0,10)) = 2
		_PowderFactor("Powder Effect Factor", Range(0.01,0.2)) = 0.02
		_LightAdjust("Light Adjustment", Range(0,10)) = 1
		_FinalAdjust("Final Light Adjustment", Range(-0.4,0.4)) = 0

		[Header(Animation)]
		_CloudShapeDirection("Cloud Shape Direction", Range(0,360)) = 0
		_CloudWeatherDirection("Cloud Weather Direction", Range(0,360)) = 1

		[Header(Optimization)]
		_SampleSize("Sample Size", Range(16, 1024)) = 64
		_LowDensityThreshold("Low Density Threshold",Range(0,0.2)) = 0.05
		_TemporalBlendFactor("Temporal Blend Factor", Range(0.0, 1.0)) = 0.05
		
		[Header(Demo Debug Options)]
		[Toggle] _RandomStepSize("Random Step Size", Float) = 1
		[Toggle] _TemporalUpsample("Temporal Upsample", Float) = 1

    }
    SubShader
    {

        //no culling and depth
		Cull Off
		//ZWrite Off


        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

			const float MAX_FLOAT = 1.0e+12;
			float3 _CameraPos;
			float _LowerHeight;
			float _UpperHeight;
			float _EarthRadius;
			float _ViewRange;
			float _SampleSize;
			
			float4x4 _LastVP;

			sampler3D _CloudBase;
			sampler3D _CloudDetail;
			sampler2D _CloudWeather;
			

			float _CloudBaseScale;
			float _CloudDetailScale;
			float _CloudWeatherScale;
			float _DensityCutoff;

			float _DirectionalSpread;
			float _DirectionalStrength;

			float _CloudShapeDirection;
			float _CloudWeatherDirection;
			float _CloudTransmittance;
			float4 _AmbientColor;
			float _AmbientStrength;
			float _PowderFactor;
			float _LightAdjust;
			float _FinalAdjust;

			float _CloudCoverage;
			float _DensityClampLow;
			float _DensityClampHigh;
			float _ThicknessDebug;
			float _DetailErodeStrength;
			sampler2D _NoiseTex;
			
			float _LowDensityThreshold;
			float _TemporalBlendFactor;
			sampler2D _LastCloudTex;
			
			float _RandomStepSize;
			float _TemporalUpsample;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
				float4 ray : TEXCOORD1;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
				float4 worldPos : TEXCOORD1;
				float4 modelPos : TEXCOORD2;
				float4 interpolatedRay : TEXCOORD3;
            };
			//Returns t1 and t2 solution of ray sphere intersection
			float2 RaySphereIntersectT(float3 ray, float height)
			{
				float a = dot(ray, ray);
				float b = 2 * (_EarthRadius + _CameraPos.y) * ray.y;
				float c = -2 * _EarthRadius * height - height * height + _CameraPos.y * _CameraPos.y + 2 * _EarthRadius * _CameraPos.y;
				float delta = b * b - 4 * a * c;
				if (delta < 0) return float2(MAX_FLOAT, MAX_FLOAT);
				float t1 = -(b + sqrt(delta)) / (2 * a); float t2 = -(b - sqrt(delta)) / (2 * a);
				return float2(t1, t2);
			}
			//Finding start and end based on player altitude
			void findSNE(float3 ray, out float3 rayMarchingStart, out float3 rayMarchingEnd)
			{
				float startT = 0; float endT = 0;

				float2 tLow = RaySphereIntersectT(ray, _LowerHeight);
				float2 tHigh = RaySphereIntersectT(ray, _UpperHeight);

				if (_CameraPos.y < _UpperHeight && _CameraPos.y > _LowerHeight)
				{
					startT = 0;
					endT = tHigh.y;
					if (tLow.x > 0) endT = tLow.x;

				}
				if (_CameraPos.y > _UpperHeight)
				{
					startT = tHigh.x;
					endT = tLow.x;
					if (tLow.x == MAX_FLOAT) {
						endT = tHigh.y;
					}
				}
				if (_CameraPos.y < _LowerHeight)
				{
					startT = tLow.y;
					endT = tHigh.y;
				}

				rayMarchingStart = _CameraPos + ray * startT;
				rayMarchingEnd = _CameraPos + ray * endT;
			}
			//Height signal calculation
			void CalculateThicknessFactor(float midHeight, float cloudThick, float linePos, out float heightSignal)
			{
				float thickness = min(midHeight, 1 - midHeight) * cloudThick;
				float a = midHeight - thickness; float b = midHeight + thickness;
				heightSignal = saturate(-4 / (a - b) / (a - b) * (linePos - a) * (linePos - b));
				//heightEnhanceThres = (b - linePos)/(b - a);
			}
			float SampleDensity(float3 pos, float linePos, float sinS, float cosS, float sinW, float cosW)
			{
				//Quit if current position is out of atmosphere
				if (linePos < 0 || linePos > 1) return 0;

				//Sampling base shape??
				float3 uvw = float3(pos.x / 10000 / _CloudBaseScale, pos.z / 10000 / _CloudBaseScale, pos.y / 10000 / _CloudBaseScale);
				//uv animation for cloud
				//uvw += float3(_Time.x / 10 * _CloudShapeSpeed * cosS, _Time.x / 10 * _CloudShapeSpeed * sinS, 0);
				float4 s = tex3Dlod(_CloudBase, float4(uvw, 0));

				//Sampling weather mask
				float random = tex2Dlod(_NoiseTex, float4(frac(pos.y + _Time.x), frac(pos.x + _Time.y), 0, 0)).r;
				//??
				float2 uv = float2((pos.x + 100 * sin(random*6.2832)) / 10000 / _CloudWeatherScale, (pos.z + 100 * cos(random*6.2832)) / 10000 / _CloudWeatherScale);
				//uv += float2(_Time.x / 10 * _CloudWeatherSpeed * cosW, _Time.x / 10 * _CloudWeatherSpeed * sinW);
				float c = tex2Dlod(_CloudWeather, float4(uv, 0, 4));

				//Cloud coverage adjustment
				if (_CloudCoverage <= 0.5) { c = lerp(0, c, _CloudCoverage * 2); }
				else { c = lerp(c, 1, _CloudCoverage * 2 - 1); }

				float density = s.r * 0.45 + s.g * 0.3 + s.b * 0.15 + s.a * 0.15;
				density *= 3;
				density *= c;

				float heightSignal;
				//Calculate height signal
				CalculateThicknessFactor(0.5, c, linePos, heightSignal);

				//Density clamping
				density = smoothstep(_DensityClampLow, _DensityClampHigh, density);
				//Thickness adjustment
				density *= pow(heightSignal, _ThicknessDebug);
				return density;
			}
			//Sampling detail shape
			float SampleDetail(float3 pos, float linePos)
			{
				float4 s = tex3Dlod(_CloudDetail, float4(pos.x / 2500 / _CloudDetailScale - _Time.x, pos.z / 2500 / _CloudDetailScale + _Time.x, pos.y / 2500 / _CloudDetailScale, 0));
				return (s.r * 0.33 + s.g * 0.33 + s.b * 0.33) *  _DetailErodeStrength;
			}

			//Sample density towards the sun
			float SampleSunLight(float3 rayPos, float3 lightDir, float density, float sinS, float cosS, float sinW, float cosW)
			{
				//Sample at around 600m away
				float random = tex2Dlod(_NoiseTex, float4(frac(rayPos.y + _SinTime.x), frac(rayPos.z + _SinTime.y), 0, 0)).r;
				float3 shadowRayPos = rayPos + lightDir * 600 * (0.5 + random);
				float shadowLinePos = (shadowRayPos.y - _LowerHeight) / (_UpperHeight - _LowerHeight);
				float newDensity = SampleDensity(shadowRayPos, shadowLinePos, sinS, cosS, sinW, cosW) - SampleDetail(shadowRayPos, shadowLinePos);
				float diff = saturate(density - newDensity);
				diff = smoothstep(0.00, 0.01, diff)* density;

				//Sample at around 3000m away
				shadowRayPos = rayPos + lightDir * 3000 * (0.5 + random);
				shadowLinePos = (shadowRayPos.y - _LowerHeight) / (_UpperHeight - _LowerHeight);
				newDensity = SampleDensity(shadowRayPos, shadowLinePos, sinS, cosS, sinW, cosW) - SampleDetail(shadowRayPos, shadowLinePos);

				//The higher density differece is, the higher the sun light is received at this point
				diff *= saturate((1 - newDensity * 2));

				return diff;
			}

			//Tome mapping from Uncharted
			float3 ToneMapping(float3 x)
			{
				const float A = 0.15;
				const float B = 0.50;
				const float C = 0.10;
				const float D = 0.20;
				const float E = 0.02;
				const float F = 0.30;
				return ((x*(A*x + C * B) + D * E) / (x*(A*x + B) + D * F)) - E / F;
			}

			//Main ray marching process
			float4 RayMarching(float3 start, float3 end, int sampleStep, float3 lightDir)
			{

				float3 stepVector = (end - start) / (float)sampleStep;
				float3 rayDir = normalize(stepVector);
				float stepSize = length(stepVector);
				bool cheap = false;

				//Setting max step size
			/*	if (stepSize > 600 && _CameraPos.y > _LowerHeight)
				{
					stepVector = stepVector / stepSize * 600;
					stepSize = 600;
				}*/

				float3 rayPos = start;
				float rayHeightPos = 0;
				float density = 0;

				//Simulating directioncal scattering
				float directionalFactor = pow(max(0, dot(rayDir, lightDir)), _DirectionalSpread);
				float3 directionalScattering = float3(1, 1, 1) * pow(10, _DirectionalStrength) * directionalFactor;

				uint cumuLowDensity = 0;
				float4 light = float4(0, 0, 0, 1);
				//Alpha 1 means no cloud density
				light.a = 1;

				//Pre-caculate directional component
				float sinS = sin(_CloudShapeDirection / 360 * 6.2832);
				float cosS = cos(_CloudShapeDirection / 360 * 6.2832);
				float sinW = sin(_CloudWeatherDirection / 360 * 6.2832);
				float cosW = cos(_CloudWeatherDirection / 360 * 6.2832);

				float3 stepVectorTMP = stepVector;
				float3 stepSizeTMP = stepSize;
				float3 baseColor = 0;
                
				for (int i = 0; i < sampleStep; i++)
				{
				    if (_RandomStepSize > 0.5f)
				    {
				        float random = tex2Dlod(_NoiseTex, float4(frac(rayPos.y + _Time.x), frac(rayPos.x + _Time.y), 0, 0)).r;
					    rayPos = rayPos + stepVectorTMP * random * 2;
				    }
				    else
				    {
				        rayPos = rayPos + stepVectorTMP;
				    }

					//Quit if out of view range
					if (length(rayPos - _CameraPos) > _ViewRange) break;
					float rayHeightPos = (rayPos.y - _LowerHeight) / (_UpperHeight - _LowerHeight);

					//Density cut-off
					density = SampleDensity(rayPos, rayHeightPos, sinS, cosS, sinW, cosW) - SampleDetail(rayPos, rayHeightPos);
					if (density <= _DensityCutoff)  density = 0;

					//Current step transmittance
					float transmittanceCurrent = exp(-stepSizeTMP * density * _CloudTransmittance);


					if (density <= _LowDensityThreshold) { cumuLowDensity += 1; }
					else
					{
						//If current step is with high density, change back to normal sampling
						cheap = false;
						cumuLowDensity = 0;
						stepSizeTMP = stepSize;
						stepVectorTMP = stepVector;
					}

					//If we have several sequential low density sampling result, change to cheaper sampling
					if (cumuLowDensity >= 5) cheap = true;

					//If transmittance is low enough, change to cheap samling
					//if (light.a < 0.3) cheap = true;

					//Increasing step size if continuously get low density result
					if (cumuLowDensity >= 15 && cumuLowDensity % 15 == 0)
					{
						stepSizeTMP *= 1.5;
						stepVectorTMP *= 1.5;
					}

					//If sampling mode is cheap, we do not sample towards the sun
					if (cheap) { baseColor = _AmbientColor.rgb; }
					else
					{
						baseColor = _AmbientColor.rgb + SampleSunLight(rayPos, lightDir, density, sinS, cosS, sinW, cosW) * (float3(1.0, 1.0, 1.0) * _AmbientStrength + directionalScattering);
					}

					//Powder effect calculation
					float powderEffect = 1 - exp(-stepSizeTMP * density * _CloudTransmittance * 2) + _PowderFactor;
					light.xyz += light.a  * powderEffect *baseColor * _LightAdjust;

					//Transmittance cumulation
					light.a *= transmittanceCurrent;

					//Early exit
					if (rayPos.y > _UpperHeight && start.y < end.y) break;
					if (rayPos.y < _LowerHeight && start.y > end.y) break;
					if (light.a < 0.05) break;

				}

				//Tone mapping & Final adjust
				light.rgb = ToneMapping(light.rgb) * (1 + _FinalAdjust);
				return light;
			}


            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.modelPos = v.vertex;
				o.uv = v.uv;
				o.interpolatedRay = v.ray;
              
                return o;
            }
			

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 cloudBaseTexture = tex3D(_CloudBase, i.modelPos.xyz);
			    fixed4 cloudDetailTexture = tex3D(_CloudDetail, i.modelPos.xyz);

				fixed4 col = 1;
				fixed3 density = cloudBaseTexture.rgb - cloudDetailTexture.rbg;

				i.interpolatedRay = normalize(i.interpolatedRay);
				float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
				//do not render pixels under horizon line
				if (_CameraPos.y < _LowerHeight && i.interpolatedRay.y < 0.00) return 1;

				float3 rayMarchingStart = 0;
				float3 rayMarchingEnd = 0;
				//find interset point of two spheres
				findSNE(i.interpolatedRay, rayMarchingStart, rayMarchingEnd);


				//ray marching 
				float4 currentFrameCol = RayMarching(rayMarchingStart, rayMarchingEnd, _SampleSize, lightDir);
				//fixed a =  density.r * 0.299 + density.g * 0.587 + density.b * 0.114;
				//clip(a - _DensityCutoff);
				
				float4 reprojectionPoint = float4((rayMarchingStart + rayMarchingEnd) / 2,1);
                float4 lastFrameClipCoord = mul(_LastVP, reprojectionPoint);
                float2 lastFrameUV  = float2(lastFrameClipCoord.x / lastFrameClipCoord.w, lastFrameClipCoord.y / lastFrameClipCoord.w)* 0.5 + 0.5;

				float4 lastFrameCol = tex2D(_LastCloudTex, lastFrameUV);
                //return lastFrameCol;
                //return currentFrameCol;
                if (_TemporalUpsample > 0.5f)
                    return currentFrameCol * _TemporalBlendFactor + lastFrameCol * (1 - _TemporalBlendFactor);
                else
                    return currentFrameCol;
            }
            ENDCG
        }
    }
}
