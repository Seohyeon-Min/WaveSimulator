// 백업: Flow Noise(그래디언트 회전)로 전환하기 전, "시간을 노이즈의 3번째 축으로 쓰는" 3D Perlin noise 버전.
// 이 셰이더 자체는 어떤 머티리얼에도 연결하지 마세요 (Ocean.shader와 다른 이름이라 별개의 셰이더로 취급됨).
// 참고: WAVE_LEARNING_LOG.md 27~27-1단계(이 버전 만든 과정), 28단계(왜 Flow Noise로 바꿨는지)
Shader "Custom/Ocean_PerlinNoise3D_Backup"
{
    Properties
    {
        _Color ("Color", Color) = (0.1, 0.4, 0.7, 1)
        _LightDirection ("Light Direction", Vector) = (0.5, 1, 0.3, 0)

        _NoiseScale ("Noise Scale", Range(0.1, 5)) = 1.5
        _FlowDirection ("Flow Direction (XZ)", Vector) = (1, 0, 0, 0)
        _FlowSpeed ("Flow Speed", Range(0, 5)) = 0.1
        _MorphSpeed ("Morph Speed (시간축 노이즈 속도)", Range(0, 5)) = 0.15
        _Amplitude ("Amplitude (0을 중심으로 위아래 대칭으로 솟는 높이)", Range(0, 4)) = 0.1
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
                float3 positionWS : TEXCOORD0;   // frag()에서 ddx/ddy로 노멀을 구하려면 월드 좌표가 필요함
            };

            float4 _Color;
            float4 _LightDirection;

            float _NoiseScale;
            float4 _FlowDirection;
            float _FlowSpeed;
            float _MorphSpeed;
            float _Amplitude;

            // ===== STAGE 1 =====
            // 목표: 3D 좌표 하나(p) -> 0~1 사이 고정된 의사난수 하나. 같은 p를 넣으면 항상 같은 값이 나와야 함.
            // Hash(해시) 함수: "같은 입력 -> 항상 같은 출력"이면서 "입력이 조금만 달라도 출력은 완전히
            //   달라 보이는" 결정적 함수. GPU엔 진짜 난수 생성기가 없어서 "위치 기반 가짜 난수"를 만드는
            //   용도로 셰이더에서 재활용됨. 네이밍 관례(Shadertoy 등): HashXY, X=입력 차원, Y=출력 차원 ->
            //   Hash31 = 3D 입력 -> 스칼라(1개) 출력.
            float Hash31(float3 p)
            {
                // 1단계: p의 각 성분(x,y,z)에 서로 다른 큰 상수를 곱해서 값을 크게 뒤섞는다.
                //         그 다음 frac()으로 정수 부분을 버리고 소수점 아래만 남긴다 (결과는 0~1 사이 3개 값).
                //   frac(p*큰상수)가 난수처럼 보이는 이유: 큰 상수를 곱하면 입력의 아주 작은 차이가 곱해진
                //   결과에서는 꽤 큰 차이로 벌어지고, frac()으로 정수부(원래 입력의 "큰 흐름" 정보)를 버리면
                //   소수부(증폭된 미세한 차이)만 남아서 완전히 다른 값처럼 보임.
                p = frac(p * float3(123.34, 456.21, 789.11));
                // 2단계: 지금 p는 서로 (x,y,z가) 별 상관없이 따로 놀고 있다. dot(p, p + 임의의 상수)를 계산해서
                //         p 전체에 더해준다 -> 세 성분이 서로 영향을 주고받게 뒤섞는 2차 뒤섞기(제곱항이 들어가는
                //   게 핵심). dot()은 이 계산을 한 줄로 압축해주는 내장 함수일 뿐, 수학적으로 반드시 dot이어야
                //   하는 건 아니고, 이 해시는 엄밀하게 유도된 공식이 아니라 경험적으로 잘 섞이면 되는 트릭이라
                //   += 대신 -=를 써도 여전히 유효한 해시가 됨.
                p += dot(p, p + 45.32);
                // 3단계: 마지막으로 p.x와 p.y를 곱하고 frac()을 씌워서, 진짜 최종 스칼라 값 하나(0~1)를 뽑아 반환한다.
                return frac(p.x * p.y);
            }

            // ===== STAGE 2 =====
            // 목표: 3D 격자점 좌표(p) -> 그 점에 배정된 무작위 3D 단위벡터(바람개비 방향) 하나.
            // 원리: 구 표면 위의 한 점을 무작위로 고르는 표준 방법(구면좌표계) 사용.
            //   - theta(경도): 0~2π 사이 무작위 각도 -> 적도를 따라 어느 쪽을 볼지
            //   - z(위도 높이): -1~1 사이 무작위 값 -> 얼마나 위/아래(극쪽)를 볼지
            //   - 그 z에서의 "적도 원의 반지름" r = sqrt(1 - z*z) (피타고라스: 구 표면이니까 x²+y²+z²=1이어야 함)
            //   - 왜 하필 구(sphere)에서 방향을 뽑나: 그래디언트는 "방향"만 중요해야 하므로 길이가 항상
            //     정확히 1이어야 함(원점에서 거리가 늘 1인 게 구의 정의라서 자동으로 만족). x,y,z를 각각
            //     독립적으로 무작위로 뽑고 정규화하면 정육면체 모서리(대각선) 방향이 통계적으로 더 자주
            //     나오는 편향이 생김(정육면체는 모서리 쪽 부피가 더 넓어서). 구면좌표(위도 높이 z를 균등하게
            //     뽑는 방식)는 이 편향 없이 구 표면에 점이 고르게 퍼지는 걸 수학적으로 보장(아르키메데스의
            //     원통 투영 정리). 참고로 "편향" 얘기에서 나온 정육면체와, PerlinNoise3D의 격자 정육면체는
            //     서로 다른 개념 - 전자는 "x,y,z를 각각 독립적으로 뽑았을 때 그 값들이 채우는 공간의 모양",
            //     후자는 "노이즈 계산을 위해 공간을 나눈 격자 칸" - 이름만 같은 정육면체지 완전히 다른 맥락.
            //   - 실무 참고: 성능이 중요한 셰이더는 이 편향을 감수하고 그냥 단순히 Hash로 x,y,z 뽑아
            //     정규화하는 방법도 실제로 많이 씀(sin/cos 같은 삼각함수가 GPU에서 비교적 비싼 연산이라).
            //     "정답이 하나만 있는 게 아니라 성능-정확도 트레이드오프"라는 걸 다시 확인.
            float3 RandomGradient3D(float3 p)
            {
                // 1단계: Hash31을 두 번 다른 입력으로 호출해서 서로 다른 난수 h1, h2를 뽑는다.
                //         (같은 p를 그대로 두 번 넣으면 h1==h2가 되어버리니, p에 임의의 상수를 더해서 두 번째를 다르게 만듦)
                float h1 = Hash31(p); float h2 = Hash31(p + 19.19);
                // 2단계: h1을 경도 각도로 변환 (0~1 -> 0~2π). HLSL엔 PI 상수가 이미 있음.
                float theta = h1 * 2.0 * PI;
                // 3단계: h2를 위도 높이로 변환 (0~1 -> -1~1)
                float z = h2 * 2.0 - 1.0;
                // 4단계: 그 위도에서의 적도 원 반지름 계산. max(0, ...)은 부동소수점 오차로 아주 살짝 음수가 되는 걸 방지.
                //   r² = 1-z²는 반지름의 "제곱"이지 반지름 자체가 아님 - 제곱을 되돌리는 연산이 sqrt(제곱근).
                float r = sqrt(max(0.0, 1.0 - z*z));
                // 5단계: 최종 3D 벡터 반환 (r*cos(theta), r*sin(theta), z) -> 길이가 항상 1인 단위벡터가 됨.
                //   sin/cos이 원 위의 점 좌표가 되는 이유(시계바늘 비유): 반지름 1인 원 위에서 각도 theta만큼
                //   돌아간 바늘 끝과 x축 사이에 생기는 직각삼각형에서, 빗변이 1이라 cos(theta)=밑변 그 자체,
                //   sin(theta)=높이 그 자체가 됨 -> (cos theta, sin theta)가 곧바로 그 점의 좌표. 반지름이
                //   r이면 그 좌표에 r을 곱하기만 하면 됨.
                return float3(r * cos(theta), r * sin(theta), z);
            }

            // ===== STAGE 3 =====
            // 목표: 3D 좌표(p) 하나 -> 부드럽게 이어지는 노이즈 값(대략 0~1) 하나.
            // 원리: p가 들어있는 정육면체 셀을 찾고, 그 8개 모서리마다 "바람개비 영향력"(dot)을 구한 뒤
            //       quintic 곡선으로 부드럽게 보간해서 하나로 합침.
            float PerlinNoise3D(float3 p)
            {
                // cell = 지금 p가 속한 정육면체의 "왼쪽 아래 앞" 모서리 좌표(정수), f = 그 셀 안에서 p의
                //   상대 위치(0~1). f = p - cell 이므로, cell을 원점(0,0,0)으로 놓고 봤을 때 p가 어디쯤
                //   있는지를 나타냄. 어느 꼭짓점을 기준(0)으로 잡을지는 floor()가 자동으로 정해준 것뿐이라
                //   "왼쪽아래앞"이라는 이름 자체엔 특별한 의미가 없고, ceil()을 썼다면 반대쪽 꼭짓점이
                //   기준이 됐어도 알고리즘은 동일하게 작동함.
                float3 cell = floor(p); float3 f = frac(p);

                // 정육면체 8개 모서리(x,y,z 각각 0 또는 1인 조합) 각각에서
                // dot(그 모서리의 그라디언트, 모서리에서 p까지의 벡터)를 계산한다.
                //
                // cell+오프셋 = 그 꼭짓점의 "실제 좌표"(RandomGradient3D에 넣어서 그 꼭짓점 전용 그래디언트를 뽑기 위함).
                // f-오프셋 = "그 꼭짓점에서 p까지의 벡터". f-오프셋을 반드시 해야 하는 이유(1D로 단순화한 예):
                //
                //   cell
                //   ↓
                //   ●--------------------●
                //   0         p(f=0.7)    1
                //
                //   정상 계산(오프셋을 뺌):
                //     000 꼭짓점: dot(gradient000, f)       // f     = +0.7 (000에서 p까지)
                //     100 꼭짓점: dot(gradient100, f - 1)   // f - 1 = -0.3 (100에서 p까지, 반대편이라 더 가깝고 부호도 반대)
                //
                //   만약 -오프셋을 안 하고 f를 그대로 재사용하면:
                //     000 꼭짓점: dot(gradient000, f)   // +0.7
                //     100 꼭짓점: dot(gradient100, f)   // +0.7  ← 틀림! 100 꼭짓점도 "내가 000인 것처럼" 착각하고 계산하게 됨
                //
                //   즉 -오프셋을 빼먹으면 모든 꼭짓점이 실제로는 저마다 다른 위치에 있는데도
                //   전부 "자기가 000 꼭짓점인 줄 알고" p까지의 거리를 계산해버리는 셈이 됨.
                //
                // dot(그래디언트, 벡터) = 이 꼭짓점 입장에서 p가 자기 그래디언트 방향과 얼마나 비슷한
                //   방향에 있는지를 나타내는 스칼라 (Value Noise처럼 거리만 보는 게 아니라 방향까지 반영되어
                //   격자 경계가 덜 도드라짐 - 이게 Value Noise보다 Perlin Noise가 자연스러워 보이는 이유)
                //
                // 변수명 규칙: n000의 n=noise value, 뒤의 000은 그 꼭짓점의 (x,y,z) 오프셋을 그대로
                //   이어붙인 것(cell+(1,0,0)이면 n100) - 8개를 헷갈리지 않고 다음 lerp 단계에서 짝짓기
                //   쉽게 하기 위한 네이밍.
                float n000 = dot(RandomGradient3D(cell + float3(0,0,0)), f - float3(0,0,0));
                float n100 = dot(RandomGradient3D(cell + float3(1,0,0)), f - float3(1,0,0));
                float n010 = dot(RandomGradient3D(cell + float3(0,1,0)), f - float3(0,1,0));
                float n110 = dot(RandomGradient3D(cell + float3(1,1,0)), f - float3(1,1,0));
                float n001 = dot(RandomGradient3D(cell + float3(0,0,1)), f - float3(0,0,1));
                float n101 = dot(RandomGradient3D(cell + float3(1,0,1)), f - float3(1,0,1));
                float n011 = dot(RandomGradient3D(cell + float3(0,1,1)), f - float3(0,1,1));
                float n111 = dot(RandomGradient3D(cell + float3(1,1,1)), f - float3(1,1,1));

                // f(0~1)를 quintic 곡선(6t^5-15t^4+10t^3)으로 워프한 u를 만든다.
                //   계수 6,-15,10은 아무 숫자나 고른 게 아니라 "t=1일 때 값=1, 1차 미분=0, 2차 미분=0"이라는
                //   3개 조건을 만족하는 연립방정식의 유일한 해(t=0쪽은 다항식에 t가 곱해져 있어 자동 만족).
                //   직접 검산: h(1)=6-15+10=1(경계값 조건), h'(t)=30t⁴-60t³+30t²이고 h'(1)=30-60+30=0(1차
                //   미분 조건). 2차 미분까지 0으로 만드는 이유는, 최종적으로 화면에 보이는 건 높이 자체가
                //   아니라 그 기울기(법선→빛 반사)라서, 기울기까지 부드럽게 이어지려면 그 재료인 이 곡선이
                //   한 단계 더(2차 미분까지) 매끈해야 하기 때문. smoothstep의 계수(3,-2)도 같은 방식으로
                //   "1차 미분까지만 0"이라는 더 낮은 조건을 풀어서 나온 값.
                //   (미분 얘기는 이 곡선을 "설계할 때" 종이 위에서 증명해둔 성질일 뿐, 셰이더 코드에는 미분
                //   계산이 없음 - 코드는 언제나 h(t) 함수 값 자체만 계산함)
                float3 u = f*f*f*(f*(f*6.0-15.0)+10.0);

                // lerp(a,b,t)="a에서 b까지 t만큼 간 지점". lerp는 값 2개만 섞을 수 있는 도구라 8개를
                //   1개로 합치려면 2개씩 묶어 절반씩 줄이는 걸 반복해야 함(8→4→2→1, 총 4+2+1=7번,
                //   "N개를 2개씩 묶어 1개로 줄이면 N-1번 필요"한 것과 같은 원리 - 토너먼트 대진표와 동일:
                //   8명이 우승자 1명을 가리려면 4+2+1=7경기 필요한 것과 같음). x→y→z 순서는 관례일 뿐,
                //   어느 축부터 묶어도 결과는 동일함.
                float nx00 = lerp(n000, n100, u.x);
                float nx10 = lerp(n010, n110, u.x);
                float nx01 = lerp(n001, n101, u.x);
                float nx11 = lerp(n011, n111, u.x);
                float nxy0 = lerp(nx00, nx10, u.y);
                float nxy1 = lerp(nx01, nx11, u.y);
                float nxyz = lerp(nxy0, nxy1, u.z);

                // nxyz는 (단위벡터 그래디언트)·(최대 길이 √3/2≈0.87인 거리벡터)라서 대략 -0.87~0.87 범위.
                //   *0.5+0.5는 "입력이 -1~1"이라는 가정하에 0~1로 옮기는 리매핑 공식
                //   (new=(x-oldMin)/(oldMax-oldMin)*(newMax-newMin)+newMin 에서 oldMin=-1,oldMax=1,
                //   newMin=0,newMax=1을 대입한 특수 케이스). 실제 범위(-0.87~0.87)가 그 안에 통째로
                //   들어가서 결과가 0~1을 벗어나진 않지만, 0.15~0.85 정도에만 몰리고 끝까지는 못 감.
                return nxyz * 0.5 + 0.5;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionOS = IN.positionOS.xyz;   // Object Space 위치 복사본(이제부터 이걸 수정)

                // Unity는 Y축이 "위"(Y-up)라서, 바닥 평면은 x,z 두 축으로만 펼쳐져 있고 y가 높이임.
                // 근데 PerlinNoise3D는 3개를 받음 - 부드럽게 "변해야 할 것"이 x위치, z위치, 시간 이렇게
                // 3개라서. (함수 내부는 1/2/3번째 칸을 완전히 똑같이 취급하는 대칭 구조라 어느 칸에 뭘
                // 넣어도 상관없음 - x,z를 1,2번 칸에 넣고 시간을 3번 칸에 넣은 건 편의상 정한 순서일 뿐)
                //
                // 3번째 칸(시간)의 역할: 3D 노이즈를 "이미 통째로 꽉 차 있는 젤리 덩어리"라고 생각하면,
                // x,z만 쓰는 건 그 덩어리를 얇게 썬 단면 하나를 들여다보는 것과 같음. "어느 위치에서 썰었는지"가
                // 3번째 칸(시간)이고, 이게 매 프레임 조금씩 커지면 매번 다른 단면을 보게 됨. 덩어리 자체가
                // 부드럽게 이어져 있으니 옆 단면끼리는 비슷하되, 시간이 갈수록 무늬가 진짜로 새로운 모양으로
                // "변형"됨 (x나 z에 시간을 그냥 더했다면 무늬 모양은 그대로고 옆으로 미끄러지기만 했을 것 -
                // 그거랑은 다른 효과라 3번째 축을 따로 씀).
                //
                // 격자점 하나의 그래디언트 "값" 자체는 절대 안 바뀌는 게 정상(그래야 이웃과 부드럽게 이어짐).
                // 시간이 지나며 진짜로 변하는 이유는, 특정 격자점의 값이 바뀌어서가 아니라 "한 번도 안 써본
                // 새로운 격자점 구간으로 계속 걸어 들어가기 때문" - 카드 한 벌(격자점들)은 고정이지만,
                // 시간이 지날수록 계속 새 카드를 뽑아서 직전 카드와 섞어 보여주는 것과 같음.
                // -> 이 방식의 한계(봉우리 위치가 잘 안 바뀌는 느낌)를 Flow Noise(그래디언트 회전)로 개선한
                //    버전이 Ocean.shader에 있음. WAVE_LEARNING_LOG.md 28단계 참고.
                float morphT = _Time.y * _MorphSpeed;
                float noise = PerlinNoise3D(float3(positionOS.xz * _NoiseScale, morphT));

                // 표준 방식: noise(0~1)를 -1~1로 되돌린 뒤 _Amplitude를 곱함 -> 0을 중심으로 위아래 대칭
                // (noise=0 -> -_Amplitude, noise=0.5 -> 0, noise=1 -> +_Amplitude).
                positionOS.y += (noise * 2.0 - 1.0) * _Amplitude;

                // Object Space(오브젝트 자기 기준 좌표)만으로는 카메라 위치/각도/시야각을 몰라서 화면에
                // 못 그림 - 아래 두 함수가 Model/View/Projection 행렬을 곱해 "화면에 그릴 좌표"(Clip Space)로
                // 바꿔줌(HLSL 자체 기능이 아니라 URP Core.hlsl이 제공하는 유틸 함수). 반드시 노이즈 변형 다음에
                // 호출해야 하는 이유: 노이즈로 "진짜 3D 위치"를 먼저 다 정한 다음에야 그걸 투영해야 함 -
                // 순서가 바뀌면 이미 눌러 찌그러진 화면 좌표에 값을 더하는 꼴이 되어 잘못된 결과가 나옴.
                // World Space를 거쳐가는 이유: frag()에서 ddx/ddy로 조명용 노멀을 구하려면 월드 좌표가 필요해서,
                // Clip Space로 한 번에 안 가고 중간에 World Space(positionWS)를 한 번 더 거쳐 Varyings로 넘겨줌.
                OUT.positionWS = TransformObjectToWorld(positionOS);
                OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);
                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                // ddx/ddy: 화면상 옆/아래 픽셀의 월드 좌표와 비교해서 표면이 얼마나 기울었는지 알려주는
                // GPU 내장 함수(screen-space derivative). 파도 수식을 직접 미분하는 정확한 방법 대신,
                // 화면에 이미 그려진 결과에서 기울기를 근사하는 훨씬 간단한 임시 방법.
                // cross(ddy, ddx) 순서는 노멀이 표면 바깥(위쪽)을 향하게 하기 위함 - 반대로 하면 뒤집힘.
                float3 normalWS = normalize(cross(ddy(IN.positionWS), ddx(IN.positionWS)));

                float3 lightDir = normalize(_LightDirection.xyz);
                // dot(노멀, 빛방향) = 이 표면이 빛을 얼마나 정면으로 보고 있는지. 같은 방향이면 1(정면),
                // 수직이면 0, 반대 방향이면 음수(빛을 전혀 못 받는 뒷면) - saturate로 음수는 0에 클램프.
                float diffuse = saturate(dot(normalWS, lightDir));

                // ambient(그림자에서도 최소한 보이는 밝기, 0~1) + diffuse(빛 받는 만큼 밝아짐)로 밝기 배율을 만듦.
                // diffuse에 곱하는 계수를 "1 - ambient"로 정확히 맞추는 게 핵심: 그래야 diffuse=1(빛 정면)일 때
                //   ambient + (1-ambient)*1 = 1.0 로 딱 떨어져서 "가장 밝은 곳 = 원래 _Color 그대로"가 보장됨.
                float ambient = 0.0;
                float3 litColor = _Color.rgb * (ambient + diffuse * (1.0 - ambient));

                return float4(litColor, _Color.a);
            }

            ENDHLSL
        }
    }
}
