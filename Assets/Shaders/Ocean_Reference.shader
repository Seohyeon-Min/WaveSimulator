// 백업/참고용 완성본. Ocean.shader를 처음부터 다시 짜다가 막히면 여기와 비교해서 확인하세요.
// 이 셰이더 자체는 어떤 머티리얼에도 연결하지 마세요 (이름이 달라서 별개의 셰이더로 취급됨).
Shader "Custom/Ocean_Reference"
{
    Properties
    {
        _Color ("Color", Color) = (0.1, 0.4, 0.7, 1)
        _LightDirection ("Light Direction", Vector) = (0.5, 1, 0.3, 0)

        _NoiseScale ("Noise Scale", Range(0.1, 5)) = 1.5
        _FlowDirection ("Flow Direction (XZ, 무늬가 옆으로 흐르는 방향)", Vector) = (1, 0, 0, 0)
        _FlowSpeed ("Flow Speed (무늬가 옆으로 흐르는 속도)", Range(0, 2)) = 0.1

        _MorphSpeed ("Morph Speed (산이 생겼다 사라지는 속도, 시간축 노이즈)", Range(0, 1)) = 0.15

        _MinHeight ("Min Height (골의 깊이)", Range(-0.5, 0)) = -0.04
        _MaxHeight ("Max Height (봉우리의 높이)", Range(0, 0.5)) = 0.15

        _Contrast ("Contrast (봉우리를 0~1 끝까지 넓게 펴줌, 골에는 영향 없음)", Range(1, 4)) = 2.0
        _PeakSharpness ("Peak Sharpness (봉우리 끝만 뾰족하게)", Range(1, 6)) = 2.0
        _PullStrength ("Pull Strength (봉우리 근처 정점을 정상으로 당겨서 첨탑 모양으로)", Range(0, 1)) = 0.3
        _Octaves ("Detail Octaves (많을수록 잘게 울퉁불퉁)", Range(1, 5)) = 2

        _CausticColor ("Caustic Color", Color) = (1, 1, 1, 1)
        _CausticScale ("Caustic Scale (망 무늬 크기)", Range(0.1, 5)) = 1.0
        _CausticSpeed ("Caustic Speed (무늬 움직이는 속도)", Range(0, 2)) = 0.3
        _CausticDistortion ("Caustic Distortion (도메인 워핑 세기)", Range(0, 1)) = 0.4
        _CausticLineWidth ("Caustic Line Width (선 두께)", Range(0.01, 0.5)) = 0.08
        _CausticIntensity ("Caustic Intensity (밝기)", Range(0, 3)) = 1.0
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
            };

            float4 _Color;
            float4 _LightDirection;

            float _NoiseScale;
            float4 _FlowDirection;
            float _FlowSpeed;
            float _MorphSpeed;

            float _MinHeight;
            float _MaxHeight;

            float _Contrast;
            float _PeakSharpness;
            float _PullStrength;
            float _Octaves;

            float4 _CausticColor;
            float _CausticScale;
            float _CausticSpeed;
            float _CausticDistortion;
            float _CausticLineWidth;
            float _CausticIntensity;

            float Hash31(float3 p)
            {
                p = frac(p * float3(123.34, 456.21, 789.11));
                p += dot(p, p + 45.32);
                return frac((p.x + p.y) * p.z);
            }

            float3 RandomGradient3D(float3 p)
            {
                float h1 = Hash31(p);
                float h2 = Hash31(p + 19.19);
                float theta = h1 * 6.2831853;
                float z = h2 * 2.0 - 1.0;
                float r = sqrt(max(0.0, 1.0 - z * z));
                return float3(r * cos(theta), r * sin(theta), z);
            }

            float PerlinNoise3D(float3 p)
            {
                float3 cell = floor(p);
                float3 f = frac(p);

                float n000 = dot(RandomGradient3D(cell + float3(0, 0, 0)), f - float3(0, 0, 0));
                float n100 = dot(RandomGradient3D(cell + float3(1, 0, 0)), f - float3(1, 0, 0));
                float n010 = dot(RandomGradient3D(cell + float3(0, 1, 0)), f - float3(0, 1, 0));
                float n110 = dot(RandomGradient3D(cell + float3(1, 1, 0)), f - float3(1, 1, 0));
                float n001 = dot(RandomGradient3D(cell + float3(0, 0, 1)), f - float3(0, 0, 1));
                float n101 = dot(RandomGradient3D(cell + float3(1, 0, 1)), f - float3(1, 0, 1));
                float n011 = dot(RandomGradient3D(cell + float3(0, 1, 1)), f - float3(0, 1, 1));
                float n111 = dot(RandomGradient3D(cell + float3(1, 1, 1)), f - float3(1, 1, 1));

                float3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

                float nx00 = lerp(n000, n100, u.x);
                float nx10 = lerp(n010, n110, u.x);
                float nx01 = lerp(n001, n101, u.x);
                float nx11 = lerp(n011, n111, u.x);

                float nxy0 = lerp(nx00, nx10, u.y);
                float nxy1 = lerp(nx01, nx11, u.y);

                float nxyz = lerp(nxy0, nxy1, u.z);

                return nxyz * 0.5 + 0.5;
            }

            float FBM3D(float3 p, float octaves)
            {
                float value = 0.0;
                float amplitude = 0.5;
                float maxValue = 0.0;
                int octaveCount = (int)octaves;
                for (int i = 0; i < octaveCount; i++)
                {
                    value += amplitude * PerlinNoise3D(p);
                    maxValue += amplitude;
                    p *= 2.0;
                    amplitude *= 0.5;
                }
                return value / maxValue;
            }

            float GetHeight(float2 posXZ, float2 flowOffset, float morphT)
            {
                float3 samplePos = float3(posXZ * _NoiseScale + flowOffset, morphT);
                float noise = FBM3D(samplePos, _Octaves);
                float centered = noise * 2.0 - 1.0;

                if (centered > 0.0)
                {
                    float c = clamp(centered * _Contrast, 0.0, 1.0);
                    centered = pow(c, _PeakSharpness);
                }

                float t01 = centered * 0.5 + 0.5;
                return lerp(_MinHeight, _MaxHeight, t01);
            }

            float2 Hash22(float2 p)
            {
                return float2(Hash31(float3(p, 17.0)), Hash31(float3(p, 43.0)));
            }

            float2 Voronoi2D(float2 p)
            {
                float2 cell = floor(p);
                float2 f = frac(p);

                float f1 = 8.0;
                float f2 = 8.0;

                for (int y = -1; y <= 1; y++)
                {
                    for (int x = -1; x <= 1; x++)
                    {
                        float2 neighbor = float2(x, y);
                        float2 seed = Hash22(cell + neighbor);
                        float dist = length(neighbor + seed - f);

                        if (dist < f1) { f2 = f1; f1 = dist; }
                        else if (dist < f2) { f2 = dist; }
                    }
                }
                return float2(f1, f2);
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                float2 posXZ = IN.positionOS.xz;
                float t = _Time.y;

                float2 flowDir = normalize(_FlowDirection.xz);
                float2 flowOffset = flowDir * _FlowSpeed * t;
                float morphT = t * _MorphSpeed;

                float height = GetHeight(posXZ, flowOffset, morphT);

                float eps = 0.05;
                float hR = GetHeight(posXZ + float2(eps, 0), flowOffset, morphT);
                float hL = GetHeight(posXZ - float2(eps, 0), flowOffset, morphT);
                float hU = GetHeight(posXZ + float2(0, eps), flowOffset, morphT);
                float hD = GetHeight(posXZ - float2(0, eps), flowOffset, morphT);
                float2 gradient = float2(hR - hL, hU - hD) / (2.0 * eps);

                float pullFactor = saturate(height / max(_MaxHeight, 0.0001)) * _PullStrength;
                float2 horizontalOffset = gradient * pullFactor;

                float3 offset = float3(horizontalOffset.x, height, horizontalOffset.y);
                float3 positionOS = IN.positionOS.xyz + offset;

                OUT.positionWS = TransformObjectToWorld(positionOS);
                OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);
                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                float3 normalWS = normalize(cross(ddy(IN.positionWS), ddx(IN.positionWS)));

                float3 lightDir = normalize(_LightDirection.xyz);
                float diffuse = saturate(dot(normalWS, lightDir));

                float ambient = 0.35;
                float3 litColor = _Color.rgb * (ambient + diffuse * 0.65);

                float t = _Time.y;
                float2 worldXZ = IN.positionWS.xz * _CausticScale;

                float warpX = FBM3D(float3(worldXZ * 0.5, t * _CausticSpeed), 2) - 0.5;
                float warpY = FBM3D(float3(worldXZ * 0.5 + 100.0, t * _CausticSpeed), 2) - 0.5;
                float2 warpedUV = worldXZ + float2(warpX, warpY) * _CausticDistortion * 4.0;

                float2 f = Voronoi2D(warpedUV);
                float edge = f.y - f.x;
                float lineMask = 1.0 - smoothstep(0.0, _CausticLineWidth, edge);

                litColor += _CausticColor.rgb * lineMask * _CausticIntensity;

                return float4(litColor, _Color.a);
            }

            ENDHLSL
        }
    }
}
