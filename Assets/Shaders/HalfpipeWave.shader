// HalfpipeWaveGenerator(플레이어가 타는, 한 번 솟아올랐다 사라지는 파도)용 셰이더.
// Ocean.shader를 새 베이스로 그대로 가져와서, halfpipe 전용 훅(uv, _RiseT, Top/Edge 강조)만 다시 얹은 버전.
Shader "Custom/HalfpipeWave"
{
    Properties
    {
        _Color ("Color", Color) = (0.49537194, 0.9547169, 0.93331236, 1)
        _LightDirection ("Light Direction", Vector) = (0.5, 1, 0.3, 0)

        _NoiseScale ("Noise Scale", Range(0.1, 5)) = 0.51
        _FlowDirection ("Flow Direction (XZ)", Vector) = (1, 0, 0, 0)
        _FlowSpeed ("Flow Speed", Range(0, 5)) = 0.34
        _MorphSpeed ("Morph Speed (Flow Noise 그래디언트 회전 속도)", Range(0, 5)) = 1.77
        _Amplitude ("Amplitude (0을 중심으로 위아래 대칭으로 솟는 높이)", Range(0, 4)) = 0.92
        _PullStrength ("Pull Strength (경사를 당기는 세기)", Range(0, 0.9)) = 0.9
        // RiseUp()/FallDown() 코루틴이 이 값을 0~1로 애니메이션시키는 걸 전제로 함
        // (C#에서 material.SetFloat("_RiseT", t) 처럼 매 프레임 갱신).
        _RiseT ("Rise T (0=사라짐, 1=완전히 솟음)", Range(0, 1)) = 0

        _WarpScale ("Warp Scale (도메인 워핑 노이즈의 스케일, 작을수록 크고 완만하게 휘어짐)", Range(0.05, 2)) = 1.603
        _WarpStrength ("Warp Strength (좌표를 얼마나 세게 휘게 할지, 노이즈 칸 단위)", Range(0, 2)) = 0.713

        _CausticColor ("Caustic Color", Color) = (1, 1, 1, 1)
        _CausticScale ("Caustic Scale (망 무늬 크기)", Range(0.1, 5)) = 0.48
        _CausticSpeed ("Caustic Speed (지형 Flow Noise 변형 속도 대비 배율)", Range(0, 2)) = 0.3
        _CausticDistortion ("Caustic Distortion (1차 도메인 워핑 세기, 큰 흐름)", Range(0, 1)) = 0.4
        _CausticDistortion2 ("Caustic Distortion 2 (2차 도메인 워핑 세기, 잘게 구불거리는 디테일)", Range(0, 1)) = 0.437
        _CausticFlowStretch ("Caustic Flow Stretch (작을수록 무늬가 길게 늘어나며 쭉 이어져 흐름)", Range(0.05, 2)) = 0.3
        _CausticLineWidth ("Caustic Line Width (선 두께)", Range(0.01, 0.5)) = 0.051
        _CausticIntensity ("Caustic Intensity (밝기)", Range(0, 3)) = 1.73
        _CausticCornerWidth ("Caustic Corner Width (마디로 인정할 반경)", Range(0.01, 0.5)) = 0.341
        _CausticWallBrightness ("Caustic Wall Brightness (마디에서 먼 선의 최소 밝기, 0~1)", Range(0, 1)) = 0.114
        _CausticFadeRange ("Caustic Fade Range (꼭대기에서 이 만큼(uv 거리) 멀어지면 완전히 흐려짐)", Range(0.01, 1)) = 0.4

        _ScatterColor ("Scatter Color (정면으로 내려다볼 때 보이는 어두운 물속 색)", Color) = (0, 0.4575615, 0.7294118, 1)
        _ScatterPower ("Scatter Power (클수록 아주 정면일 때만 어두워짐)", Range(0.5, 8)) = 1.93
        _ScatterIntensity ("Scatter Intensity (최대로 얼마나 섞을지, 0~1)", Range(0, 1)) = 0.61

        _WhitecapColor ("Whitecap Color (비스듬하고 먼 곳에서 하얗게 빛나는 색)", Color) = (1, 1, 1, 1)
        _WhitecapGrazingPower ("Whitecap Grazing Power (클수록 아주 비스듬할 때만 반응)", Range(0.5, 8)) = 6.34
        _WhitecapDistance ("Whitecap Distance (이 거리(월드 단위)부터 완전히 반영)", Range(1, 100)) = 25.9
        _WhitecapIntensity ("Whitecap Intensity (최대로 얼마나 섞을지, 0~1)", Range(0, 1)) = 0.479
        _WhitecapThreshold ("Whitecap Threshold (이 값 이상만 하얗게, 나머지는 완전히 안 보임 - 툰 느낌)", Range(0, 1)) = 0.5
        _WhitecapEdgeSoftness ("Whitecap Edge Softness (경계 앤티에일리어싱, 작을수록 툰처럼 딱 끊김)", Range(0.001, 0.5)) = 0.1

        _TopColor ("Top Color (꼭대기, 플레이어가 오를 부분의 흰색)", Color) = (1, 1, 1, 1)
        _TopSharpness ("Top Sharpness (클수록 꼭대기 극히 일부만 하얗게, 나머지는 원래 바다색)", Range(1, 32)) = 8

        // HalfpipeWaveGenerator.cs가 rideWidth 양 끝을 edgeTaperRatio만큼 원점으로 오므려서(taper)
        // 단면이 점으로 모이게 만드는데, 그 구간은 uv.x(폭 방향)는 그대로 0~1인데 실제 3D 모양은 거의
        // 한 점으로 뭉개져 있어서 uv 기반 효과(Top/Edge/EdgeBlue)가 지저분하게/불규칙하게 겹쳐 보임.
        // 이 값만큼 uv.x가 0 또는 1에 가까울 때(=테이퍼 구간) 그 효과들을 부드럽게 꺼서 문제를 피함.
        _UvEdgeFade ("UV Edge Fade (rideWidth 양 끝 이 비율만큼 uv 기반 효과를 꺼서 테이퍼 구간 안 지저분해짐 방지)", Range(0, 0.5)) = 0.15

        // 모서리(오버행으로 꺾이는 지점) 강조 - Whitecap과 똑같은 형태(pow로 만든 완만한 falloff를
        // 두 조건 곱해서 강도 결정)를 그대로 재사용. "카메라가 비스듬한지"가 아니라 "이 지점이 꺾이는
        // 지점(_EdgeT)에 얼마나 가까운지"를 grazing 자리에 넣은 것만 다름.
        _EdgeColor ("Edge Color (모서리 강조색)", Color) = (0.9, 0.98, 1, 1)
        _EdgeT ("Edge T (단면 경로상 꺾이는 지점, 0~1 - 정점 근처가 약 0.5)", Range(0, 1)) = 0.5
        _EdgeWidth ("Edge Width (이 uv 거리 안쪽만 반응)", Range(0.01, 0.5)) = 0.15
        _EdgeGrazingPower ("Edge Power (클수록 꺾이는 지점 아주 가까이서만 진해짐)", Range(0.5, 8)) = 3.0
        _EdgeIntensity ("Edge Intensity (최대로 얼마나 섞을지, 0~1)", Range(0, 1)) = 0.8

        // Whitecap 아래 깔리는 층 - "uv 기준 얼마나 꺾이는 지점(_EdgeT)에 가까운지" * "카메라가 그
        // 지점을 거의 정면으로 보는지(viewDotNormal)"를 곱해서, 두 조건 다 만족하는 곳만 진한 파랑이
        // 곱해지게(lerp가 아니라 multiply) 함 - Scatter처럼 섞는 게 아니라 그림자처럼 원래 색 위에
        // 내려앉는 느낌.
        _EdgeBlueColor ("Edge Blue Color (모서리에 곱해질 진한 파랑)", Color) = (0.1, 0.3, 0.6, 1)
        _EdgeBluePower ("Edge Blue Power (클수록 정면으로 볼 때만 반응)", Range(0.5, 8)) = 2.0
        _EdgeBlueIntensity ("Edge Blue Intensity (최대 강도, 0~1)", Range(0, 1)) = 0.6

        // Whitecap/Top(둘 다 흰색) 영역을 한 번 더 밝게 - 원래 색에 곱하는 배율이라 1보다 크면 흰색이
        // 그 이상으로 튀어서(overbright) 더 반짝이는 느낌이 남.
        _HighlightBoost ("Highlight Boost (Whitecap/Top을 몇 배 더 밝게)", Range(1, 3)) = 1.0
        _HighlightPower ("Highlight Power (클수록 아주 밝은 곳만 더 밝아짐)", Range(0.5, 8)) = 1.0

        // @@@@@@@@ 여기서부터 트레일 추가 @@@@@@@@
        // Ocean.shader와 같은 트레일 시스템 - OceanTrailPainter.cs가 Shader.SetGlobal*로 갱신하는 같은
        //   전역 텍스처/센터/크기를 그대로 재사용(트레일은 씬에 하나뿐이라 바다든 halfpipe든 같은 값을 봄).
        //   텍스처/센터/크기는 여기 Properties에 안 넣음 - Ocean.shader와 같은 이유(Properties에 있으면
        //   머티리얼 전용 값이 되어 전역 갱신이 무시됨).
        _OceanTrailDistortStrength ("Ocean Trail Distort Strength (그물망을 얼마나 세게 휠지)", Range(0, 10)) = 8.31
        _OceanTrailPushStrength ("Ocean Trail Push Strength (양옆을 얼마나 높이 밀어올릴지)", Range(0, 5)) = 1.0
        _OceanTrailLineColor ("Ocean Trail Line Color (웨이크 이중선 색)", Color) = (1, 1, 1, 1)
        _OceanTrailLineThreshold ("Ocean Trail Line Threshold (트레일 마스크가 이 값을 지나는 경계에 선이 생김)", Range(0.01, 0.99)) = 0.279
        _OceanTrailLineWidth ("Ocean Trail Line Width (선 두께)", Range(0.001, 0.3)) = 0.077
        _OceanTrailLineNoiseScale ("Ocean Trail Line Noise Scale (삐뚤빼뚤함의 잘기, 클수록 잘게 흔들림)", Range(0.1, 5)) = 1.12
        _OceanTrailLineNoiseStrength ("Ocean Trail Line Noise Strength (선을 얼마나 세게 흔들지)", Range(0, 1)) = 0.327
        _OceanTrailLineIntensity ("Ocean Trail Line Intensity (선 밝기)", Range(0, 3)) = 1.69
        // @@@@@@@@ 여기까지 트레일 추가 @@@@@@@@
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

            // @@@@@@@@ 여기서부터 그림자 추가 @@@@@@@@
            // Ocean.shader와 같은 이유 - 이 keyword 선언이 없으면 MainLightRealtimeShadow()가 컴파일
            //   시점에 "그림자 없음"(1.0 고정) 코드 경로로 빠짐.
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _SHADOWS_SOFT
            // @@@@@@@@ 여기까지 그림자 추가 @@@@@@@@

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // @@@@@@@@ 여기서부터 그림자 추가 @@@@@@@@
            // MainLightRealtimeShadow, TransformWorldToShadowCoord 등 그림자 함수는 Lighting.hlsl에 있음
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            // @@@@@@@@ 여기까지 그림자 추가 @@@@@@@@

            struct Attributes
            {
                float4 positionOS : POSITION;
                // HalfpipeWaveGenerator.cs가 만들어주는 UV: x=rideWidth 축 위치(0~1), y=단면 경로 위치
                // (0~1, 0=뒤쪽 바닥, 1=앞쪽 바닥/오버행 끝) - Top/Edge 강조가 "여기가 어디인지" 아는 유일한 방법.
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;   // Scatter/Fresnel 등 카메라 방향 계산에 필요한 월드 좌표
                float3 normalWS : TEXCOORD1;     // vert()에서 경사로 미리 계산한 진짜 노멀
                float heightT : TEXCOORD2;       // 이 정점의 노이즈 값(0~1, 워프 전) - 꼭대기일수록 1에 가까움
                float2 uv : TEXCOORD3;           // Attributes.uv를 그대로 프래그먼트로 전달
                // @@@@@@@@ 여기서부터 그림자 추가 @@@@@@@@
                float4 shadowCoord : TEXCOORD4;  // vert()에서 채워 frag()로 보간되는 그림자맵 좌표
                // @@@@@@@@ 여기까지 그림자 추가 @@@@@@@@
            };

            float4 _Color;
            float4 _LightDirection;

            float _NoiseScale;
            float4 _FlowDirection;
            float _FlowSpeed;
            float _MorphSpeed;
            float _Amplitude;
            float _PullStrength;
            float _RiseT;
            float _WarpScale;
            float _WarpStrength;
            float4 _CausticColor;
            float _CausticScale;
            float _CausticFlowStretch;
            float _CausticSpeed;
            float _CausticDistortion;
            float _CausticDistortion2;
            float _CausticLineWidth;
            float _CausticIntensity;
            float _CausticCornerWidth;
            float _CausticWallBrightness;
            float _CausticFadeRange;
            float4 _ScatterColor;
            float _ScatterPower;
            float _ScatterIntensity;
            float4 _WhitecapColor;
            float _WhitecapGrazingPower;
            float _WhitecapDistance;
            float _WhitecapIntensity;
            float _WhitecapThreshold;
            float _WhitecapEdgeSoftness;
            float4 _TopColor;
            float _TopSharpness;
            float _UvEdgeFade;
            float4 _EdgeColor;
            float _EdgeT;
            float _EdgeWidth;
            float _EdgeGrazingPower;
            float _EdgeIntensity;
            float4 _EdgeBlueColor;
            float _EdgeBluePower;
            float _EdgeBlueIntensity;
            float _HighlightBoost;
            float _HighlightPower;

            // @@@@@@@@ 여기서부터 트레일 추가 @@@@@@@@
            // Ocean.shader와 완전히 같은 이름 - OceanTrailPainter.cs가 Shader.SetGlobal*로 갱신하는 같은
            //   전역 값을 이 셰이더도 그대로 받아서 씀(씬에 트레일은 하나뿐).
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
            // @@@@@@@@ 여기까지 트레일 추가 @@@@@@@@

            // ===== Hash21 =====
            float Hash21(float2 p)
            {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }

            // ===== RandomGradient2D (Flow Noise, Perlin & Neyret 2001) =====
            float2 RandomGradient2D(float2 p, float time)
            {
                float baseAngle = Hash21(p) * 2.0 * PI;
                float rotSpeed = Hash21(p + 7.7) * 2.0 - 1.0;
                float angle = baseAngle + time * rotSpeed;
                return float2(cos(angle), sin(angle));
            }

            // ===== PerlinNoise2D =====
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

            // ===== Hash22 / Voronoi2D (Caustic 그물망용) =====
            float2 Hash22(float2 p)
            {
                return float2(Hash21(p + 17.0), Hash21(p + 43.0));
            }

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

            float2 GetWarpedPos(float2 posXZ, float time)
            {
                float2 scaledPos = posXZ * _NoiseScale;
                float2 warp = float2(
                    PerlinNoise2D(scaledPos * _WarpScale + 17.0, time),
                    PerlinNoise2D(scaledPos * _WarpScale + 91.0, time)
                ) - 0.5;
                return scaledPos + warp * _WarpStrength;
            }

            // @@@@@@@@ 여기서부터 트레일 추가 @@@@@@@@
            // 월드 XZ 위치의 트레일 마스크(0~1) 샘플링 - Ocean.shader와 완전히 같음(자세한 설명은 그쪽 참고).
            float SampleOceanTrailMask(float2 worldXZ)
            {
                float2 uv = (worldXZ - _OceanTrailCenter.xy) / _OceanTrailAreaSize + 0.5;
                if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return 0.0;
                return SAMPLE_TEXTURE2D_LOD(_OceanTrailTex, sampler_OceanTrailTex, uv, 0).r;
            }
            // @@@@@@@@ 여기까지 트레일 추가 @@@@@@@@

            // posXZ 위치의 노이즈 값 그 자체(0~1, 증폭 전) - GetHeight와 frag()의 "꼭대기 흰색" 판정이
            // 같은 값을 기준으로 삼도록 따로 뽑아냄.
            float GetNoise01(float2 posXZ, float time)
            {
                float2 warpedPos = GetWarpedPos(posXZ, time);
                return PerlinNoise2D(warpedPos, time);
            }

            // posXZ 위치의 노이즈 높이. _RiseT가 0이면 무조건 0(완전히 평평, 안 보임), 1이면
            // _Amplitude만큼 완전히 솟은 상태 - RiseUp/FallDown 애니메이션이 이 스칼라 하나로 표현됨.
            float GetHeight(float2 posXZ, float time)
            {
                float noise = GetNoise01(posXZ, time);
                return (noise * 2.0 - 1.0) * _Amplitude * _RiseT;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionOS = IN.positionOS.xyz;

                float flowT = _Time.y * _MorphSpeed;
                float2 flowOffset = normalize(_FlowDirection.xz) * _FlowSpeed * _Time.y;
                float2 samplePos = positionOS.xz + flowOffset;

                float height = GetHeight(samplePos, flowT);
                OUT.heightT = GetNoise01(samplePos, flowT);
                OUT.uv = IN.uv;

                float eps = 0.05;
                float hR = GetHeight(samplePos + float2(eps, 0), flowT);
                float hL = GetHeight(samplePos - float2(eps, 0), flowT);
                float hU = GetHeight(samplePos + float2(0, eps), flowT);
                float hD = GetHeight(samplePos - float2(0, eps), flowT);
                float2 gradient = float2(hR - hL, hU - hD) / (2.0 * eps);

                // @@@@@@@@ 여기서부터 트레일 추가 @@@@@@@@
                // 트레일은 지형 노이즈(samplePos, 오브젝트 로컬 기준)와 무관하게 항상 월드 좌표 기준이라,
                //   변형 전 오브젝트 위치를 미리 월드로 변환해서 씀(Ocean.shader와 같은 방식).
                float2 worldBasePosXZ = TransformObjectToWorld(positionOS).xz;
                float trailEps = 0.3;
                float tR = SampleOceanTrailMask(worldBasePosXZ + float2(trailEps, 0));
                float tL = SampleOceanTrailMask(worldBasePosXZ - float2(trailEps, 0));
                float tU = SampleOceanTrailMask(worldBasePosXZ + float2(0, trailEps));
                float tD = SampleOceanTrailMask(worldBasePosXZ - float2(0, trailEps));
                float2 trailGradWS = float2(tR - tL, tU - tD) / (2.0 * trailEps);
                // _RiseT를 곱하는 이유: 파도가 안 솟아있을 때(평평/안 보이는 상태)는 트레일 push도 같이
                //   꺼져야 함 - 안 그러면 파도가 없는데 그 자리만 봉긋 솟아 보이는 어색한 상황이 생김.
                float trailPushHeight = length(trailGradWS) * _OceanTrailPushStrength * _RiseT;
                gradient += trailGradWS * _OceanTrailPushStrength * _RiseT;
                // @@@@@@@@ 여기까지 트레일 추가 @@@@@@@@

                float slopeMag = length(gradient);
                float pullFactor = saturate(slopeMag) * _PullStrength;

                float3 normalOS = normalize(float3(-gradient.x, 1.0, -gradient.y));

                positionOS.xz += gradient * pullFactor;
                // @@@@@@@@ 여기서부터 트레일 추가 @@@@@@@@
                positionOS.y += height + trailPushHeight;
                // @@@@@@@@ 여기까지 트레일 추가 @@@@@@@@

                OUT.positionWS = TransformObjectToWorld(positionOS);
                OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);
                OUT.normalWS = TransformObjectToWorldNormal(normalOS);
                // @@@@@@@@ 여기서부터 그림자 추가 @@@@@@@@
                OUT.shadowCoord = TransformWorldToShadowCoord(OUT.positionWS);
                // @@@@@@@@ 여기까지 그림자 추가 @@@@@@@@
                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                float3 normalWS = normalize(IN.normalWS);

                float3 lightDir = normalize(_LightDirection.xyz);
                float diffuse = saturate(dot(normalWS, lightDir));

                // @@@@@@@@ 여기서부터 그림자 추가 @@@@@@@@
                float shadowAttenuation = MainLightRealtimeShadow(IN.shadowCoord);
                diffuse *= shadowAttenuation;
                // @@@@@@@@ 여기까지 그림자 추가 @@@@@@@@

                float ambient = 0.15;
                float3 litColor = _Color.rgb * (ambient + diffuse * (1.0 - ambient));

                // Scatter
                float3 viewDir = normalize(GetCameraPositionWS() - IN.positionWS);
                float viewDotNormal = saturate(dot(normalWS, viewDir));
                float scatterFactor = pow(viewDotNormal, _ScatterPower) * _ScatterIntensity;
                litColor = lerp(litColor, _ScatterColor.rgb, saturate(scatterFactor));

                // Whitecap (카메라가 비스듬하고 먼 곳)
                float grazingFactor = pow(1.0 - viewDotNormal, _WhitecapGrazingPower);
                float camDist = length(GetCameraPositionWS() - IN.positionWS);
                float distanceFactor = saturate(camDist / max(_WhitecapDistance, 0.0001));
                float whitecapRaw = grazingFactor * distanceFactor;
                float whitecapMask = smoothstep(_WhitecapThreshold - _WhitecapEdgeSoftness,
                                                 _WhitecapThreshold + _WhitecapEdgeSoftness, whitecapRaw);
                float whitecapFactor = whitecapMask * _WhitecapIntensity;
                litColor = lerp(litColor, _WhitecapColor.rgb, saturate(whitecapFactor));

                // "uv 기준 얼마나 꺾이는 지점(_EdgeT)에 가까운지" - 모서리 강조(Edge)와 아래 파랑 곱하기
                //   (EdgeBlue) 둘 다 이 값을 공유해서 씀.
                float edgeDistNorm = saturate(1.0 - abs(IN.uv.y - _EdgeT) / max(_EdgeWidth, 0.0001));

                // rideWidth 양 끝(uv.x가 0 또는 1에 가까움)은 C# 쪽에서 단면을 점으로 오므린(taper) 구간이라,
                //   uv 기반 효과(Top/Edge/EdgeBlue)를 그대로 켜두면 지저분하게 보임 - uv.x가 양 끝에
                //   가까울수록 0으로 부드럽게 꺼지는 마스크를 만들어서 그 구간만 죽임.
                float uvEdgeMask = smoothstep(0.0, _UvEdgeFade, IN.uv.x) * smoothstep(0.0, _UvEdgeFade, 1.0 - IN.uv.x);

                // Top(꼭대기 흰색)이 얼마나 강하게 켜질지 - 원래는 아래에서 lerp로 적용하지만, EdgeBlue가
                //   Top/Whitecap의 흰색 위에 곱해져서 탁해지는 걸 막으려면 여기서 미리 알아야 함.
                float topFactor = pow(saturate(IN.heightT), _TopSharpness) * uvEdgeMask;

                // 모서리 파랑 곱하기(Whitecap 밑에 깔리는 층): edgeDistNorm(모서리에 가까운지) *
                //   pow(viewDotNormal, power)(카메라가 그 지점을 거의 정면으로 보는지, 1에 가까울수록
                //   정면) 를 곱해서, "모서리면서 동시에 카메라가 거의 수직으로 내려다보는 곳"만 진한
                //   파랑이 원래 색에 곱해지게 함(lerp로 섞는 게 아니라 *=로 어둡게 눌러앉힘).
                //   whiteMask: Whitecap이나 Top(둘 다 흰색)이 이미 강하게 켜진 지점은 (1-factor)로
                //   깎아서 거의 0으로 만듦 - 그래야 흰색 위에 파랑을 곱해서 탁해지는 일이 없음.
                float whiteMask = (1.0 - saturate(whitecapFactor)) * (1.0 - saturate(topFactor));
                float edgeBlueFactor = edgeDistNorm * pow(viewDotNormal, _EdgeBluePower) * _EdgeBlueIntensity * whiteMask * uvEdgeMask;
                litColor *= lerp(float3(1, 1, 1), _EdgeBlueColor.rgb, saturate(edgeBlueFactor));

                // 꼭대기(플레이어가 오를 부분) 흰색: heightT가 1에 가까울수록 극단적으로 하얗게.
                litColor = lerp(litColor, _TopColor.rgb, topFactor);

                // 밝은 곳(Whitecap/Top)을 한 번 더: max(topFactor, whitecapFactor)로 "둘 중 더 강하게
                //   켜진 쪽"을 밝기 기준으로 삼고, pow로 모양을 다듬은 뒤 1~_HighlightBoost 배율로
                //   곱함(lerp가 아니라 *= 배율이라 1.0을 넘어서 더 밝게 튈 수 있음 - overbright).
                //   _HighlightPower가 클수록 이미 아주 밝은 곳(mask가 1에 가까운 곳)만 반응하고, 어중간한
                //   곳은 거의 안 밝아짐(_TopSharpness 때와 같은 pow의 성질).
                float highlightMask = pow(saturate(max(topFactor, whitecapFactor)), _HighlightPower);
                litColor *= 1.0 + highlightMask * (_HighlightBoost - 1.0);

                // 모서리(오버행으로 꺾이는 지점) 강조: Whitecap과 완전히 같은 형태(pow로 완만한 falloff
                //   만들고, 그대로 lerp에 넣음 - 문턱으로 딱 끊지 않고 부드럽게) - "카메라가 비스듬한지" 대신
                //   "uv.y가 _EdgeT에 얼마나 가까운지"를 grazing 자리에 넣음.
                float edgeGrazingFactor = pow(edgeDistNorm, _EdgeGrazingPower) * _EdgeIntensity * uvEdgeMask;
                litColor = lerp(litColor, _EdgeColor.rgb, saturate(edgeGrazingFactor) * saturate(_RiseT));

                // @@@@@@@@ 여기서부터 트레일 추가 @@@@@@@@
                // 트레일: Ocean.shader와 같은 계산(자세한 설명은 그쪽 참고). 여기는 uv 기반 Caustic이라
                //   트레일 왜곡/선 자체는 월드 좌표 기준으로 계산해서 아래 causticUV(uv 기반) 워핑에 더함 -
                //   스케일 단위가 다르지만(uv 기반 vs 월드 기반), 각자 노출된 세기(Distort/Line Width 등)로
                //   맞추면 되니 실용적으로 문제 없음.
                float2 trailUV = (IN.positionWS.xz - _OceanTrailCenter.xy) / _OceanTrailAreaSize + 0.5;
                float trailMask = 0.0;
                if (trailUV.x >= 0.0 && trailUV.x <= 1.0 && trailUV.y >= 0.0 && trailUV.y <= 1.0)
                {
                    trailMask = SAMPLE_TEXTURE2D(_OceanTrailTex, sampler_OceanTrailTex, trailUV).r;
                }
                float2 trailGrad = float2(ddx(trailMask), ddy(trailMask));

                float lineNoise = PerlinNoise2D(IN.positionWS.xz * _OceanTrailLineNoiseScale, _Time.y) - 0.5;
                float noisyTrailMask = trailMask + lineNoise * _OceanTrailLineNoiseStrength;
                float distFromLine = abs(noisyTrailMask - _OceanTrailLineThreshold);
                float trailLineMask = 1.0 - smoothstep(0.0, _OceanTrailLineWidth, distFromLine);
                litColor += _OceanTrailLineColor.rgb * trailLineMask * _OceanTrailLineIntensity * saturate(_RiseT);
                // @@@@@@@@ 여기까지 트레일 추가 @@@@@@@@

                // Caustic 그물망: 월드 좌표 대신 폭포 때처럼 IN.uv 기반으로 샘플링 - uv.y가 그대로
                //   메쉬의 단면 경로(등 -> 꼭대기 -> 오버행)를 따라가니까, 여기서 스크롤시키면 실제 표면을
                //   따라 쭉 이어져서 흐르는 것처럼 보임(월드 좌표를 밀 때는 무늬가 표면 곡선을 안 따라가고
                //   그냥 평행이동만 해서 어색했음). scrollY에 uv.y 자체를 stretch 배율로 넣는 게 핵심 -
                //   그래야 "제자리에서 출렁"이 아니라 uv.y가 커질수록 새 무늬가 계속 나타나며 흘러가 보임.
                float flowSign = (IN.uv.y > _EdgeT) ? -1.0 : 1.0;
                float scrollY = IN.uv.y * _CausticFlowStretch + flowSign * _Time.y * _FlowSpeed;
                // *10: uv는 0~1 범위라 월드 단위보다 훨씬 작음 - Voronoi 씨앗 격자가 너무 안 쪼개지고
                //   뭉치지 않도록 _CausticScale 앞에 상수를 곱해 스케일을 맞춤.
                float2 causticUV = float2(IN.uv.x, scrollY) * _CausticScale * 10.0;
                float flowT2 = _Time.y * _MorphSpeed;

                float warpX = PerlinNoise2D(causticUV * 0.5, flowT2 * _CausticSpeed) - 0.5;
                float warpY = PerlinNoise2D(causticUV * 0.5 + 100.0, flowT2 * _CausticSpeed) - 0.5;
                float2 warpedUV = causticUV + float2(warpX, warpY) * _CausticDistortion * 4.0;

                float warpX2 = PerlinNoise2D(warpedUV * 2.5 + 300.0, flowT2 * _CausticSpeed) - 0.5;
                float warpY2 = PerlinNoise2D(warpedUV * 2.5 + 400.0, flowT2 * _CausticSpeed) - 0.5;
                warpedUV += float2(warpX2, warpY2) * _CausticDistortion2 * 1.5;

                // @@@@@@@@ 여기서부터 트레일 추가 @@@@@@@@
                warpedUV += trailGrad * _OceanTrailDistortStrength * saturate(_RiseT);
                // @@@@@@@@ 여기까지 트레일 추가 @@@@@@@@

                float3 f = Voronoi2D(warpedUV);
                float edge = f.y - f.x;
                float lineMask = 1.0 - smoothstep(0.0, _CausticLineWidth, edge);

                float corner = f.z - f.y;
                float cornerMask = 1.0 - smoothstep(0.0, _CausticCornerWidth, corner);
                float wallStrength = lerp(_CausticWallBrightness, 1.0, cornerMask);

                // 꼭대기(_EdgeT)에서 uv.y로 얼마나 멀어졌는지(flowDist)를 구해서, _CausticFadeRange를
                //   넘어서면(=일정 아래로 내려가면) 완전히 0(안 보임)이 되게 함 - 폭포 페이드와 같은 방식.
                float flowDist = abs(IN.uv.y - _EdgeT);
                float causticFadeFactor = 1.0 - saturate(flowDist / max(_CausticFadeRange, 0.0001));

                litColor += _CausticColor.rgb * lineMask * wallStrength * _CausticIntensity * causticFadeFactor;

                return float4(litColor, _Color.a);
            }

            ENDHLSL
        }
    }
}
