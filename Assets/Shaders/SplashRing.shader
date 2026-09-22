// 착지 스플래시용 카툰풍 셰이더. 평면이 아니라 종이를 말아 휴지심처럼 세운 "열린 원통" 벽면
// (SplashEffect.cs가 만드는 메쉬, UV.x=둘레 각도 0~1, UV.y=높이 0=바닥~1=꼭대기) 위에,
// 둘레를 한 바퀴 도는 사인파 하나로 테두리 높이를 울렁이게 그려서 카툰풍 스플래시 실루엣을 만든다.
Shader "Custom/SplashRing"
{
    Properties
    {
        _Color ("Color", Color) = (0.4, 0.85, 1, 1)

        // SplashEffect.cs가 재생 시간(duration) 동안 0->1로 애니메이션시키는 값. 0~0.5 구간엔
        // 테두리가 바닥에서부터 자라 올라오고, 0.5~1 구간엔 전체가 서서히 사라짐.
        _ExpandT ("Expand T (0=시작, 1=끝)", Range(0, 1)) = 0

        _BaseHeight ("Base Height (사인파가 흔들리는 기준 높이)", Range(0, 1)) = 0.5
        _Period ("Period (둘레를 도는 동안 파도가 몇 번 반복되는지)", Range(1, 20)) = 5
        _Amplitude ("Amplitude (파도가 위아래로 얼마나 크게 출렁이는지)", Range(0, 1)) = 0.3
        _Phase ("Phase (파도 시작 위상, 0~1)", Range(0, 1)) = 0

        // 도메인 워핑(Ocean.shader/HalfpipeWave.shader와 같은 기법): 메인 사인파에 그대로 넣는 대신,
        // sin에 넣기 전에 좌표(위상) 자체를 더 느린 보조 사인파로 한 번 더 흔들어서 "주기가 일정하지
        // 않고 들쭉날쭉해 보이게" 만듦 - 진짜로 불규칙한 노이즈가 아니라 사인끼리 겹친 것이라 여전히
        // 매끄럽게 이어짐.
        _PeriodVarianceFreq ("Period Variance Frequency (주기가 늘어났다 줄었다 하는 게 둘레에 몇 번)", Range(0, 8)) = 2
        _PeriodVarianceStrength ("Period Variance Strength (주기가 얼마나 들쭉날쭉해질지)", Range(0, 0.5)) = 0.15

        // 진폭도 같은 방식으로 흔들어서 "물결 높이도 곳에 따라 들쭉날쭉하게" 만듦.
        _AmplitudeVarianceFreq ("Amplitude Variance Frequency", Range(0, 8)) = 3
        _AmplitudeVarianceStrength ("Amplitude Variance Strength (0=항상 같은 높이, 1=거의 0까지 작아졌다 커짐)", Range(0, 1)) = 0.5

        // 물결(_Period 개수만큼 있는 각 봉우리) 하나하나가 서로 다른 무작위 속도/높이로 나타났다가
        // 줄어들며 사라짐 - 전부 똑같이 자라고 똑같이 줄어들면 기계적으로 보여서, 봉우리마다 값을 다르게 줌.
        [Header(Per Bump Random Timing)]
        _MinGrowSpeed ("Min Grow Speed (0~0.5 구간에서 가장 느리게 나타나는 봉우리 배속)", Range(0.3, 3)) = 0.7
        _MaxGrowSpeed ("Max Grow Speed (가장 빠르게 나타나는 봉우리 배속)", Range(0.3, 5)) = 2.0
        _MinShrinkSpeed ("Min Shrink Speed (0.5~1 구간에서 가장 느리게 줄어드는 봉우리 배속)", Range(0.3, 5)) = 0.8
        _MaxShrinkSpeed ("Max Shrink Speed (가장 빠르게 줄어드는 봉우리 배속)", Range(0.3, 6)) = 2.5
        _MinHeightScale ("Min Height Scale (가장 낮게 자라는 봉우리 높이 배율)", Range(0, 2)) = 0.5
        _MaxHeightScale ("Max Height Scale (가장 높게 자라는 봉우리 높이 배율)", Range(0, 2)) = 1.3

        _EdgeSoftness ("Edge Softness (작을수록 카툰처럼 딱 끊긴 테두리)", Range(0.001, 0.3)) = 0.04

        // 레퍼런스 이미지처럼 꼭대기(끝부분)만 다른 색(보통 흰색)으로 칠함 - 카툰 스플래시의 하이라이트.
        [Header(Tip Coloring)]
        _TipColor ("Tip Color (끝부분 색, 보통 흰색)", Color) = (1, 1, 1, 1)
        _TipWidth ("Tip Width (꼭대기에서 이 폭만큼 Tip Color로)", Range(0, 0.5)) = 0.15

        // 원래 Voronoi(경계선 전체가 서로 이어진 그물망, Ocean.shader Caustic과 같은 방식)로 돌아가되,
        // 그물망을 sin으로 도메인 워핑해서 직선 폴리곤 대신 동글동글 곡선으로 휘어지게 함 - 여전히 전부
        // 이어져 있으면서(끊긴 원 조각이 아님) 카툰풍 거품 느낌이 남.
        [Header(Voronoi Water Facets)]
        _VoronoiScale ("Voronoi Scale (조각이 얼마나 잘게 쪼개질지)", Range(1, 30)) = 10
        _VoronoiWarpFreq ("Voronoi Warp Frequency (곡선이 얼마나 자주 휘어질지)", Range(0, 10)) = 2.5
        _VoronoiWarpStrength ("Voronoi Warp Strength (곡선이 얼마나 크게 휘어질지, 0=원래 직선 Voronoi)", Range(0, 1)) = 0.35
        _VoronoiLineColor ("Voronoi Line Color (조각 경계선 색)", Color) = (0.1, 0.35, 0.55, 1)
        _VoronoiLineWidth ("Voronoi Line Width", Range(0.01, 0.5)) = 0.08
        _VoronoiLineIntensity ("Voronoi Line Intensity (0~1)", Range(0, 1)) = 0.5

        // Voronoi Water Facets와는 독립된 별도의 격자(스케일도 따로) - 씨앗 지점 근처에 구멍을 숭숭
        // 뚫음(전부가 아니라 _HoleChance 확률만큼만).
        [Header(Holes)]
        _HoleScale ("Hole Scale (구멍 격자가 얼마나 잘게 쪼개질지, Voronoi Scale과 별개)", Range(1, 30)) = 6
        _HoleRadius ("Hole Radius (씨앗 지점 기준 반지름)", Range(0, 0.5)) = 0.18
        _HoleChance ("Hole Chance (조각 하나가 구멍일 확률, 0~1)", Range(0, 1)) = 0.35

        // 보로노이/구멍 패턴이 제자리에 고정된 텍스처처럼 안 보이게, _ExpandT가 진행되는 동안 두 격자를
        // 같이 위로(또는 아래로) 밀어서(스크롤) 실제로 물이 솟아오르면서 패턴도 같이 흐르는 느낌을 냄.
        [Header(Pattern Movement)]
        _PatternScrollSpeed ("Pattern Scroll Speed (ExpandT 0->1 동안 패턴이 격자 칸 단위로 얼마나 밀릴지)", Range(-10, 10)) = 3
    }
    SubShader
    {
        Tags { "RenderType" = "Transparent" "Queue" = "Transparent" "RenderPipeline" = "UniversalPipeline" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            float4 _Color;
            float _ExpandT;
            float _BaseHeight;
            float _Period;
            float _Amplitude;
            float _Phase;
            float _PeriodVarianceFreq;
            float _PeriodVarianceStrength;
            float _AmplitudeVarianceFreq;
            float _AmplitudeVarianceStrength;
            float _MinGrowSpeed;
            float _MaxGrowSpeed;
            float _MinShrinkSpeed;
            float _MaxShrinkSpeed;
            float _MinHeightScale;
            float _MaxHeightScale;
            float _EdgeSoftness;
            float4 _TipColor;
            float _TipWidth;
            float _VoronoiScale;
            float _VoronoiWarpFreq;
            float _VoronoiWarpStrength;
            float4 _VoronoiLineColor;
            float _VoronoiLineWidth;
            float _VoronoiLineIntensity;
            float _HoleScale;
            float _HoleRadius;
            float _HoleChance;
            float _PatternScrollSpeed;

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }

            // Hash21: 같은 입력엔 항상 같은 출력, 입력이 조금만 달라도 완전히 달라 보이는 의사난수
            // (Ocean.shader/HalfpipeWave.shader와 동일한 트릭) - 봉우리(bump) 인덱스별 무작위 속도/높이를
            // 뽑는 용도로 씀.
            float Hash21(float2 p)
            {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }

            // Hash22 / Voronoi2D: Ocean.shader의 Caustic 그물망과 완전히 같은 기법 - 격자 셀마다 무작위
            // 위치에 씨앗 점을 두고, 가장 가까운 씨앗까지 거리(f1)와 두 번째로 가까운 씨앗까지 거리(f2)를
            // 구함. f2-f1이 0에 가까우면 셀 경계선(물 표면 조각의 갈라진 틈), f1 자체가 작으면 씨앗
            // 바로 근처(구멍을 뚫을 자리).
            float2 Hash22(float2 p)
            {
                return float2(Hash21(p + 17.0), Hash21(p + 43.0));
            }

            float2 Voronoi2D(float2 p, out float2 cellOut)
            {
                float2 cell = floor(p);
                float2 f = frac(p);

                float f1 = 8.0;
                float f2 = 8.0;
                float2 closestCell = cell;

                for (int y = -1; y <= 1; y++)
                {
                    for (int x = -1; x <= 1; x++)
                    {
                        float2 neighbor = float2(x, y);
                        float2 seed = Hash22(cell + neighbor);
                        float dist = length(neighbor + seed - f);

                        if (dist < f1) { f2 = f1; f1 = dist; closestCell = cell + neighbor; }
                        else if (dist < f2) { f2 = dist; }
                    }
                }

                cellOut = closestCell;
                return float2(f1, f2);
            }

            float4 frag(Varyings IN) : SV_Target
            {
                float2 uv = IN.uv; // x: 둘레 각도 0~1(랩어라운드), y: 높이 0(바닥)~1(꼭대기)

                // 0~0.5: 전체적으로 자라나는 구간(글로벌 진행도). 0.5~1: 전체적으로 줄어드는 구간.
                // 실제로 각 봉우리에 적용되는 그로스/슈링크 배속은 봉우리마다 다르게(아래) 곱해짐.
                float growGlobalT = saturate(_ExpandT / 0.5);
                float shrinkGlobalT = saturate((_ExpandT - 0.5) / 0.5);

                // 도메인 워핑 1: 메인 사인에 넣을 위상(uv.x) 자체를 더 느린 보조 사인파로 흔들어서,
                //   "주기가 곳에 따라 넓어졌다 좁아졌다" 하는 것처럼 보이게 함.
                float periodWarp = sin(uv.x * _PeriodVarianceFreq * 2.0 * PI) * _PeriodVarianceStrength;
                float warpedX = uv.x + periodWarp;

                // 도메인 워핑 2: 진폭도 (uv.x 기준, periodWarp와 다른 주파수로) 같은 방식으로 흔들어서
                //   "물결 높이도 곳에 따라 들쭉날쭉"하게 만듦. amplitudeMod가 0 밑으로 안 내려가게 saturate.
                float amplitudeMod = saturate(1.0 + sin(uv.x * _AmplitudeVarianceFreq * 2.0 * PI) * _AmplitudeVarianceStrength);

                // 지금 이 지점이 _Period개의 물결 중 몇 번째 "봉우리"에 속하는지 - 정수로 뚝뚝 끊어서
                //   봉우리 하나 전체가 같은 무작위 값(같은 속도/높이)을 공유하게 함(연속값이면 봉우리 안에서도
                //   값이 스멀스멀 바뀌어서 부자연스러움).
                float bumpIndex = floor((warpedX + _Phase) * _Period);

                // 봉우리별 무작위값 3개(서로 다른 오프셋의 Hash21) - 등장 속도, 소멸 속도, 최대 높이.
                float growSpeed = lerp(_MinGrowSpeed, _MaxGrowSpeed, Hash21(float2(bumpIndex, 11.0)));
                float shrinkSpeed = lerp(_MinShrinkSpeed, _MaxShrinkSpeed, Hash21(float2(bumpIndex, 37.0)));
                float heightScale = lerp(_MinHeightScale, _MaxHeightScale, Hash21(float2(bumpIndex, 59.0)));

                // 이 봉우리만의 배속으로 다시 진행도를 계산 - 배속이 빠르면 더 일찍 다 자라고(성장 구간)
                //   더 일찍 다 줄어듦(소멸 구간), 배속이 느리면 그 반대.
                float localGrowT = saturate(growGlobalT * growSpeed);
                float localShrinkT = saturate(shrinkGlobalT * shrinkSpeed);

                // 둘레(uv.x, 랩어라운드라 2π 곱하면 한 바퀴 = 정수 주기라 이음매가 안 끊김)를 한 바퀴 도는
                // 사인파 하나. _Period=주기(둘레에 물결이 몇 개), _Amplitude=출렁이는 높이 폭.
                float wave = sin((warpedX + _Phase) * _Period * 2.0 * PI);
                float baseTarget = (_BaseHeight + wave * _Amplitude * amplitudeMod) * heightScale;

                // 페이드아웃(알파) 대신 "다시 줄어듦"(높이가 0을 향해 낮아짐)으로 사라짐을 표현.
                float edgeHeight = baseTarget * localGrowT * (1.0 - localShrinkT);

                // 이 높이(uv.y)가 edgeHeight보다 낮으면 보임 - EdgeSoftness로만 살짝 부드럽게 끊음(카툰 느낌).
                float mask = 1.0 - smoothstep(edgeHeight - _EdgeSoftness, edgeHeight + _EdgeSoftness, uv.y);

                // 끝부분(꼭대기에서 _TipWidth만큼)만 Tip Color로 - EdgeSoftness로 카툰처럼 딱 끊김.
                float tipFactor = smoothstep(edgeHeight - _TipWidth - _EdgeSoftness, edgeHeight - _TipWidth + _EdgeSoftness, uv.y);
                float3 color = lerp(_Color.rgb, _TipColor.rgb, tipFactor);

                // 패턴이 제자리에 고정된 텍스처처럼 안 보이게, ExpandT를 따라 두 격자를 같이 스크롤함 -
                //   _ExpandT가 0->1로 진행되는 동안 격자 좌표(y)를 밀어서, 마치 물이 솟아오르며 패턴도
                //   같이 흐르는 것처럼 보이게 함(제자리에서 가만히 있는 게 아니라 진짜로 움직임).
                float patternScroll = _ExpandT * _PatternScrollSpeed;

                // Voronoi로 물 조각(facet) 느낌 - 격자에 넣기 전에 좌표를 sin으로 한 번 휘게(도메인 워핑,
                //   Ocean.shader/HalfpipeWave.shader와 같은 기법) 만들어서, 원래는 직선인 폴리곤 경계선이
                //   동글동글 곡선으로 휘어져 보이게 함. 여전히 f2-f1 기반 그물망이라 경계선 전체가 서로
                //   이어져 있음(끊어진 원 조각이 아님).
                float2 voronoiUV = uv * _VoronoiScale + float2(0.0, patternScroll);
                float2 voronoiWarp = float2(
                    sin(voronoiUV.y * _VoronoiWarpFreq + 11.0),
                    sin(voronoiUV.x * _VoronoiWarpFreq + 57.0)
                ) * _VoronoiWarpStrength;

                float2 voronoiCell;
                float2 vor = Voronoi2D(voronoiUV + voronoiWarp, voronoiCell);
                float edge = vor.y - vor.x; // 0에 가까울수록 조각 경계선
                float lineMask = 1.0 - smoothstep(0.0, _VoronoiLineWidth, edge);
                color = lerp(color, _VoronoiLineColor.rgb, lineMask * _VoronoiLineIntensity);

                // 구멍은 완전히 별개의 격자(_HoleScale)로 - Voronoi Water Facets 패턴과 안 얽히게 따로 계산.
                //   이 조각이 구멍일지는 씨앗 하나당 고정된 무작위값으로 결정(전부가 아니라 _HoleChance
                //   확률만큼만) - 구멍이면 씨앗 근처(holeVor.x가 작은 곳)만 알파 0으로 뚫음. 같은
                //   patternScroll을 써서 Voronoi 패턴이랑 같이(같은 방향/속도로) 움직이게 함.
                float2 holeCell;
                float2 holeVor = Voronoi2D(uv * _HoleScale + float2(0.0, patternScroll), holeCell);
                float holeRoll = Hash21(holeCell + 5.5);
                float isHoleCell = step(holeRoll, _HoleChance);
                float insideHole = 1.0 - smoothstep(_HoleRadius - _EdgeSoftness, _HoleRadius + _EdgeSoftness, holeVor.x);
                float holeMask = 1.0 - isHoleCell * insideHole;

                float alpha = mask * holeMask * _Color.a;
                return float4(color, alpha);
            }
            ENDHLSL
        }
    }
}
