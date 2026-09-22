// 처음부터 다시 따라가는 연습용. 한 번에 한 스테이지씩만 진행 (다음 스테이지는 이거 끝내고 요청하면 이어서 드림)
// 완성본은 Ocean_Reference.shader에 백업돼 있음. 막히면 비교.
//
// 지금 단계: STAGE 0 완료 (빈 셰이더, 파이프라인 확인용 단색)
// 다음 목표: STAGE 1 - 사인파 1개로 y축만 흔들기

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

        // HalfpipeWave(플레이어가 타는 파도)가 있는 위치를 외부(C#)에서 받아서, 그 근처는 Ocean의
        // Caustic 그물망을 흐리게(안 보이게) 만듦 - 두 무늬가 겹쳐서 지저분해 보이는 걸 막기 위함.
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

        // @@@@@@@@ 여기서부터 트레일 추가 @@@@@@@@
        // 이동체(플레이어 등)가 지나간 자리의 물살 왜곡 트레일. 새 색을 칠하는 대신, 이미 있는 Caustic
        //   그물망(Voronoi) 좌표를 트레일 자리에서만 추가로 휘어서 "물결이 끌려가며 출렁이는" 것처럼 보이게 함.
        // _OceanTrailTex(텍스처)는 매 프레임 OceanTrailPainter.cs가 Shader.SetGlobalTexture로 갱신하는
        //   값이라 Properties에 넣으면 안 됨 - Properties에 있으면 "머티리얼 전용 값"이 되어 항상 그
        //   기본값이 이기고 전역(Global) 갱신은 무시되기 때문(아래 HLSL 변수 선언 쪽에 전역으로만 있음).
        // 반면 왜곡 세기는 디자이너가 인스펙터에서 한 번 정해두는 값(Caustic Distortion들과 같은 성격)이라
        //   여기 Properties에 있는 게 맞음.
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

            // 메인 라이트 그림자 관련 URP keyword 선언 - 이게 없으면 MainLightRealtimeShadow()가
            //   컴파일 시점에 "그림자 없음"(1.0 고정) 코드 경로로 빠져서, 4/4 TODO를 맞게 채워도
            //   실제로는 그림자가 전혀 반영되지 않음.
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // MainLightRealtimeShadow, TransformWorldToShadowCoord 등 그림자 함수는 Lighting.hlsl에 있음
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;   // Scatter/Fresnel 등 카메라 방향 계산에 필요한 월드 좌표
                float3 normalWS : TEXCOORD1;     // vert()에서 경사로 미리 계산한 진짜 노멀(정점별로 다름 ->
                                                  // 삼각형 안에서도 부드럽게 보간됨. ddx/ddy는 삼각형 하나당
                                                  // 값이 고정이라 각지게 보였던 문제를 이걸로 해결)

                float4 shadowCoord : TEXCOORD2;  // vert()에서 채워 frag()로 보간되는 그림자맵 좌표
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

            // @@@@@@@@ 여기서부터 트레일 추가 @@@@@@@@
            // 텍스처는 float/float4와 선언 방식이 다름 - TEXTURE2D(텍스처 자체)와 SAMPLER(어떻게 읽을지,
            // 필터링/클램프 방식)를 따로 선언하고, 실제로 값을 읽을 땐 SAMPLE_TEXTURE2D(텍스처, 샘플러, uv)로
            // 둘을 같이 넘겨줌 - URP의 텍스처 접근 방식(옛날 sampler2D 한 줄이면 끝나던 것과 다름).
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

            // ===== STAGE 1 =====
            // 목표: 2D 좌표 하나(p) -> 0~1 사이 고정된 의사난수 하나. 같은 p를 넣으면 항상 같은 값이 나와야 함.
            // Hash(해시) 함수: "같은 입력 -> 항상 같은 출력"이면서 "입력이 조금만 달라도 출력은 완전히
            //   달라 보이는" 결정적 함수. GPU엔 진짜 난수 생성기가 없어서 "위치 기반 가짜 난수"를 만드는
            //   용도로 셰이더에서 재활용됨. 네이밍 관례(Shadertoy 등): HashXY, X=입력 차원, Y=출력 차원 ->
            //   Hash21 = 2D 입력 -> 스칼라(1개) 출력. (Flow Noise는 시간을 별도 축으로 안 쓰고 x,z 2축만
            //   쓰기 때문에 3D 대신 2D 해시로 충분함)
            float Hash21(float2 p)
            {
                // 1단계: p의 각 성분(x,y)에 서로 다른 큰 상수를 곱해서 값을 크게 뒤섞는다.
                //   frac()으로 정수부를 버리고 소수부만 남김(결과는 0~1 사이 값 2개). 큰 상수를 곱하면
                //   입력의 아주 작은 차이가 곱해진 결과에서는 훨씬 크게 벌어지고, frac()으로 정수부(원래
                //   입력의 "큰 흐름" 정보)를 버리면 소수부(증폭된 미세한 차이)만 남아서 완전히 다른 값처럼 보임.
                p = frac(p * float2(123.34, 456.21));
                // 2단계: 지금 p는 x,y가 서로 상관없이 따로 놀고 있음. dot(p, p+45.32)를 계산해서 p 전체에
                //   더해줌 -> 두 성분이 서로 영향을 주고받게 뒤섞는 2차 뒤섞기(제곱항이 들어가는 게 핵심 -
                //   선형 항만으로는 이 정도로 안 섞임). dot()은 이 계산을 한 줄로 압축해주는 내장 함수일
                //   뿐, 수학적으로 반드시 dot이어야 하는 건 아니고, 이 해시는 엄밀하게 유도된 공식이 아니라
                //   경험적으로 잘 섞이면 되는 트릭이라 += 대신 -=를 써도 여전히 유효한 해시가 됨.
                p += dot(p, p + 45.32);
                // 3단계: p.x와 p.y를 곱하고 frac()을 씌워서 최종 스칼라 값 하나(0~1)를 반환.
                return frac(p.x * p.y);
            }

            // ===== STAGE 2 (Flow Noise, Perlin & Neyret 2001) =====
            // *** 왜 이 방식으로 바꿨는지 ***
            // 원래는 PerlinNoise3D(x, z, 시간)처럼 시간을 노이즈의 3번째 축으로 넣어서, 시간이 지날수록
            //   한 번도 안 가본 새 격자점(z축 방향)으로 계속 걸어 들어가는 방식이었음 - "격자점 값 자체는
            //   절대 안 바뀌고, 대신 시간에 따라 다른 격자점 조합을 보여준다"는 원리라 이론적으론 맞는
            //   접근인데, 실제로 봤을 때 "봉우리가 완전히 사라지고 다른 랜덤한 위치에서 새로 튀어오르는"
            //   느낌이 원하는 만큼 안 나오고, 봉우리 위치 자체는 안 바뀐 채 높이만 살짝 흔들리는 것처럼
            //   보였음. Contrast/PeakSharpness(대비를 줘서 대부분을 평평하게 누르고 극단값만 남기는 방법)로
            //   보완을 시도했지만 그것도 근본적인 해결은 아니었음.
            // 그래서 "격자점에 배정된 그래디언트 값 자체를 시간에 따라 계속 바꾸면 안 되나?"라는 질문이
            //   나왔었고, 처음엔 "그러면 이웃 점들과 안 맞아서 노이즈가 끊긴다"고 판단해 불가능하다고
            //   결론 내렸었음 - 근데 이건 틀린 결론이었음. "값을 다른 값으로 통째로 갈아치우는 것"과 "값을
            //   매끄럽게 변화시키는 것"은 다른 얘기. 그래디언트가 "각도"라는 걸 이용하면, 그 각도를 시간에
            //   따라 조금씩 회전시킬 수 있고, 회전은 연속적인 변화라 이웃 점들과 안 끊기고 자연스럽게
            //   이어짐. 이게 Ken Perlin과 Fabrice Neyret이 2001년에 제안한 "Flow Noise" 기법.
            //
            // 목표: 2D 격자점 좌표(p) -> 그 점의 그래디언트(단위벡터). 근데 "고정된 방향"이 아니라
            //   시간에 따라 계속 회전하는 방향 - 이게 일반 Perlin noise와의 핵심 차이.
            // 원리: 각 격자점마다 (1) 기준 각도 하나 + (2) 그 점만의 고유한 회전 속도를 무작위로 배정해두고,
            //   실제 각도는 "기준 각도 + 시간*회전속도"로 계산 -> 시간이 지나면 바늘이 시계처럼 돌아감.
            //   격자점의 각도(값) 자체는 매 순간 계속 바뀌지만, 변화가 연속적(회전)이라 끊기지 않음.
            float2 RandomGradient2D(float2 p, float time)
            {
                float baseAngle = Hash21(p) * 2.0 * PI;          // 이 격자점의 "출발" 각도
                // 이 격자점만의 회전 속도(-1~1). 모든 격자점이 똑같은 속도로 돌면 화면 전체가 그냥 통째로
                // 한 방향으로 회전하는 것처럼 보여서 부자연스러움 - 격자점마다 속도/방향을 다르게 줘야
                // 소용돌이처럼 자연스럽게 보임.
                float rotSpeed = Hash21(p + 7.7) * 2.0 - 1.0;
                float angle = baseAngle + time * rotSpeed;
                // 길이 1인 2D 단위벡터. cos/sin이 반지름 1인 원 위에서 각도 angle만큼 돈 바늘 끝 좌표인
                // 원리는 이전 3D 버전(RandomGradient3D, 지금은 삭제됨)에서 구면좌표로 그래디언트를 만들던
                // 것과 동일한 발상의 2D 버전. (그 3D 버전 요약, 잊지 않게 여기 남겨둠 - 자세한 유도는
                // WAVE_LEARNING_LOG.md 27단계 참고)
                //   - x,y,z를 각각 독립적으로 뽑아 정규화하면 정육면체 모서리(대각선) 방향이 통계적으로
                //     더 자주 나오는 편향이 생김(정육면체는 모서리 쪽 부피가 더 넓어서)
                //   - 그래서 위도(z, -1~1 균등)와 경도(theta, 0~2π 균등)를 뽑고 r=sqrt(1-z²)(원 반지름)로
                //     구 표면 위에 편향 없이 고르게 퍼지는 방향을 구했음 (아르키메데스 원통 투영 정리)
                //   - 2D는 애초에 "원 하나"만 있어서 이런 편향 문제 자체가 없음 -> 그냥 각도 하나 뽑아서
                //     cos/sin만 하면 원 위에 고르게 퍼짐 (3D의 "구 표면 고르게 뽑기" 문제가 2D에선
                //     "원 둘레 고르게 뽑기"로 단순해지고, 원 둘레는 각도만 균등하게 뽑으면 자동으로 고르게 됨)
                return float2(cos(angle), sin(angle));
            }

            // ===== STAGE 3 =====
            // 목표: 2D 좌표(p) 하나 -> 부드럽게 이어지는 노이즈 값(대략 0~1) 하나.
            // 원리: p가 들어있는 정사각형 셀을 찾고, 그 4개 모서리마다 "바람개비 영향력"(dot)을 구한 뒤
            //       quintic 곡선으로 부드럽게 보간해서 하나로 합침.
            float PerlinNoise2D(float2 p, float time)
            {
                // cell = p가 속한 정사각형의 "왼쪽 아래" 모서리 좌표(정수). f = 그 안에서 p의 상대 위치(0~1).
                //   f = p - cell 이므로, cell을 원점(0,0)으로 놓고 봤을 때 p가 어디쯤 있는지를 나타냄.
                float2 cell = floor(p);
                float2 f = frac(p);

                // cell+오프셋 = 그 꼭짓점의 "실제 좌표"(RandomGradient2D에 넣어서 그 꼭짓점 전용 그래디언트를 뽑기 위함).
                // f-오프셋 = "그 꼭짓점에서 p까지의 벡터". f-오프셋을 반드시 해야 하는 이유(1D로 단순화한 예):
                //
                //   cell
                //   ↓
                //   ●--------------------●
                //   0         p(f=0.7)    1
                //
                //   정상 계산(오프셋을 뺌):
                //     00 꼭짓점: dot(gradient00, f)       // f     = +0.7 (00에서 p까지)
                //     10 꼭짓점: dot(gradient10, f - 1)   // f - 1 = -0.3 (10에서 p까지, 반대편이라 더 가깝고 부호도 반대)
                //
                //   만약 -오프셋을 안 하고 f를 그대로 재사용하면:
                //     00 꼭짓점: dot(gradient00, f)   // +0.7
                //     10 꼭짓점: dot(gradient10, f)   // +0.7  ← 틀림! 10 꼭짓점도 "내가 00인 것처럼" 착각하고 계산하게 됨
                //
                //   즉 -오프셋을 빼먹으면 모든 꼭짓점이 실제로는 저마다 다른 위치에 있는데도
                //   전부 "자기가 00 꼭짓점인 줄 알고" p까지의 거리를 계산해버리는 셈이 됨.
                //
                // dot(그래디언트, 벡터) = 이 꼭짓점 입장에서 p가 자기 그래디언트 방향과 얼마나 비슷한
                //   방향에 있는지를 나타내는 스칼라 (Value Noise처럼 거리만 보는 게 아니라 방향까지 반영되어
                //   격자 경계가 덜 도드라짐)
                float n00 = dot(RandomGradient2D(cell + float2(0,0), time), f - float2(0,0));
                float n10 = dot(RandomGradient2D(cell + float2(1,0), time), f - float2(1,0));
                float n01 = dot(RandomGradient2D(cell + float2(0,1), time), f - float2(0,1));
                float n11 = dot(RandomGradient2D(cell + float2(1,1), time), f - float2(1,1));

                // f(0~1)를 quintic 곡선(6t^5-15t^4+10t^3)으로 워프한 u를 만든다.
                //   계수 6,-15,10은 아무 숫자나 고른 게 아니라 "t=1일 때 값=1, 1차 미분=0, 2차 미분=0"이라는
                //   3개 조건을 만족하는 연립방정식의 유일한 해. 2차 미분까지 0으로 만드는 이유는, 최종적으로
                //   화면에 보이는 건 높이 자체가 아니라 그 기울기(법선→빛 반사)라서, 기울기까지 부드럽게
                //   이어지려면 그 재료인 이 곡선이 한 단계 더(2차 미분까지) 매끈해야 하기 때문.
                float2 u = f*f*f*(f*(f*6.0-15.0)+10.0);

                // lerp(a,b,t)="a에서 b까지 t만큼 간 지점". lerp는 값 2개만 섞을 수 있는 도구라 4개를
                //   1개로 합치려면 2개씩 묶어 절반씩 줄이는 걸 반복해야 함(4→2→1, 총 2+1=3번,
                //   "N개를 2개씩 묶어 1개로 줄이면 N-1번 필요"한 것과 같은 원리 - 토너먼트 대진표와 동일:
                //   4명이 우승자 1명을 가리려면 2+1=3경기 필요한 것과 같음). x→y 순서는 관례일 뿐,
                //   어느 축부터 묶어도 결과는 동일함.
                float nx0 = lerp(n00, n10, u.x);
                float nx1 = lerp(n01, n11, u.x);
                float nxy = lerp(nx0, nx1, u.y);

                // nxy는 (단위벡터 그래디언트)·(최대 길이 √2/2≈0.71인 거리벡터)라서 대략 -0.71~0.71 범위.
                //   *0.5+0.5는 "입력이 -1~1"이라는 가정하에 0~1로 옮기는 리매핑 공식
                //   (new=(x-oldMin)/(oldMax-oldMin)*(newMax-newMin)+newMin 에서 oldMin=-1,oldMax=1,
                //   newMin=0,newMax=1을 대입한 특수 케이스). 실제 범위(-0.71~0.71)가 그 안에 통째로
                //   들어가서 결과가 0~1을 벗어나진 않지만, 끝까지는 못 감.
                return nxy * 0.5 + 0.5;
            }

            // Hash21의 2D 버전. 서로 다른 오프셋으로 Hash21을 두 번 호출해서 2개의 독립적인 난수를 만듦
            // (RandomGradient2D에서 h1,h2 뽑을 때와 같은 트릭).
            float2 Hash22(float2 p)
            {
                return float2(Hash21(p + 17.0), Hash21(p + 43.0));
            }

            // Voronoi(Cellular) Noise: Perlin과 원리가 다른 노이즈. 격자 셀마다 무작위 위치에 "씨앗 점"을
            //   하나씩 두고, 각 지점에서 가장 가까운 씨앗(f1)과 두 번째로 가까운 씨앗(f2)까지의 거리를 계산.
            //   f2-f1이 0에 가까운 지점 = 두 셀의 경계선이라, 이걸 이용해 그물망 모양의 선을 뽑아낼 수 있음.
            //   지형(GetHeight)과는 완전히 독립 - frag()의 흰 줄 무늬 전용으로만 씀.
            float3 Voronoi2D(float2 p)
            {
                float2 cell = floor(p);
                float2 f = frac(p);

                float f1 = 8.0;
                float f2 = 8.0;
                float f3 = 8.0; // [1단계 추가] 3등 거리도 f1,f2랑 똑같은 이유로 "아직 없음" 초기값 8

                // 내 셀뿐 아니라 3x3(이웃 8개 포함) 셀의 씨앗까지 다 확인 - 씨앗이 이웃 셀에 있어도 내
                // 셀 안의 p보다 가까울 수 있기 때문(셀 경계 바로 앞/뒤 상황).
                for (int y = -1; y <= 1; y++)
                {
                    for (int x = -1; x <= 1; x++)
                    {
                        float2 neighbor = float2(x, y);
                        float2 seed = Hash22(cell + neighbor);
                        float dist = length(neighbor + seed - f);

                        // [1단계 추가] f3까지 순위 정렬에 끼워넣음: 새 1등이 나오면 기존 1등→2등, 기존 2등→3등
                        if (dist < f1) { f3 = f2; f2 = f1; f1 = dist; }
                        else if (dist < f2) { f3 = f2; f2 = dist; }
                        else if (dist < f3) { f3 = dist; }
                    }
                }
                return float3(f1, f2, f3); // [1단계 추가] 이제 3개를 반환
            }

            // posXZ(스케일 전 좌표)를 노이즈 스케일 적용 + 도메인 워핑까지 거친 좌표로 변환하는 헬퍼.
            //   지형 노이즈(GetHeight)와 Voronoi 씨앗 격자(GetHeight의 봉우리 계산, frag의 흰 줄)가 전부
            //   이 함수를 거친 "같은 뒤틀린 좌표"를 공유해야, 씨앗 위치와 지형/그물망이 서로 어긋나지 않음.
            float2 GetWarpedPos(float2 posXZ, float time)
            {
                float2 scaledPos = posXZ * _NoiseScale;

                // Domain Warping: 격자 "크기" 자체를 칸마다 다르게 만드는 건 어려움(이웃 셀끼리 경계가
                //   딱 들어맞아야 하는데, 크기가 제각각이면 그 경계를 양쪽에서 일관되게 정의할 수가 없음).
                //   대신 격자에 들어가는 좌표를 넣기 전에 미리 살짝 뒤틀어버리면, 격자 자체(경계=항상 정수)는
                //   그대로 두면서도 결과적으로 셀 경계가 삐뚤빼뚤해져서 규칙적인 그리드/에일리어싱 느낌이
                //   깨짐. warp를 만드는 노이즈는 _WarpScale(보통 원본보다 작게, 더 크고 완만한 스케일)로
                //   따로 샘플링해서 원본 무늬와 다른 리듬으로 움직이게 함. -0.5는 결과(noise, 0~1)를
                //   -0.5~0.5로 되돌려서 "어느 방향으로든" 밀 수 있게 하기 위함(0~1만 쓰면 항상 한쪽으로만 밀림).
                float2 warp = float2(
                    PerlinNoise2D(scaledPos * _WarpScale + 17.0, time),
                    PerlinNoise2D(scaledPos * _WarpScale + 91.0, time)
                ) - 0.5;
                return scaledPos + warp * _WarpStrength;
            }

            // @@@@@@@@ 여기서부터 트레일 추가 @@@@@@@@
            // 월드 XZ 위치의 트레일 마스크(0~1)를 샘플링하는 헬퍼. vert()는 픽셀 셰이더가 아니라서
            // ddx/ddy(화면 미분)를 못 쓰니, 이 함수를 상하좌우로 여러 번 불러서 유한차분으로 기울기를
            // 구하는 방식(GetHeight 방식과 동일)을 쓸 것. SAMPLE_TEXTURE2D_LOD를 쓰는 이유: 버텍스
            // 셰이더에는 자동 밉맵 레벨 계산이 없어서(화면상 픽셀 크기를 모름), 밉레벨을 직접 0으로
            // 지정해야 함(일반 SAMPLE_TEXTURE2D는 프래그먼트 전용).
            float SampleOceanTrailMask(float2 worldXZ)
            {
                float2 uv = (worldXZ - _OceanTrailCenter.xy) / _OceanTrailAreaSize + 0.5;
                if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return 0.0;
                return SAMPLE_TEXTURE2D_LOD(_OceanTrailTex, sampler_OceanTrailTex, uv, 0).r;
            }
            // @@@@@@@@ 여기까지 트레일 추가 @@@@@@@@

            // posXZ 위치의 노이즈 높이(-_Amplitude~+_Amplitude)만 뽑아내는 헬퍼. vert()에서 정점 자기
            // 자신의 높이뿐 아니라, 바로 옆(상하좌우)의 높이도 같은 방식으로 구해서 "경사(기울기)"를
            // 유한차분으로 근사하는 데 씀 (WAVE_LEARNING_LOG.md 13단계와 같은 기법).
            float GetHeight(float2 posXZ, float time)
            {
                float2 warpedPos = GetWarpedPos(posXZ, time);
                float noise = PerlinNoise2D(warpedPos, time);
                return (noise * 2.0 - 1.0) * _Amplitude;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionOS = IN.positionOS.xyz;   // Object Space 위치 복사본(이제부터 이걸 수정)

                // Flow Noise 방식: 시간을 노이즈의 3번째 축으로 넣는 대신(예전 버전), x,z 2축짜리
                // 노이즈만 쓰고 대신 각 격자점의 그래디언트 "방향" 자체를 시간에 따라 회전시킴
                // (RandomGradient2D 안의 baseAngle + time*rotSpeed). 격자점 값을 갈아치우는 게 아니라
                // 그 값(각도)을 매끄럽게 돌리는 거라, 시간이 지나도 뚝뚝 끊기지 않고 계속 다른 모양이 됨.
                float flowT = _Time.y * _MorphSpeed;

                // "한쪽으로 계속 흐르게" 하고 싶으면 정점 자체(positionOS)를 옮기면 안 되고, 노이즈를
                // 샘플링하는 좌표(samplePos)만 옮겨야 함 - 그래야 정점은 원래 자리에 그대로 있으면서 그
                // 자리에서 "보여주는 무늬"만 시간에 따라 옆으로 흘러가는 것처럼 보임. _Time.y를 정점
                // 위치에 직접 더하면 메쉬 전체가 끝없이 미끄러져 화면 밖으로 사라져버리고, 노이즈를 계산한
                // 위치와 실제 정점 위치도 어긋나버림(둘 다 이전에 확인한 문제).
                // 월드 좌표로 샘플링: 무한 타일링으로 바닥이 여러 개의 GridMeshGenerator 메쉬로 쪼개져
                //   있는데, 그 메쉬들이 로컬(Object Space) 좌표 범위를 전부 똑같이 공유함(같은 캐싱된
                //   메쉬를 재사용하니까). positionOS.xz를 그대로 쓰면 모든 타일이 "자기 로컬 좌표"에서
                //   노이즈를 다시 처음부터 읽는 꼴이라, 타일 경계(로컬 좌표가 리셋되는 지점)에서 물결
                //   모양이 뚝 끊김. 월드 좌표는 타일이 몇 개로 쪼개져 있든 이어지는 하나의 값이라, 같은
                //   월드 지점은 어느 타일 소속이든 항상 같은 노이즈 입력 -> 같은 출력이 나와서 안 끊김.
                //   (frag()의 Caustic 그물망은 이미 positionWS를 쓰고 있어서 원래부터 안 끊겼음 - 여기
                //   지형 높이만 늦게 맞춰주는 것)
                float3 worldBasePos = TransformObjectToWorld(positionOS);
                float2 flowOffset = normalize(_FlowDirection.xz) * _FlowSpeed * _Time.y;
                float2 samplePos = worldBasePos.xz + flowOffset;
                float height = GetHeight(samplePos, flowT);

                // 경사(기울기)가 가파른 곳은 전부 각지게 꺾어서 당김. "봉우리냐 아니냐"(높이 기준)가
                // 아니라 "가파르냐 아니냐"(경사 크기 기준)라서, 높이가 낮은 완만한 언덕의 가파른 옆면도
                // 능선/절벽처럼 각지게 잡히고, 완만한 곳은 전혀 안 건드려짐.
                //
                // 1) 경사 구하기: 이 정점의 x,z에서 아주 살짝(eps) 떨어진 상하좌우 4곳의 높이를 GetHeight로
                //    구해서 유한차분으로 근사. (오른쪽-왼쪽, 위쪽-아래쪽)이 클수록 그쪽이 오르막이라는 뜻.
                float eps = 0.05;
                float hR = GetHeight(samplePos + float2(eps, 0), flowT);
                float hL = GetHeight(samplePos - float2(eps, 0), flowT);
                float hU = GetHeight(samplePos + float2(0, eps), flowT);
                float hD = GetHeight(samplePos - float2(0, eps), flowT);
                // 왜 2*eps로 나누나: 경사 = 높이차이/수평거리 인데, hR을 잰 지점(x+eps)과 hL을 잰 지점(x-eps)
                // 사이의 실제 수평 거리가 eps가 아니라 eps+eps=2*eps이기 때문(P를 기준으로 오른쪽으로 eps,
                // 왼쪽으로 eps 떨어진 두 점 사이 거리니까). 예: eps=0.05, L=9.95, R=10.05 -> 거리는
                // 10.05-9.95=0.1=2*0.05. 즉 2*eps는 임의로 붙인 숫자가 아니라 hR/hL을 측정한 두 지점 사이의
                // 진짜 거리 그 자체.
                float2 gradient = float2(hR - hL, hU - hD) / (2.0 * eps);

                // @@@@@@@@ 여기서부터 트레일 추가 @@@@@@@@
                // 트레일이 지나간 자리 양옆을 밀어올리는 높이(push). 지형 노이즈(samplePos, flowOffset 적용됨)와
                //   무관하게 순수 월드 위치(worldBasePos.xz) 기준으로 트레일 마스크의 기울기를 구함 - 트레일이
                //   진행 방향으로 길게 늘어진 "혜성 꼬리" 모양이라, 기울기는 자연스럽게 진행 방향에 수직인
                //   좌우 방향으로 가장 크게 나옴(양옆이 봉긋 솟는 웨이크 모양이 저절로 만들어짐).
                //   eps는 지형용(0.05)보다 훨씬 크게 잡음 - 트레일 텍스처 한 칸이 지형 노이즈보다 훨씬
                //   성기기(areaSize 40을 256칸이 나눠 가짐 ≈ 칸당 0.16m) 때문에, 너무 작은 eps로 재면
                //   같은 텍셀만 반복해서 읽어 기울기가 뚝뚝 끊겨 보임.
                float trailEps = 0.3;
                float tR = SampleOceanTrailMask(worldBasePos.xz + float2(trailEps, 0));
                float tL = SampleOceanTrailMask(worldBasePos.xz - float2(trailEps, 0));
                float tU = SampleOceanTrailMask(worldBasePos.xz + float2(0, trailEps));
                float tD = SampleOceanTrailMask(worldBasePos.xz - float2(0, trailEps));
                float2 trailGradWS = float2(tR - tL, tU - tD) / (2.0 * trailEps);
                // length(기울기)는 "마스크가 얼마나 급하게 변하는 자리인가"라 항상 양수 -> 트레일 테두리
                //   (양옆)에서 가장 크고, 트레일 한복판이나 트레일과 먼 곳은 거의 0이라 push가 자연스럽게
                //   양옆에만 집중됨(가운데는 아직 안 밀림, 정중앙 통과 직후에나 서서히 벌어짐).
                float trailPushHeight = length(trailGradWS) * _OceanTrailPushStrength;
                // 노멀/경사 계산에도 트레일이 만든 기울기를 더해서, 밀려 올라간 부분이 그냥 밋밋하게 뜨지
                //   않고 실제로 기울어진 표면처럼 빛을 받게 함(엄밀한 미분은 아니고 근사치 - 이 셰이더의
                //   다른 노이즈 트릭들처럼 "보기에 그럴듯하면 충분하다"는 방식).
                gradient += trailGradWS * _OceanTrailPushStrength;
                // @@@@@@@@ 여기까지 트레일 추가 @@@@@@@@

                // 2) 문턱은 0으로 고정(별도 프로퍼티 없이 하드코딩) - 경사가 조금이라도 있으면 그 즉시
                //    바로 당겨지기 시작하는 게 더 예쁘고 자연스러워서, "얼마 이상부터"라는 문턱 자체를 없앰.
                //    quintic/smoothstep 계열(부드럽게 시작하는 곡선)이 아니라 선형(1차) saturate만 써서,
                //    saturate(x)=clamp(x,0,1) 자체의 "0에서 미분이 뚝 끊기는" 성질로 각지게 꺾이게 함.
                float slopeMag = length(gradient);
                float pullFactor = saturate(slopeMag) * _PullStrength;

                // 노멀을 "화면에 이미 그려진 결과"(ddx/ddy)가 아니라, 방금 구한 경사(gradient)로 직접
                //   계산 - 훨씬 정확하고, 정점마다 다른 값이라 삼각형 안에서도 부드럽게 이어짐(예전 ddx/ddy
                //   방식은 삼각형 하나 전체가 같은 노멀이라 각지게 보였음).
                //   높이 함수 h(x,z) 표면 위의 점은 (x, h, z)로 쓸 수 있고, x방향 접선은 (1, dh/dx, 0),
                //   z방향 접선은 (0, dh/dz, 1). 이 두 접선을 외적(cross)하면 표면에 수직인 노멀이 나오는데,
                //   그 결과가 정확히 (-dh/dx, 1, -dh/dz) - gradient=(dh/dx, dh/dz)이므로 코드로는
                //   float3(-gradient.x, 1, -gradient.y). "경사가 없으면(gradient=0) 노멀이 그냥 (0,1,0),
                //   즉 위를 똑바로 본다"는 당연한 경우로 검산하면 이해하기 쉬움.
                float3 normalOS = normalize(float3(-gradient.x, 1.0, -gradient.y));

                // 3) 합치기: 문턱을 넘은 만큼(pullFactor) 오르막 방향(gradient)으로 수평 이동시키고, 높이도 적용.
                //    pullFactor는 위에서 이미 트레일이 더해진 gradient로 계산됐으니, 트레일 테두리에서는
                //    이 수평 이동(xz += gradient*pullFactor)도 자동으로 더 세게 걸림 - 위로 솟을 뿐 아니라
                //    옆으로도 같이 밀려나는 느낌이 추가 코드 없이 그냥 따라옴.
                positionOS.xz += gradient * pullFactor;
                // @@@@@@@@ 여기서부터 트레일 추가 @@@@@@@@
                positionOS.y += height + trailPushHeight;
                // @@@@@@@@ 여기까지 트레일 추가 @@@@@@@@

                // Object Space(오브젝트 자기 기준 좌표)만으로는 카메라 위치/각도/시야각을 몰라서 화면에
                // 못 그림 - 아래 두 함수가 Model/View/Projection 행렬을 곱해 "화면에 그릴 좌표"(Clip Space)로
                // 바꿔줌(HLSL 자체 기능이 아니라 URP Core.hlsl이 제공하는 유틸 함수). 반드시 노이즈 변형 다음에
                // 호출해야 하는 이유: 노이즈로 "진짜 3D 위치"를 먼저 다 정한 다음에야 그걸 투영해야 함 -
                // 순서가 바뀌면 이미 눌러 찌그러진 화면 좌표에 값을 더하는 꼴이 되어 잘못된 결과가 나옴.
                OUT.positionWS = TransformObjectToWorld(positionOS);
                OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);
                // TransformObjectToWorldNormal: 위치(positionOS)랑 다르게 방향(노멀)은 오브젝트의
                //   회전/스케일을 다른 방식으로 반영해야 정확함(비균일 스케일이 있으면 위치용 행렬을
                //   그대로 쓰면 노멀이 틀어짐) - 그래서 노멀 전용 변환 함수를 따로 씀.
                OUT.normalWS = TransformObjectToWorldNormal(normalOS);

                OUT.shadowCoord = TransformWorldToShadowCoord(OUT.positionWS);

                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                // vert()에서 경사로 미리 계산해서 넘겨준 노멀. 정점마다 다른 값이 삼각형 안에서 부드럽게
                // 보간되기 때문에, 예전 ddx/ddy(삼각형 하나에 노멀 하나 고정) 방식보다 각짐이 훨씬 덜함.
                // 보간 과정에서 길이가 조금 흐트러질 수 있어 다시 normalize.
                float3 normalWS = normalize(IN.normalWS);

                float3 lightDir = normalize(_LightDirection.xyz);
                // dot(노멀, 빛방향) = 이 표면이 빛을 얼마나 정면으로 보고 있는지. 같은 방향이면 1(정면),
                // 수직이면 0, 반대 방향이면 음수(빛을 전혀 못 받는 뒷면) - saturate로 음수는 0에 클램프.
                float diffuse = saturate(dot(normalWS, lightDir));

                // 그림자 감쇠(그림자 안이면 0에 가깝고 밖이면 1)를 diffuse에 곱해 그림자를 반영
                float shadowAttenuation = MainLightRealtimeShadow(IN.shadowCoord);
                diffuse *= shadowAttenuation;

                // ambient(그림자에서도 최소한 보이는 밝기, 0~1) + diffuse(빛 받는 만큼 밝아짐)로 밝기 배율을 만듦.
                // diffuse에 곱하는 계수를 "1 - ambient"로 정확히 맞추는 게 핵심: 그래야 diffuse=1(빛 정면)일 때
                //   ambient + (1-ambient)*1 = 1.0 로 딱 떨어져서 "가장 밝은 곳 = 원래 _Color 그대로"가 보장됨.
                //   만약 그냥 ambient + diffuse처럼 계수 없이 더하면 최대 밝기가 1을 넘어(예: 0.15+1=1.15)
                //   원래 지정한 _Color보다 더 밝고 하얗게 떠버림.
                // diffuse=0(빛 반대편) -> ambient(최소 밝기), diffuse=1(정면) -> 1.0(최대 밝기) 로 항상
                //   [ambient, 1.0] 범위 안에서만 밝기가 오르내림.
                float ambient = 0.15;
                float3 litColor = _Color.rgb * (ambient + diffuse * (1.0 - ambient));

                // 산란(Scatter) 레이어: 카메라가 노멀과 가까울수록(정면으로 내려다봄) 어두운 물속 색이
                //   보이고, 카메라가 노멀과 멀수록(비스듬히 봄) 원래 표면색이 그대로 보임 - 실제 물의
                //   프레넬 반사율이 정면에서 낮고 비스듬할수록 높아지는 것과 같은 원리(정면=반사가 적어
                //   물속이 비쳐 보임, 비스듬=반사가 강해 표면색이 지배적).
                // GetCameraPositionWS(): URP가 제공하는 함수로, 지금 화면을 그리고 있는 카메라의 월드
                //   좌표를 돌려줌. 옛날(Built-in RP) 문법인 _WorldSpaceCameraPosition을 직접 쓰면 URP
                //   에선 정의가 안 돼있어서 컴파일 에러가 남 - URP에서는 이 함수를 쓰는 게 공식 방식.
                float3 viewDir = normalize(GetCameraPositionWS() - IN.positionWS);
                // dot(노멀, 시선) = 카메라가 노멀 방향과 얼마나 가까운지. 1이면 정면(카메라가 노멀 연장선
                //   위, 즉 정확히 내려다보는 상태), 0이면 완전히 옆에서 보는 상태(수학적으로 음수도 나올 수
                //   있어 saturate로 0에 클램프).
                float viewDotNormal = saturate(dot(normalWS, viewDir));
                // pow()로 정면 근처에서만 확 어두워지게 조절(_ScatterPower가 클수록 아주 정면일 때만
                //   어두워지고, 나머지 대부분은 원래색 유지) - 이전에 봉우리 뾰족하게 만들 때와 비슷하게
                //   pow가 "중간값을 눌러서 극단만 남기는" 역할을 함.
                float scatterFactor = pow(viewDotNormal, _ScatterPower) * _ScatterIntensity;
                // lerp(a,b,t): scatterFactor=0(비스듬)->litColor 그대로, scatterFactor=1(정면 최대)->
                //   _ScatterColor(어두운 물속색)로 완전히 대체. 그 사이는 두 색이 섞임.
                litColor = lerp(litColor, _ScatterColor.rgb, saturate(scatterFactor));

                // Whitecap(빛 산란) 레이어: 방금 만든 Scatter랑 조건이 정반대 - "카메라가 노멀과 아주
                //   비스듬하고(grazing) + 그 지점이 카메라에서 멀수록" 표면이 하얗게 빛나 보이게 함.
                //   실제 바다를 멀리서 보면 수평선 근처가 뿌옇게 하얀 빛으로 빛나 보이는 것과 같은 느낌 -
                //   비스듬한 각도일수록 하늘/태양광 반사가 강해지고(Fresnel), 그 반사가 먼 거리에 걸쳐
                //   누적되면서 개별 물결은 안 보이고 표면 전체가 뭉개져 하얗게 보이는 걸 흉내냄.
                //   1.0 - viewDotNormal: Scatter 때 쓴 viewDotNormal(1=정면, 0=비스듬)을 그대로 뒤집어서
                //   "비스듬할수록 커지는 값"으로 씀 (Scatter의 pow(viewDotNormal,...)과 반대 극단을 봄).
                float grazingFactor = pow(1.0 - viewDotNormal, _WhitecapGrazingPower);

                // 거리 조건: 카메라에서 이 표면 지점까지의 실제 거리(월드 단위)를 구해서, _WhitecapDistance
                //   보다 가까우면 0(안 보임)~1(완전히 반영) 사이로 서서히 늘어나게 함. length()는 그냥
                //   벡터의 길이(=거리) - viewDir는 이미 normalize돼서 방향만 남았으니, 여기선 정규화 전의
                //   벡터로 다시 거리를 구함.
                float camDist = length(GetCameraPositionWS() - IN.positionWS);
                float distanceFactor = saturate(camDist / max(_WhitecapDistance, 0.0001));

                // 두 조건을 곱해서 "비스듬하면서 동시에 멀어야만" 강하게 나타나게 함(AND 조건, 저번에
                //   Caustic 밝기 곱셈에서 썼던 것과 같은 원리) - 비스듬해도 가까우면 약하고, 멀어도
                //   정면이면 약함. 둘 다 만족해야 확실히 하얗게 빛남.
                float whitecapRaw = grazingFactor * distanceFactor;
                // 툰처럼 딱 끊기게: 그냥 lerp에 whitecapRaw를 바로 넣으면 0->1로 서서히 밝아지는 부드러운
                //   그라데이션이 됨. 대신 HalfpipeWave.shader의 폭포 줄무늬와 같은 방식으로, smoothstep으로
                //   문턱(_WhitecapThreshold)을 넘는 곳만 확 하얗게 켜지는 하드 엣지 마스크를 만듦 -
                //   _WhitecapEdgeSoftness가 작을수록 경계가 거의 딱 끊겨서 셀 셰이딩(툰) 느낌이 남.
                float whitecapMask = smoothstep(_WhitecapThreshold - _WhitecapEdgeSoftness,
                                                 _WhitecapThreshold + _WhitecapEdgeSoftness, whitecapRaw);
                float whitecapFactor = whitecapMask * _WhitecapIntensity;
                litColor = lerp(litColor, _WhitecapColor.rgb, saturate(whitecapFactor));

                // 흰 줄 그물망을 지형의 Flow Noise와 "같이 흐르게" 하기: vert()에서 지형에 쓰는 것과
                //   똑같은 flowOffset(이동, _FlowDirection/_FlowSpeed)과 flowT(변형 속도, _MorphSpeed)를
                //   그대로 재사용. 그물망만의 독자적인 시간/이동이 아니라, 지형이 흘러가는 그 흐름 위에
                //   그물망도 같이 얹혀서 따라가는 구조가 됨.
                float flowT = _Time.y * _MorphSpeed;
                float2 flowOffset = normalize(_FlowDirection.xz) * _FlowSpeed * _Time.y;
                float2 worldXZ = (IN.positionWS.xz + flowOffset) * _CausticScale;

                // @@@@@@@@ 여기서부터 트레일 추가 @@@@@@@@
                // 트레일: OceanTrailPainter.cs가 매 프레임 갱신하는 텍스처를 이 픽셀의 월드 XZ 기준으로
                //   샘플링. 텍스처는 _OceanTrailCenter를 중심으로 한 _OceanTrailAreaSize 크기의 정사각형만
                //   담당하니, 먼저 이 픽셀의 월드 좌표를 그 범위 안에서의 0~1 UV로 변환해야 함.
                float2 trailUV = (IN.positionWS.xz - _OceanTrailCenter.xy) / _OceanTrailAreaSize + 0.5;
                float trailMask = 0.0;
                if (trailUV.x >= 0.0 && trailUV.x <= 1.0 && trailUV.y >= 0.0 && trailUV.y <= 1.0)
                {
                    trailMask = SAMPLE_TEXTURE2D(_OceanTrailTex, sampler_OceanTrailTex, trailUV).r;
                }
                // trailMask는 "밝기"만 있고 "방향"이 없음(그냥 둥근 얼룩) - ddx/ddy(화면상 옆 픽셀과의
                //   차이)로 방향을 뽑아냄. 트레일 한가운데(가장 밝은 정점)에서는 기울기가 0이고, 얼룩의
                //   가장자리(밝기가 급격히 변하는 경계)에서 가장 커짐 - 그래서 이걸로 Voronoi UV를 밀면
                //   트레일 "안"이 아니라 트레일 "테두리를 따라 고리 모양으로" 그물망이 출렁이며 왜곡됨.
                float2 trailGrad = float2(ddx(trailMask), ddy(trailMask));

                // 노이지한 카툰풍 웨이크 이중선: trailMask가 _OceanTrailLineThreshold를 지나는 경계선을
                //   따라 선을 그림. 트레일이 진행 방향으로 길쭉한 "혜성 꼬리" 모양이라, 이 경계선은
                //   자연스럽게 진행 방향 양옆을 따라가는 두 줄이 됨(뒤쪽 끝은 둥글게 이어짐).
                //   PerlinNoise2D로 문턱값 자체를 흔들어서, 매끈한 곡선이 아니라 손그림처럼 삐뚤빼뚤한
                //   카툰풍 선이 되게 함 - HalfpipeWave.shader의 폭포 줄무늬와 같은 "노이즈로 흔든 뒤 하드
                //   엣지로 끊기" 계열 기법.
                float lineNoise = PerlinNoise2D(IN.positionWS.xz * _OceanTrailLineNoiseScale, _Time.y) - 0.5;
                float noisyTrailMask = trailMask + lineNoise * _OceanTrailLineNoiseStrength;
                float distFromLine = abs(noisyTrailMask - _OceanTrailLineThreshold);
                // 1-smoothstep(0, width, 거리): 문턱값에 딱 붙어있으면(거리=0) 1(선), width 이상 멀어지면
                //   0(선 아님) - Caustic의 lineMask와 완전히 같은 패턴.
                float trailLineMask = 1.0 - smoothstep(0.0, _OceanTrailLineWidth, distFromLine);
                litColor += _OceanTrailLineColor.rgb * trailLineMask * _OceanTrailLineIntensity;
                // @@@@@@@@ 여기까지 트레일 추가 @@@@@@@@

                // 1차 워핑: 낮은 주파수(0.5)라 크고 완만하게 흐르는 큰 굴곡을 만듦. 시간은 flowT*_CausticSpeed로
                //   - _CausticSpeed가 이제 절대 속도가 아니라 "지형 변형 속도(flowT) 대비 배율"이 됨.
                float warpX = PerlinNoise2D(worldXZ * 0.5, flowT * _CausticSpeed) - 0.5;
                float warpY = PerlinNoise2D(worldXZ * 0.5 + 100.0, flowT * _CausticSpeed) - 0.5;
                float2 warpedUV = worldXZ + float2(warpX, warpY) * _CausticDistortion * 4.0;

                // 2차 워핑: 1차로 이미 뒤틀린 좌표(warpedUV)를 기준으로, 훨씬 더 높은 주파수(2.5)의
                //   노이즈로 한 번 더 살짝 흔듦 - 도메인 워핑을 여러 겹 쌓는 건 흔한 테크닉(Inigo Quilez의
                //   "domain warping" 아티클이 유명함). 큰 흐름(1차) 위에 잘게 꿈틀거리는 디테일(2차)이
                //   얹혀서, 한 겹만 쓸 때보다 선이 훨씬 더 구불구불하고 유기적으로 보임.
                float warpX2 = PerlinNoise2D(warpedUV * 2.5 + 300.0, flowT * _CausticSpeed) - 0.5;
                float warpY2 = PerlinNoise2D(warpedUV * 2.5 + 400.0, flowT * _CausticSpeed) - 0.5;
                warpedUV += float2(warpX2, warpY2) * _CausticDistortion2 * 1.5;

                // @@@@@@@@ 여기서부터 트레일 추가 @@@@@@@@
                // 3차 워핑(트레일 전용): 지형 흐름과 무관하게, 이동체가 지나간 자리만 추가로 더 세게 휘어서
                //   "물살에 그물망이 끌려가며 출렁이는" 느낌을 냄. trailGrad가 0인 곳(트레일과 무관한 대부분의
                //   바다)은 이 줄이 사실상 아무 효과가 없음.
                warpedUV += trailGrad * _OceanTrailDistortStrength;
                // @@@@@@@@ 여기까지 트레일 추가 @@@@@@@@

                float3 f = Voronoi2D(warpedUV); // [2단계] float2 -> float3로 받도록만 변경
                float edge = f.y - f.x; // 0에 가까울수록 "두 셀 사이의 경계선"에 가까움
                // smoothstep(0, lineWidth, edge): edge가 0이면 0, lineWidth 이상이면 1로 부드럽게 -> 1-그값을
                //   해서 "경계선 근처(edge가 작음)일 때 1(선이 보임), 멀어지면 0"인 lineMask를 만듦.
                float lineMask = 1.0 - smoothstep(0.0, _CausticLineWidth, edge);

                // corner: f3-f2. 평범한 벽 한가운데면 이 값이 크고(3등이 확실히 더 멀어서), 마디(3개
                //   씨앗이 다 비슷하게 가까운 지점)에 가까우면 0에 가까워짐.
                float corner = f.z - f.y;

                // [3단계] corner를 밝기로 바꾸기: edge 때와 완전히 같은 패턴(1-smoothstep)을 corner에도
                //   적용. cornerMask는 "마디에 가까울수록 1, 멀수록 0".
                float cornerMask = 1.0 - smoothstep(0.0, _CausticCornerWidth, corner);

                // [3단계] cornerMask(0~1)를 "밝기 배율"로 변환: 마디에서 멀면(cornerMask=0) 최소 밝기인
                //   _CausticWallBrightness만, 마디에 가까울수록(cornerMask=1) 최대 밝기 1.0까지 lerp로 올라감.
                //   -> "선일수록 흐리고, 마디로 갈수록 진하게" 원했던 그 효과.
                float wallStrength = lerp(_CausticWallBrightness, 1.0, cornerMask);

                // 웨이브(HalfpipeWave) 근처는 Caustic을 흐리게: 이 지점(XZ)에서 _WaveWorldPos까지의
                //   거리가 _WaveFadeRadius보다 가까우면 0(완전히 안 보임)~1(원래대로)로 부드럽게 줄어듦.
                float distToWave = length(IN.positionWS.xz - _WaveWorldPos.xz);
                // pow()로 "경계 안쪽에서 얼마나 급격하게 사라질지" 조절 - _WaveFadeSharpness가 1이면
                //   거리에 정비례해서 서서히 사라지고(선형), 클수록 파도 아주 가까이서만 급격히 훅
                //   사라지고 그 밖은 거의 원래 밝기를 유지함(Top 뾰족하게 만들 때 쓴 pow와 같은 원리).
                float waveFadeFactor = pow(saturate(distToWave / max(_WaveFadeRadius, 0.0001)), _WaveFadeSharpness);

                // 기존 조명 결과(litColor) 위에 흰 망 무늬를 더하기(additive)로 얹음 - 포말/반짝임 표현의
                //   일반적인 방식으로, 기존 조명을 덮어쓰지 않고 그 위에 반짝임만 추가함.
                //   [3단계] lineMask 뒤에 wallStrength를 추가로 곱해서, 선의 "어디"인지에 따라 밝기가 달라지게 함.
                //
                //   왜 다 곱하기인가 - 각 항이 "원래 값을 몇 %로 반영할지"를 나타내는 비율이라, 비율끼리
                //   합칠 땐 더하기가 아니라 곱하기가 맞음(정가 할인 50%+추가 20% 할인을 0.5+0.2가 아니라
                //   0.5*0.8로 계산하는 것과 같은 원리). 곱하기는 항 하나라도 0이면 전체가 0이 되어
                //   "선이면서 동시에 밝아야 함"이라는 AND 조건을 자연스럽게 표현함(더하기였다면 선이
                //   아닌 곳도 다른 항 때문에 살짝 칠해지는 버그가 생겼을 것).
                //     _CausticColor.rgb : 원래 색 (예: 흰색 (1,1,1))
                //     lineMask          : "여기가 선인가?"를 0~1로 (0=선 아님, 1=선임)
                //     wallStrength      : "그 선이 얼마나 밝은가?"를 0~1로 (0.25~1.0)
                //     _CausticIntensity : "전체적으로 몇 배 밝게 할까"(사용자가 조절하는 배율)
                litColor += _CausticColor.rgb * lineMask * wallStrength * _CausticIntensity * waveFadeFactor;

                return float4(litColor, _Color.a);
            }

            ENDHLSL
        }
    }
}
