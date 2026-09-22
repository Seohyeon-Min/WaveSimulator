using System.Collections;
using UnityEngine;

// 플레이어가 타고 올라가서 점프할 수 있는, 가나가와 해변의 파도처럼 위에서 말려 내려오는
// 오버행(overhang) 지형. rideWidth 축으로는 단면이 동일하게 이어지고, 진행 방향 단면은
// "높이 함수"가 아니라 "경로(제어점을 잇는 곡선)"로 정의됨 — 함수는 한 위치에 값이 하나뿐이라
// 오버행(같은 depth에 정점이 여러 높이로 겹치는 것)을 표현할 수 없기 때문.
// 셰이더로 만드는 비주얼 파도와 달리, 이건 C#에서 진짜 메쉬 지오메트리로 만들어서
// MeshCollider에 그대로 연결하기 때문에 물리적으로 올라타고 부딪힐 수 있음.
[ExecuteAlways]
[RequireComponent(typeof(MeshFilter))]
[RequireComponent(typeof(MeshRenderer))]
[RequireComponent(typeof(MeshCollider))]
public class HalfpipeWaveGenerator : MonoBehaviour
{
    [Header("크기")]
    public float rideWidth = 12f;      // 플레이어가 옆으로 타고 다닐 폭 (이 축 방향으로는 단면이 동일)
    public float maxAmplitude = 4f;    // 완전히 솟아올랐을 때의 높이 배율

    [Header("단면 경로 (제어점을 순서대로 이어서 곡선을 만듦)")]
    [Tooltip("x = depth(진행방향 위치), y = 높이 비율(0~1 정도, maxAmplitude와 애니메이션 진행도가 곱해짐). " +
             "순서대로 이으면 뒤쪽 바닥 -> 정점 -> 앞으로 말리며 내려오는 오버행 -> 앞쪽 바닥.")]
    public Vector2[] crossSectionPoints = new Vector2[]
    {
        new Vector2(-6.26f, 0f),    // 뒤쪽 바닥 (수면과 이어짐)
        new Vector2(-2.56f, 0.29f), // 뒤쪽 벽 오르막
        new Vector2(0.08f,  0.72f), // 정점 직전
        new Vector2(1.4f,   0.95f), // 정점 (가장 높은 지점)
        new Vector2(1.33f,  0.53f), // 파도가 앞으로 말리며 내려오는 바깥쪽(처마 윗면)
        new Vector2(0.37f,  -0.17f),// 말린 안쪽으로 되접혀 들어옴 (오버행의 핵심: depth가 줄어들며 처마 밑면을 만듦, 수면 아래까지 내려감)
        new Vector2(2.1f,   0f),    // 앞쪽 바닥 (수면과 이어짐)
    };

    [Range(0f, 0.5f)]
    [Tooltip("rideWidth 양쪽 끝에서 이 비율만큼 단면 전체를 원점 쪽으로 오므려서, 평평한 절단면 대신 둥글게 끝나게 함")]
    public float edgeTaperRatio = 0.474f;

    [Header("애니메이션")]
    public float riseDuration = 1.2f;  // 솟아오르는 데 걸리는 시간 (초)
    public float fallDuration = 0.25f; // 꺼지는 데 걸리는 시간 (초) - 짧게 둬서 "훅" 꺼지는 느낌

    [Range(0f, 0.95f)]
    [Tooltip("riseDuration 중 단면 경로(뒤쪽 바닥 -> 정점 -> 오버행)를 따라 밀려 올라오는 데 쓰이는 비율. " +
             "나머지 시간은 경로상 각 지점이 그 자리에서 솟아오르는 데 쓰임. 0이면 전체가 동시에 솟아오름")]
    public float sweepPortion = 0.6f;

    [Header("애니메이션 - 전체 위치 이동")]
    [Tooltip("솟아오를 때 지금 배치된 위치(최종 위치)보다 오브젝트 자신의 로컬 -Z(단면 경로상 '뒤쪽') 방향으로 " +
             "이 거리만큼 더 뒤에서 시작해서 최종 위치까지 훅 밀려들어옴. 오브젝트가 회전되어 있어도 그 회전 " +
             "기준으로 방향이 맞춰짐. 0이면 위치 이동 없이 제자리에서만 솟아오름")]
    public float riseStartBackDistance = 16f;

    [Tooltip("뒤쪽 시작 위치에서 최종 위치까지 이동하는 데 걸리는 시간(초). riseDuration보다 길게 두면 " +
             "단면이 다 솟아오른 뒤에도 위치 이동이 조금 더 남아서 계속 밀고 들어오는 느낌이 됨")]
    public float moveDuration = 1.6f;

    [Tooltip("위치가 뒤쪽 시작점(0)에서 최종 위치(1)까지 이동하는 진행도에 적용할 이즈 커브. " +
             "기본값은 시작이 아주 빠르고 끝에서 확 죽는 강한 ease-out (훅 들이닥치는 느낌)")]
    public AnimationCurve moveEase = new AnimationCurve(
        new Keyframe(0f, 0f, 0f, 4f),
        new Keyframe(1f, 1f, 0f, 0f)
    );

    [Header("해상도")]
    [Min(2)] public int widthSegments = 20;
    [Min(3)] public int depthSegments = 40; // 오버행 곡선이라 촘촘해야 매끈함

    [Header("디버그")]
    [Tooltip("RiseUp()/FallDown()의 코루틴 애니메이션은 Play 모드에서만 돌아서, Edit 모드에서는 아무리 " +
             "호출해도 움직이지 않음. 이 체크박스를 켜면 코루틴/애니메이션 상태와 무관하게 즉시 완전히 " +
             "솟아오른 모양으로 강제 고정됨 - 셰이더나 단면 모양을 Play 안 하고 씬에서 바로 확인할 때 씀.")]
    public bool debugForceFullyRisen = false;

    enum AnimState { Rising, Falling }
    AnimState animState = AnimState.Falling; // 시작 상태: 완전히 꺼진 채로 정지
    float animElapsed = 0f;
    float[] fallStartFractions; // FallDown이 호출된 순간의 각 depth행(z) 높이 비율 (그 모양 그대로 균일하게 꺼짐)
    Coroutine animCoroutine;

    Vector3 restWorldPosition;      // 디자이너가 씬에 배치한 "최종 위치" (Awake 시점 1회 캡처, 월드 스페이스)
    Vector3 riseStartWorldPosition; // 이번 RiseUp에서 실제로 출발한 뒤쪽 위치 (월드 스페이스)

    MaterialPropertyBlock propertyBlock; // HalfpipeWave.shader의 _RiseT를 머티리얼 애셋 안 건드리고 넘기는 용도

    void Awake()
    {
        restWorldPosition = transform.position;
    }

    void OnEnable()
    {
        Generate();
    }

#if UNITY_EDITOR
    void OnValidate()
    {
        Generate();
    }
#endif

    // 밖에서 호출: 파도를 솟아오르게 함 (뒤쪽 바닥부터 정점/오버행까지 단면 경로를 따라 밀려 올라오며 솟아오름 +
    // 전체 위치도 최종 위치보다 뒤쪽에서 이즈 커브를 타고 훅 밀려들어옴)
    public void RiseUp()
    {
        if (animCoroutine != null) StopCoroutine(animCoroutine);
        animState = AnimState.Rising;
        animElapsed = 0f;
        // 오브젝트가 회전되어 있어도 "뒤쪽"이 항상 그 오브젝트 자신의 로컬 -Z(단면 경로상 뒤쪽 바닥 방향)가
        // 되도록, 월드 스페이스로 변환한 방향으로 오프셋을 계산함
        riseStartWorldPosition = restWorldPosition + transform.TransformDirection(Vector3.back) * riseStartBackDistance;
        transform.position = riseStartWorldPosition;
        animCoroutine = StartCoroutine(AnimateRise());
    }

    // 밖에서 호출: 파도를 훅 꺼지게 함 (지금 모양 그대로 균일하게 가라앉음)
    public void FallDown()
    {
        if (animCoroutine != null) StopCoroutine(animCoroutine);
        fallStartFractions = ComputeRowFractions(depthSegments + 1);
        animState = AnimState.Falling;
        animElapsed = 0f;
        animCoroutine = StartCoroutine(AnimateFall());
    }

    IEnumerator AnimateRise()
    {
        // 단면(높이)은 riseDuration, 위치는 moveDuration으로 각자 다른 길이를 가질 수 있어서
        // 둘 중 더 긴 시간까지 루프를 돌림 (moveDuration이 더 길면 다 솟아오른 뒤에도 위치가 계속 밀려들어옴)
        float totalDuration = Mathf.Max(riseDuration, moveDuration);
        while (animElapsed < totalDuration)
        {
            animElapsed += Time.deltaTime;
            UpdateRisePosition();
            Generate();
            yield return null;
        }
        animElapsed = riseDuration;
        transform.position = restWorldPosition;
        Generate();
        animCoroutine = null;
    }

    void UpdateRisePosition()
    {
        float moveT = moveDuration > 0f ? Mathf.Clamp01(animElapsed / moveDuration) : 1f;
        float eased = moveEase.Evaluate(moveT);
        transform.position = Vector3.LerpUnclamped(riseStartWorldPosition, restWorldPosition, eased);
    }

    IEnumerator AnimateFall()
    {
        while (animElapsed < fallDuration)
        {
            animElapsed += Time.deltaTime;
            Generate();
            yield return null;
        }
        animElapsed = fallDuration;
        Generate();
        animCoroutine = null;
    }

    // depth행(zi, 0~depthSegments)마다 현재 높이 비율(0~1)을 계산. 단면 경로의 t와 그대로 대응되므로
    // (zi=0 -> 뒤쪽 바닥, zi=depthSegments -> 정점을 지나 앞쪽 바닥/오버행) rideWidth 축과는 무관하게
    // 항상 "뒤쪽 바닥부터 정점/오버행까지" 순서로 밀려 올라옴 - 오브젝트 회전과도 무관함.
    // Rising: tPath=0(뒤쪽 바닥)인 지점이 먼저 솟아오르고, tPath=1(오버행 쪽)이 가장 늦게 솟아올라
    //         파도가 바닥에서부터 차오르며 정점/오버행 쪽으로 밀려 올라오는 것처럼 보임.
    // Falling: FallDown 시점의 모양(fallStartFractions)을 그대로 유지한 채 균일하게 0으로 줄어듦.
    float[] ComputeRowFractions(int zCount)
    {
        float[] fractions = new float[zCount];

        // [디버그] Edit 모드에서 애니메이션 상태와 무관하게 즉시 완전히 솟은 모양으로 고정.
        // OnValidate()가 인스펙터 값이 바뀔 때마다 Generate()를 호출해주니, 이 체크박스를 켜는 순간
        // Play 모드가 아니어도 바로 반영됨.
        if (debugForceFullyRisen)
        {
            for (int i = 0; i < zCount; i++) fractions[i] = 1f;
            return fractions;
        }

        if (animState == AnimState.Rising)
        {
            float localDuration = Mathf.Max(riseDuration * (1f - sweepPortion), 0.0001f);
            for (int zi = 0; zi < zCount; ++zi)
            {
                float tPath = zi / (float)(zCount - 1);
                float delay = tPath * sweepPortion * riseDuration;
                float localT = Mathf.Clamp01((animElapsed - delay) / localDuration);
                fractions[zi] = localT * localT * (3f - 2f * localT); // smoothstep
            }
        }
        else // Falling
        {
            float t = Mathf.Clamp01(fallDuration > 0f ? animElapsed / fallDuration : 1f);
            float fallOut = 1f - (t * t * (3f - 2f * t)); // smoothstep, 1->0
            for (int zi = 0; zi < zCount; ++zi)
            {
                float startFraction = (fallStartFractions != null && zi < fallStartFractions.Length)
                    ? fallStartFractions[zi]
                    : 0f;
                fractions[zi] = startFraction * fallOut;
            }
        }

        return fractions;
    }

    // Catmull-Rom 스플라인: 4개의 점(p0~p3)을 가지고, p1~p2 사이를 부드럽게 보간
    // (u=0이면 p1, u=1이면 p2. p0,p3는 그 앞뒤 곡률을 자연스럽게 이어주기 위한 참고점)
    static Vector2 CatmullRom(Vector2 p0, Vector2 p1, Vector2 p2, Vector2 p3, float u)
    {
        float u2 = u * u;
        float u3 = u2 * u;
        return 0.5f * (
            (2f * p1) +
            (-p0 + p2) * u +
            (2f * p0 - 5f * p1 + 4f * p2 - p3) * u2 +
            (-p0 + 3f * p1 - 3f * p2 + p3) * u3
        );
    }

    // 단면 경로 전체를 하나의 매개변수 t(0~1)로 훑으면서 그 위치의 (depth, heightRatio)를 샘플링
    // 함수가 아니라 "경로"라서, t가 늘어나도 depth가 줄어들 수 있음(오버행) -> 이게 핵심
    Vector2 SampleCrossSection(float t)
    {
        int n = crossSectionPoints.Length;
        float scaledT = t * (n - 1);
        int i1 = Mathf.Clamp(Mathf.FloorToInt(scaledT), 0, n - 2);
        float u = scaledT - i1;

        Vector2 p0 = crossSectionPoints[Mathf.Max(i1 - 1, 0)];
        Vector2 p1 = crossSectionPoints[i1];
        Vector2 p2 = crossSectionPoints[Mathf.Min(i1 + 1, n - 1)];
        Vector2 p3 = crossSectionPoints[Mathf.Min(i1 + 2, n - 1)];

        return CatmullRom(p0, p1, p2, p3, u);
    }

    void Generate()
    {
        int xCount = widthSegments + 1;
        int zCount = depthSegments + 1;

        // 정점 데이터를 담을 그릇 준비
        Vector3[] vertices = new Vector3[xCount * zCount];
        // UV: x = rideWidth 축 위치(0~1), y = 단면 경로 위치(0~1, 0=뒤쪽 바닥, 1=앞쪽 바닥/오버행 끝).
        // 셰이더가 "지금 여기가 오버행(물이 말려 떨어지는 구간)인지"를 UV.y만 보고 알 수 있게 하려고 추가함
        // (지금까지는 UV가 아예 없어서 셰이더가 단면 경로상 위치를 전혀 몰랐음).
        Vector2[] uvs = new Vector2[xCount * zCount];

        float halfWidth = rideWidth * 0.5f;

        // depth행마다 지금 순간의 높이 비율 (파도가 밀려들어오는 애니메이션의 핵심)
        float[] rowFractions = ComputeRowFractions(zCount);

        // 단면 경로를 따라 정점 위치 계산 (depth와 height 둘 다 경로에서 나옴)
        for (int zi = 0; zi < zCount; ++zi)
        {
            float tPath = zi / (float)(zCount - 1);
            Vector2 sample = SampleCrossSection(tPath);

            for (int xi = 0; xi < xCount; ++xi)
            {
                float tx = xi / (float)(xCount - 1);
                float x = tx * rideWidth - halfWidth;

                // 가장자리 오므리기: rideWidth 양 끝에서 taperWidth 안쪽까지는 원래 단면 그대로,
                // 그 바깥은 단면 전체를 원점(0,0)으로 끌어당겨서 평평한 절단면 대신 한 점으로 둥글게 모임
                float taperWidth = rideWidth * edgeTaperRatio;
                float distFromEdge = halfWidth - Mathf.Abs(x);
                float taperFactor = taperWidth > 0f ? Mathf.Clamp01(distFromEdge / taperWidth) : 1f;
                taperFactor = taperFactor * taperFactor * (3f - 2f * taperFactor); // smoothstep

                Vector2 tapered = Vector2.Lerp(Vector2.zero, sample, taperFactor);
                float depth = tapered.x;
                float y = tapered.y * maxAmplitude * rowFractions[zi];

                int i = zi * xCount + xi;
                vertices[i] = new Vector3(x, y, depth);
                uvs[i] = new Vector2(tx, tPath);
            }
        }

        // 정점들을 삼각형으로 엮기 (사각형 한 칸 -> 삼각형 2개)
        // + 좌우 양 끝을 단면 모양 그대로 막는 뚜껑(cap) 삼각형도 추가 (오버행이라 옆에서 보면 뻥 뚫려있어서)
        int capTriangleCount = (zCount - 2) * 3; // 부채꼴(fan) 삼각분할: 점이 n개면 삼각형 n-2개
        int[] triangles = new int[widthSegments * depthSegments * 6 + capTriangleCount * 2];
        int t2 = 0;
        for (int zi = 0; zi < depthSegments; ++zi)
        {
            for (int xi = 0; xi < widthSegments; ++xi)
            {
                int i = zi * xCount + xi;

                triangles[t2++] = i;
                triangles[t2++] = i + xCount;
                triangles[t2++] = i + 1;

                triangles[t2++] = i + 1;
                triangles[t2++] = i + xCount;
                triangles[t2++] = i + xCount + 1;
            }
        }

        // 뒤쪽 뚜껑 (xi=0, x=-halfWidth): 단면 경로를 따라 놓인 zCount개 정점을 부채꼴로 삼각분할
        int lastZi = xCount - 1;
        for (int zi = 1; zi < zCount - 1; zi++)
        {
            triangles[t2++] = 0 * xCount + lastZi;
            triangles[t2++] = zi * xCount + lastZi;
            triangles[t2++] = (zi + 1) * xCount + lastZi;
        }

        // 앞쪽 뚜껑 (xi=xCount-1, x=+halfWidth): 반대 방향을 바라봐야 하니 정점 순서를 뒤집어서 감음

        for (int zi = 1; zi < zCount - 1; zi++)
        {
            triangles[t2++] = 0 * xCount;
            triangles[t2++] = (zi + 1) * xCount;
            triangles[t2++] = zi * xCount;
        }

        // 계산한 데이터를 실제 Mesh 객체로 조립
        var mesh = new Mesh { name = "OverhangWave" };
        mesh.indexFormat = vertices.Length > 65000
            ? UnityEngine.Rendering.IndexFormat.UInt32
            : UnityEngine.Rendering.IndexFormat.UInt16;
        mesh.vertices = vertices;
        mesh.uv = uvs;
        mesh.triangles = triangles;
        mesh.RecalculateNormals();
        mesh.RecalculateBounds();

        // 만든 메쉬를 렌더러와 콜라이더에 실제로 연결
        GetComponent<MeshFilter>().sharedMesh = mesh;

        // HalfpipeWave.shader의 _RiseT(0~1, "얼마나 솟았는지")를 실제 애니메이션 진행도와 동기화.
        // 오버행 끝(맨 앞 행)의 rowFraction을 대표값으로 씀 - 폭포 효과가 딱 그 구간이 실제로 솟아야
        // 나타나는 게 자연스럽기 때문. sharedMaterial.SetFloat을 직접 쓰면 머티리얼 애셋 자체가
        // 바뀌어버려서(다른 오브젝트가 같은 머티리얼을 쓰면 다 같이 바뀌고, 에디터에서 애셋이 계속
        // dirty해짐) MaterialPropertyBlock으로 이 렌더러 하나에만 값을 얹음.
        propertyBlock ??= new MaterialPropertyBlock();
        var meshRenderer = GetComponent<MeshRenderer>();
        meshRenderer.GetPropertyBlock(propertyBlock);
        float riseT = rowFractions.Length > 0 ? rowFractions[rowFractions.Length - 1] : 0f;
        propertyBlock.SetFloat("_RiseT", riseT);
        meshRenderer.SetPropertyBlock(propertyBlock);

        var collider = GetComponent<MeshCollider>();
        collider.sharedMesh = null;  // 콜라이더는 메쉬가 바뀐 걸 캐싱해서 못 알아챌 때가 있어서, 일단 비웠다가
        collider.sharedMesh = mesh;  // 다시 넣어줘야 확실히 갱신됨
        collider.convex = false;     // 오목/오버행 형태를 그대로 충돌면으로 쓰려면 convex를 꺼야 함
    }

    // 이 파도가 차지하는 대략적인 반경(월드 단위) - Ocean.shader의 _WaveFadeRadius처럼 "이 파도 근처는
    // 다른 효과를 흐리게" 같은 용도로 씀. 실제 생성된 메쉬의 바운드를 그대로 쓰는 게, rideWidth/maxAmplitude
    // 따로 계산하는 것보다 taper나 애니메이션 진행도까지 다 반영돼서 더 정확함.
    public float GetApproxRadius()
    {
        return GetComponent<MeshRenderer>().bounds.extents.magnitude;
    }
}
