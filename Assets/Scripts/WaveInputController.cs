using UnityEngine;
using UnityEngine.InputSystem;

// 숫자키 1/2로 파도를 하나씩 골라서 솟아오르게 함.
// 다른 키를 누르면 지금 솟아있던 파도는 훅 꺼지고, 새로 고른 파도가 솟아오름 (한 번에 하나만 활성화)
// [디버그용] 0번키: 등록된 파도를 전부 한꺼번에 솟아오르게 함 (평소엔 하나만 켜지는 걸 깨는 예외 기능이라
// 디버그 전용 - 다른 셰이더/애니메이션이 서로 안 겹치고 잘 보이는지 한눈에 비교할 때 씀). 백스페이스: 전부 끄기.
public class WaveInputController : MonoBehaviour
{
    public HalfpipeWaveGenerator[] waves; // 인스펙터에서 순서대로 등록: [0]=1번키, [1]=2번키, ...

    [Header("Ocean 연동")]
    [Tooltip("Ocean.shader를 쓰는 머티리얼. 컨트롤러가 파도들의 위치/크기를 이미 다 알고 있으니, " +
             "여기서 매 프레임 Ocean의 _WaveWorldPos/_WaveFadeRadius를 갱신해서 파도 근처의 Voronoi " +
             "그물망(Caustic)이 흐려지게 함 - 파도 쪽(HalfpipeWave.shader)이 아니라 Ocean 쪽에서 처리.")]
    public Material oceanMaterial;

    HalfpipeWaveGenerator activeWave; // 가장 최근에 Activate()된 파도 (Ocean 페이드 기준점으로 씀)

    [Header("디버그")]
    [Tooltip("Play 모드에서 이 체크박스를 켜면 등록된 파도가 전부 한꺼번에 솟아오름 (평소엔 하나만 켜지는 " +
             "규칙을 무시하는 디버그 전용 기능). 끄면 전부 훅 꺼짐. 인스펙터에서 씬을 보면서 바로 켜고 끌 수 있음.")]
    public bool debugRiseAll = false;

    bool prevDebugRiseAll = false; // 체크박스가 "바뀐 순간"만 감지하기 위한 이전 프레임 값

    void Update()
    {
        var keyboard = Keyboard.current;
        if (keyboard != null && waves != null)
        {
            if (keyboard.digit1Key.wasPressedThisFrame) Activate(0);
            if (keyboard.digit2Key.wasPressedThisFrame) Activate(1);
            if (keyboard.digit3Key.wasPressedThisFrame) Activate(2);

            if (keyboard.digit0Key.wasPressedThisFrame) RiseAll();       // [디버그] 전부 솟아오르기
            if (keyboard.backspaceKey.wasPressedThisFrame) FallAll();    // [디버그] 전부 끄기
        }

        // 체크박스가 방금 켜졌을 때만 RiseAll 호출, 방금 꺼졌을 때만 FallAll 호출 - 매 프레임 값이
        // true라고 매번 다시 호출하면 코루틴이 계속 재시작돼서 애니메이션이 안 끝나고 튐.
        if (debugRiseAll != prevDebugRiseAll)
        {
            if (debugRiseAll) RiseAll();
            else FallAll();
            prevDebugRiseAll = debugRiseAll;
        }

        UpdateOceanWaveFade();
    }

    void Activate(int index)
    {
        if (index < 0 || index >= waves.Length || waves[index] == null) return;

        for (int i = 0; i < waves.Length; i++)
        {
            if (waves[i] == null) continue;
            if (i == index) waves[i].RiseUp();
            else waves[i].FallDown();
        }
        activeWave = waves[index];
    }

    // Ocean.shader의 _WaveWorldPos/_WaveFadeRadius를 지금 솟아있는 파도(activeWave)의 실제 위치/크기로
    // 매 프레임 갱신 - 파도가 뒤에서 밀려들어오는 애니메이션 중에도 위치가 계속 바뀌니까 프레임마다 갱신해야 함.
    // sharedMaterial을 직접 SetVector/SetFloat하는 건(MaterialPropertyBlock이 아니라) Ocean이 씬에 하나뿐인
    // 큰 메쉬라 렌더러별로 다른 값을 줄 필요가 없어서 - 여러 오브젝트가 이 머티리얼을 공유해도 다 같은
    // "지금 어디에 파도가 있는지" 값을 보면 되기 때문에 오히려 이 방식이 맞음.
    void UpdateOceanWaveFade()
    {
        if (oceanMaterial == null || activeWave == null) return;
        oceanMaterial.SetVector("_WaveWorldPos", activeWave.transform.position);
        oceanMaterial.SetFloat("_WaveFadeRadius", activeWave.GetApproxRadius());
    }

    // [디버그용] 한 번에 하나만 켜진다는 평소 규칙을 무시하고, 등록된 파도를 전부 솟아오르게 함.
    void RiseAll()
    {
        for (int i = 0; i < waves.Length; i++)
        {
            if (waves[i] != null) waves[i].RiseUp();
        }
    }

    // [디버그용] 전부 훅 꺼지게 함.
    void FallAll()
    {
        for (int i = 0; i < waves.Length; i++)
        {
            if (waves[i] != null) waves[i].FallDown();
        }
    }
}
