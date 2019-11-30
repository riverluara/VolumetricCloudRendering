Shader "FinalProject/CloudRendering"
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

		_DensityCutoff("Density Cutoff", Range(0, 1)) = 0.1


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

			sampler3D _CloudBase;
			sampler3D _CloudDetail;
			sampler2D _CloudWeather;

			float _CloudBaseScale;
			float _CloudDetailScale;
			float _CloudWeatherScale;
			float _DensityCutoff;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
				float4 worldPos : TEXCOORD1;
				float4 modelPos : TEXCOORD2;
            };


            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.modelPos = v.vertex;
				o.uv = v.uv;
              
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 cloudBaseTexture = tex3D(_CloudBase, i.modelPos.xyz);
			    fixed4 cloudDetailTexture = tex3D(_CloudDetail, i.modelPos.xyz);

				fixed4 col = 1;
				fixed3 density = cloudBaseTexture.rgb - cloudDetailTexture.rbg;
				fixed a =  density.r * 0.299 + density.g * 0.587 + density.b * 0.114;

				clip(a - _DensityCutoff);

                return col;
            }
            ENDCG
        }
    }
}
