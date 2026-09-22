// Procedural URP ocean shader used in Poseidon Skate.
// Combines animated gradient noise, domain warping, procedural normals,
// Voronoi surface detail, realtime shadows, and render-texture-driven wake deformation.
Shader "Custom/Ocean"
{
    Properties
    {
        _Color ("Color", Color) = (0.1, 0.4, 0.7, 1)
        _LightDirection ("Light Direction", Vector) = (0.5, 1, 0.3, 0)

        _NoiseScale ("Noise Scale", Range(0.1, 5)) = 1.5
        _FlowDirection ("Flow Direction (XZ)", Vector) = (1, 0, 0, 0)
        _FlowSpeed ("Flow Speed", Range(0, 5)) = 0.1
        _MorphSpeed ("Morph Speed (Flow Noise 그래디언트 회전 속도)", Range(0, 5)) = 0.15
        _Amplitude ("Amplitude (0을 중심으로 위아래 대칭으로 솟는 높이)", Range(0, 4)) = 0.1
        _PullStrength ("Pull Strength (경사를 당기는 세기)", Range(0, 0.9)) = 0.5

        _WarpScale ("Warp Scale (도메인 워핑 노이즈의 스케일, 작을수록 크고 완만하게 휘어짐)", Range(0.05, 2)) = 0.3
        _WarpStrength ("Warp Strength (좌표를 얼마나 세게 휘게 할지, 노이즈 칸 단위)", Range(0, 2)) = 0.5

        _CausticColor ("Caustic Color", Color) = (1, 1, 1, 1)
        _CausticScale ("Caustic Scale (망 무늬 크기)", Range(0.1, 5)) = 1.0
        _CausticSpeed ("Caustic Speed (지형 Flow Noise 변형 속도 대비 배율)", Range(0, 2)) = 0.3
        _CausticDistortion ("Caustic Distortion (1차 도메인 워핑 세기, 큰 흐름)", Range(0, 1)) = 0.4
        _CausticDistortion2 ("Caustic Distortion 2 (2차 도메인 워핑 세기, 잘게 구불거리는 디테일)", Range(0, 1)) = 0.4
        _CausticLineWidth ("Caustic Line Width (선 두께)", Range(0.01, 0.5)) = 0.08
        _CausticIntensity ("Caustic Intensity (밝기)", Range(0, 3)) = 1.0
        _CausticCornerWidth ("Caustic Corner Width (마디로 인정할 반경)", Range(0.01, 0.5)) = 0.12
        _CausticWallBrightness ("Caustic Wall Brightness (마디에서 먼 선의 최소 밝기, 0~1)", Range(0, 1)) = 0.25

        _WaveWorldPos ("Wave World Pos (XZ, C#에서 HalfpipeWaveGenerator 위치를 SetVector로 갱신)", Vector) = (0, 0, 0, 0)
        _WaveFadeRadius ("Wave Fade Radius (이 거리(월드 단위) 안쪽은 Caustic이 흐려짐)", Range(1, 100)) = 10.0
        _WaveFadeSharpness ("Wave Fade Sharpness (클수록 경계 안쪽에서 훨씬 급격하게 사라짐)", Range(0.5, 8)) = 1.0

        _ScatterColor ("Scatter Color (정면으로 내려다볼 때 보이는 어두운 물속 색)", Color) = (0.02, 0.1, 0.2, 1)
        _ScatterPower ("Scatter Power (클수록 아주 정면일 때만 어두워짐)", Range(0.5, 8)) = 2.0
        _ScatterIntensity ("Scatter Intensity (최대로 얼마나 섞을지, 0~1)", Range(0, 1)) = 0.6

        _WhitecapColor ("Whitecap Color (비스듬하고 먼 곳에서 하얗게 빛나는 색)", Color) = (1, 1, 1, 1)
        _WhitecapGrazingPower ("Whitecap Grazing Power (클수록 아주 비스듬할 때만 반응)", Range(0.5, 8)) = 3.0
        _WhitecapDistance ("Whitecap Distance (이 거리(월드 단위)부터 완전히 반영)", Range(1, 100)) = 20.0
        _WhitecapIntensity ("Whitecap Intensity (최대로 얼마나 섞을지, 0~1)", Range(0, 1)) = 0.8
        _WhitecapThreshold ("Whitecap Threshold (이 값 이상만 하얗게, 나머지는 완전히 안 보임 - 툰 느낌)", Range(0, 1)) = 0.5
        _WhitecapEdgeSoftness ("Whitecap Edge Softness (경계 앤티에일리어싱, 작을수록 툰처럼 딱 끊김)", Range(0.001, 0.5)) = 0.1

        _OceanTrailDistortStrength ("Ocean Trail Distort Strength (그물망을 얼마나 세게 휠지)", Range(0, 10)) = 8.31
        _OceanTrailPushStrength ("Ocean Trail Push Strength (양옆을 얼마나 높이 밀어올릴지)", Range(0, 5)) = 1.0
        _OceanTrailLineColor ("Ocean Trail Line Color (웨이크 이중선 색)", Color) = (1, 1, 1, 1)
        _OceanTrailLineThreshold ("Ocean Trail Line Threshold (트레일 마스크가 이 값을 지나는 경계에 선이 생김)", Range(0.01, 0.99)) = 0.279
        _OceanTrailLineWidth ("Ocean Trail Line Width (선 두께)", Range(0.001, 0.3)) = 0.077
        _OceanTrailLineNoiseScale ("Ocean Trail Line Noise Scale (삐뚤빼뚤함의 잘기, 클수록 잘게 흔들림)", Range(0.1, 5)) = 1.12
        _OceanTrailLineNoiseStrength ("Ocean Trail Line Noise Strength (선을 얼마나 세게 흔들지)", Range(0, 1)) = 0.327
        _OceanTrailLineIntensity ("Ocean Trail Line Intensity (선 밝기)", Range(0, 3)) = 1.69
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

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;

                float4 shadowCoord : TEXCOORD2;
            };

            float4 _Color;
            float4 _LightDirection;

            float _NoiseScale;
            float4 _FlowDirection;
            float _FlowSpeed;
            float _MorphSpeed;
            float _Amplitude;
            float _PullStrength;
            float _WarpScale;
            float _WarpStrength;
            float4 _CausticColor;
            float _CausticScale;
            float _CausticSpeed;
            float _CausticDistortion;
            float _CausticDistortion2;
            float _CausticLineWidth;
            float _CausticIntensity;
            float _CausticCornerWidth;
            float _CausticWallBrightness;
            float4 _WaveWorldPos;
            float _WaveFadeRadius;
            float _WaveFadeSharpness;
            float4 _ScatterColor;
            float _ScatterPower;
            float _ScatterIntensity;
            float4 _WhitecapColor;
            float _WhitecapGrazingPower;
            float _WhitecapDistance;
            float _WhitecapIntensity;
            float _WhitecapThreshold;
            float _WhitecapEdgeSoftness;

            TEXTURE2D(_OceanTrailTex);
            SAMPLER(sampler_OceanTrailTex);
            float4 _OceanTrailCenter;
            float _OceanTrailAreaSize;
            float _OceanTrailDistortStrength;
            float _OceanTrailPushStrength;
            float4 _OceanTrailLineColor;
            float _OceanTrailLineThreshold;
            float _OceanTrailLineWidth;
            float _OceanTrailLineNoiseScale;
            float _OceanTrailLineNoiseStrength;
            float _OceanTrailLineIntensity;

// Deterministic 2D-to-1D hash used to seed procedural noise.
            float Hash21(float2 p)
            {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }

// Animated gradient direction: each lattice point rotates continuously at its own seeded speed.
// This produces evolving flow noise without discontinuous value changes.
            float2 RandomGradient2D(float2 p, float time)
            {
                float baseAngle = Hash21(p) * 2.0 * PI;
                float rotSpeed = Hash21(p + 7.7) * 2.0 - 1.0;
                float angle = baseAngle + time * rotSpeed;
                return float2(cos(angle), sin(angle));
            }

// 2D gradient noise with quintic interpolation for smooth first- and second-order transitions.
            float PerlinNoise2D(float2 p, float time)
            {
                float2 cell = floor(p);
                float2 f = frac(p);

                float n00 = dot(RandomGradient2D(cell + float2(0,0), time), f - float2(0,0));
                float n10 = dot(RandomGradient2D(cell + float2(1,0), time), f - float2(1,0));
                float n01 = dot(RandomGradient2D(cell + float2(0,1), time), f - float2(0,1));
                float n11 = dot(RandomGradient2D(cell + float2(1,1), time), f - float2(1,1));

                float2 u = f*f*f*(f*(f*6.0-15.0)+10.0);

                float nx0 = lerp(n00, n10, u.x);
                float nx1 = lerp(n01, n11, u.x);
                float nxy = lerp(nx0, nx1, u.y);

                return nxy * 0.5 + 0.5;
            }

// Two decorrelated hash samples for Voronoi seed placement.
            float2 Hash22(float2 p)
            {
                return float2(Hash21(p + 17.0), Hash21(p + 43.0));
            }

// Returns the three nearest Voronoi seed distances.
// f2-f1 extracts cell edges; f3-f2 emphasizes junctions.
            float3 Voronoi2D(float2 p)
            {
                float2 cell = floor(p);
                float2 f = frac(p);

                float f1 = 8.0;
                float f2 = 8.0;
                float f3 = 8.0;

                for (int y = -1; y <= 1; y++)
                {
                    for (int x = -1; x <= 1; x++)
                    {
                        float2 neighbor = float2(x, y);
                        float2 seed = Hash22(cell + neighbor);
                        float dist = length(neighbor + seed - f);

                        if (dist < f1) { f3 = f2; f2 = f1; f1 = dist; }
                        else if (dist < f2) { f3 = f2; f2 = dist; }
                        else if (dist < f3) { f3 = dist; }
                    }
                }
                return float3(f1, f2, f3);
            }

// Low-frequency domain warping breaks up visible grid regularity in the base noise.
            float2 GetWarpedPos(float2 posXZ, float time)
            {
                float2 scaledPos = posXZ * _NoiseScale;

                float2 warp = float2(
                    PerlinNoise2D(scaledPos * _WarpScale + 17.0, time),
                    PerlinNoise2D(scaledPos * _WarpScale + 91.0, time)
                ) - 0.5;
                return scaledPos + warp * _WarpStrength;
            }

// Samples the world-space wake mask written by OceanTrailPainter.
// Explicit LOD sampling is required because this helper is also used from the vertex stage.
            float SampleOceanTrailMask(float2 worldXZ)
            {
                float2 uv = (worldXZ - _OceanTrailCenter.xy) / _OceanTrailAreaSize + 0.5;
                if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return 0.0;
                return SAMPLE_TEXTURE2D_LOD(_OceanTrailTex, sampler_OceanTrailTex, uv, 0).r;
            }

// Shared procedural height function used by displacement and normal reconstruction.
            float GetHeight(float2 posXZ, float time)
            {
                float2 warpedPos = GetWarpedPos(posXZ, time);
                float noise = PerlinNoise2D(warpedPos, time);
                return (noise * 2.0 - 1.0) * _Amplitude;
            }

// Vertex stage: world-space procedural displacement, wake deformation, and normal reconstruction.
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionOS = IN.positionOS.xyz;

                float flowT = _Time.y * _MorphSpeed;

                float3 worldBasePos = TransformObjectToWorld(positionOS);
                float2 flowOffset = normalize(_FlowDirection.xz) * _FlowSpeed * _Time.y;
// Sample in world space so tiled ocean meshes share a continuous noise field.
                float2 samplePos = worldBasePos.xz + flowOffset;
                float height = GetHeight(samplePos, flowT);

                float eps = 0.05;
                float hR = GetHeight(samplePos + float2(eps, 0), flowT);
                float hL = GetHeight(samplePos - float2(eps, 0), flowT);
                float hU = GetHeight(samplePos + float2(0, eps), flowT);
                float hD = GetHeight(samplePos - float2(0, eps), flowT);
// Central differences approximate the height-field gradient for procedural normals.
                float2 gradient = float2(hR - hL, hU - hD) / (2.0 * eps);

                float trailEps = 0.3;
                float tR = SampleOceanTrailMask(worldBasePos.xz + float2(trailEps, 0));
                float tL = SampleOceanTrailMask(worldBasePos.xz - float2(trailEps, 0));
                float tU = SampleOceanTrailMask(worldBasePos.xz + float2(0, trailEps));
                float tD = SampleOceanTrailMask(worldBasePos.xz - float2(0, trailEps));
// The wake-mask gradient concentrates displacement along the trail boundary.
                float2 trailGradWS = float2(tR - tL, tU - tD) / (2.0 * trailEps);
                float trailPushHeight = length(trailGradWS) * _OceanTrailPushStrength;
                gradient += trailGradWS * _OceanTrailPushStrength;

                float slopeMag = length(gradient);
                float pullFactor = saturate(slopeMag) * _PullStrength;

// Reconstruct the surface normal directly from dh/dx and dh/dz.
                float3 normalOS = normalize(float3(-gradient.x, 1.0, -gradient.y));

                positionOS.xz += gradient * pullFactor;
                positionOS.y += height + trailPushHeight;

                OUT.positionWS = TransformObjectToWorld(positionOS);
                OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);
                OUT.normalWS = TransformObjectToWorldNormal(normalOS);

                OUT.shadowCoord = TransformWorldToShadowCoord(OUT.positionWS);

                return OUT;
            }

// Fragment stage: lighting, view-dependent water response, stylized wake lines, and Voronoi caustics.
            float4 frag(Varyings IN) : SV_Target
            {
                float3 normalWS = normalize(IN.normalWS);

                float3 lightDir = normalize(_LightDirection.xyz);
                float diffuse = saturate(dot(normalWS, lightDir));

// Apply URP main-light shadow attenuation to the procedural surface.
                float shadowAttenuation = MainLightRealtimeShadow(IN.shadowCoord);
                diffuse *= shadowAttenuation;

                float ambient = 0.15;
                float3 litColor = _Color.rgb * (ambient + diffuse * (1.0 - ambient));

                float3 viewDir = normalize(GetCameraPositionWS() - IN.positionWS);
                float viewDotNormal = saturate(dot(normalWS, viewDir));
// View-dependent scatter darkens near-normal views to suggest subsurface depth.
                float scatterFactor = pow(viewDotNormal, _ScatterPower) * _ScatterIntensity;
                litColor = lerp(litColor, _ScatterColor.rgb, saturate(scatterFactor));

// Grazing-angle response brightens distant water for a stylized Fresnel-like effect.
                float grazingFactor = pow(1.0 - viewDotNormal, _WhitecapGrazingPower);

                float camDist = length(GetCameraPositionWS() - IN.positionWS);
                float distanceFactor = saturate(camDist / max(_WhitecapDistance, 0.0001));

                float whitecapRaw = grazingFactor * distanceFactor;
                float whitecapMask = smoothstep(_WhitecapThreshold - _WhitecapEdgeSoftness,
                                                 _WhitecapThreshold + _WhitecapEdgeSoftness, whitecapRaw);
                float whitecapFactor = whitecapMask * _WhitecapIntensity;
                litColor = lerp(litColor, _WhitecapColor.rgb, saturate(whitecapFactor));

                float flowT = _Time.y * _MorphSpeed;
                float2 flowOffset = normalize(_FlowDirection.xz) * _FlowSpeed * _Time.y;
                float2 worldXZ = (IN.positionWS.xz + flowOffset) * _CausticScale;

                float2 trailUV = (IN.positionWS.xz - _OceanTrailCenter.xy) / _OceanTrailAreaSize + 0.5;
                float trailMask = 0.0;
                if (trailUV.x >= 0.0 && trailUV.x <= 1.0 && trailUV.y >= 0.0 && trailUV.y <= 1.0)
                {
                    trailMask = SAMPLE_TEXTURE2D(_OceanTrailTex, sampler_OceanTrailTex, trailUV).r;
                }
// Screen-space mask derivatives drive localized distortion of the surface detail.
                float2 trailGrad = float2(ddx(trailMask), ddy(trailMask));

                float lineNoise = PerlinNoise2D(IN.positionWS.xz * _OceanTrailLineNoiseScale, _Time.y) - 0.5;
                float noisyTrailMask = trailMask + lineNoise * _OceanTrailLineNoiseStrength;
                float distFromLine = abs(noisyTrailMask - _OceanTrailLineThreshold);
                float trailLineMask = 1.0 - smoothstep(0.0, _OceanTrailLineWidth, distFromLine);
                litColor += _OceanTrailLineColor.rgb * trailLineMask * _OceanTrailLineIntensity;

                float warpX = PerlinNoise2D(worldXZ * 0.5, flowT * _CausticSpeed) - 0.5;
                float warpY = PerlinNoise2D(worldXZ * 0.5 + 100.0, flowT * _CausticSpeed) - 0.5;
// First warp layer creates broad organic motion.
                float2 warpedUV = worldXZ + float2(warpX, warpY) * _CausticDistortion * 4.0;

                float warpX2 = PerlinNoise2D(warpedUV * 2.5 + 300.0, flowT * _CausticSpeed) - 0.5;
                float warpY2 = PerlinNoise2D(warpedUV * 2.5 + 400.0, flowT * _CausticSpeed) - 0.5;
// A second, higher-frequency warp adds smaller-scale breakup.
                warpedUV += float2(warpX2, warpY2) * _CausticDistortion2 * 1.5;

// The player wake adds a third local warp only where the trail exists.
                warpedUV += trailGrad * _OceanTrailDistortStrength;

                float3 f = Voronoi2D(warpedUV);
                float edge = f.y - f.x;
// Voronoi edge distance becomes the stylized caustic line mask.
                float lineMask = 1.0 - smoothstep(0.0, _CausticLineWidth, edge);

                float corner = f.z - f.y;

                float cornerMask = 1.0 - smoothstep(0.0, _CausticCornerWidth, corner);

// Brighten line junctions while keeping ordinary Voronoi walls dimmer.
                float wallStrength = lerp(_CausticWallBrightness, 1.0, cornerMask);

                float distToWave = length(IN.positionWS.xz - _WaveWorldPos.xz);
                float waveFadeFactor = pow(saturate(distToWave / max(_WaveFadeRadius, 0.0001)), _WaveFadeSharpness);

                litColor += _CausticColor.rgb * lineMask * wallStrength * _CausticIntensity * waveFadeFactor;

                return float4(litColor, _Color.a);
            }

            ENDHLSL
        }
    }
}
