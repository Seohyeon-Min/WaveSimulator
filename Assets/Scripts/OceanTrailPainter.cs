using UnityEngine;

// 이동체(보통 플레이어)를 따라다니는 "국소 창" 하나짜리 RenderTexture에 트레일을 그려서
// Ocean.shader에 전역(Shader.SetGlobal*)으로 넘겨주는 스크립트. 카메라나 씬 렌더링 없이
// Graphics.Blit(OceanTrailBlit.shader)만으로 매 프레임 "이전 내용 밀기 + 페이드 + 현재 위치에 스탬프"를
// 반복하는 핑퐁(ping-pong) 방식.
//
// 텍스처는 항상 target 위치를 중심으로 한 areaSize x areaSize(월드 단위) 정사각형을 담당하고,
// target이 움직이면 텍스처 "내용"을 반대로 밀어서 마치 창이 따라 움직이는 것처럼 보이게 함
// (자세한 유도는 OceanTrailBlit.shader 주석 참고).
//
// FloatingOriginManager가 플레이어를 원점 근처로 순간이동시킬 때(수천 유닛 단위로 아주 가끔) 이번
// 프레임의 deltaWorld가 areaSize보다 훨씬 커져서 트레일이 한 프레임 동안 통째로 비워지는데, 다음
// 프레임부터 다시 정상적으로 그려지는 자연스러운 자동 복구라 별도 처리가 필요 없음.
public class OceanTrailPainter : MonoBehaviour
{
    [Header("Tracked object (보통 플레이어)")]
    public Transform target;

    [Header("Trail area")]
    [Tooltip("이 텍스처가 담당하는 정사각형 범위(월드 단위, target 중심). 너무 작으면 트레일이 빨리 창 밖으로 " +
             "나가 잘리고, 너무 크면 트레일 한 칸(스탬프)이 상대적으로 작아 보임.")]
    public float areaSize = 40f;
    [Tooltip("텍스처 해상도 (클수록 트레일 가장자리가 선명해지지만 GPU 비용 증가)")]
    public int resolution = 256;

    [Header("Trail look")]
    [Tooltip("1초에 트레일 밝기가 이 비율만큼 사라짐 (0=안 사라짐, 1=1초 만에 완전히 사라짐)")]
    [Range(0f, 1f)] public float fadePerSecond = 0.6f;
    [Tooltip("스탬프(현재 위치 자국) 반경, areaSize에 대한 비율(UV 단위)")]
    [Range(0.01f, 0.5f)] public float stampRadius = 0.03f;
    [Range(0f, 2f)] public float stampStrength = 1f;

    Material blitMaterial;
    RenderTexture rtA, rtB;
    bool usingA = true;
    Vector3 lastCenter;
    bool initialized;

    // target(플레이어)이 땅/바다에 붙어있는지 - 공중에 떠 있을 때(점프 중 등)는 발밑에 트레일이 찍히면
    // 안 되니, Movement.cs가 이미 매 프레임 갱신하는 _isGrounded를 그대로 참조해서 스탬프만 끔.
    Movement targetMovement;

    static readonly int MainTexID = Shader.PropertyToID("_MainTex");
    static readonly int OffsetID = Shader.PropertyToID("_Offset");
    static readonly int FadeID = Shader.PropertyToID("_Fade");
    static readonly int StampPosID = Shader.PropertyToID("_StampPos");
    static readonly int StampRadiusID = Shader.PropertyToID("_StampRadius");
    static readonly int StampStrengthID = Shader.PropertyToID("_StampStrength");

    void OnEnable()
    {
        // 애셋(.mat)을 따로 안 만들고 셰이더에서 즉석으로 머티리얼을 만듦 - Blit 전용이라 인스펙터에
        // 노출할 필요가 없고, 이렇게 하면 씬에 이 스크립트만 붙이면 바로 동작함.
        var shader = Shader.Find("Hidden/OceanTrailBlit");
        blitMaterial = new Material(shader);

        targetMovement = target?.GetComponent<Movement>();

        // R채널 하나만 쓰는 흑백 마스크라 R8 포맷으로 충분 (RGBA32보다 메모리 1/4).
        var desc = new RenderTextureDescriptor(resolution, resolution, RenderTextureFormat.R8, 0);
        rtA = new RenderTexture(desc) { name = "OceanTrailA", wrapMode = TextureWrapMode.Clamp };
        rtB = new RenderTexture(desc) { name = "OceanTrailB", wrapMode = TextureWrapMode.Clamp };
        rtA.Create();
        rtB.Create();

        var prevActive = RenderTexture.active;
        RenderTexture.active = rtA; GL.Clear(true, true, Color.black);
        RenderTexture.active = rtB; GL.Clear(true, true, Color.black);
        RenderTexture.active = prevActive;

        initialized = false;
    }

    void OnDisable()
    {
        if (rtA != null) { rtA.Release(); rtA = null; }
        if (rtB != null) { rtB.Release(); rtB = null; }
        if (blitMaterial != null) { Destroy(blitMaterial); blitMaterial = null; }
    }

    void LateUpdate()
    {
        if (target == null || blitMaterial == null) return;

        Vector3 center = target.position;
        if (!initialized)
        {
            lastCenter = center;
            initialized = true;
        }

        RenderTexture src = usingA ? rtA : rtB;
        RenderTexture dst = usingA ? rtB : rtA;

        Vector2 deltaWorld = new Vector2(center.x - lastCenter.x, center.z - lastCenter.z);
        Vector2 offsetUV = deltaWorld / areaSize;

        // fadePerSecond(초당 비율)를 이번 프레임 시간(deltaTime)에 맞는 배율로 변환.
        // pow(1-fadePerSecond, deltaTime)를 쓰는 이유: 프레임마다 그냥 고정된 배율을 곱하면 프레임레이트가
        // 바뀔 때(60fps vs 30fps) 초당 실제로 사라지는 양이 달라짐 - pow로 보정해야 몇 fps든 1초 뒤
        // 밝기가 항상 (1-fadePerSecond)배로 같아짐.
        float fade = Mathf.Pow(1f - fadePerSecond, Time.deltaTime);

        blitMaterial.SetTexture(MainTexID, src);
        blitMaterial.SetVector(OffsetID, offsetUV);
        blitMaterial.SetFloat(FadeID, fade);
        blitMaterial.SetVector(StampPosID, new Vector2(0.5f, 0.5f)); // target은 항상 창 정중앙
        blitMaterial.SetFloat(StampRadiusID, stampRadius);
        // 공중에 떠 있으면(점프 중 등) 발밑에 새 자국을 안 찍음 - fade/shift는 그대로 계속되니 이미 찍힌
        // 트레일은 평소처럼 서서히 사라지고, 착지하는 순간부터 다시 자국이 찍히기 시작함.
        bool grounded = targetMovement == null || targetMovement._isGrounded;
        blitMaterial.SetFloat(StampStrengthID, grounded ? stampStrength : 0f);

        Graphics.Blit(src, dst, blitMaterial);

        // Ocean.shader는 여러 타일(InfiniteFloorTiler 등)이 같은 머티리얼을 공유할 수 있으니,
        // 특정 렌더러 하나가 아니라 전역으로 설정해서 모든 오션 타일이 같은 트레일을 보게 함.
        Shader.SetGlobalTexture("_OceanTrailTex", dst);
        Shader.SetGlobalVector("_OceanTrailCenter", new Vector4(center.x, center.z, 0f, 0f));
        Shader.SetGlobalFloat("_OceanTrailAreaSize", areaSize);

        lastCenter = center;
        usingA = !usingA;
    }
}
