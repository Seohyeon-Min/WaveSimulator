using System.Collections;
using UnityEngine;
using UnityEngine.InputSystem;

// Sandbox_GAM300_Laptop의 Assets/Important Stuff/04_Scripts/Movement.cs를 이 프로젝트로 옮긴 트림(trim) 버전.
// 원본은 Trick(QTE 트릭 미니게임)/StyleSystem/LandingSplash 프리팹 등 Sandbox 전용 시스템과 얽혀 있었는데,
// 이 프로젝트(WaveSimulator)에는 Trick/StyleSystem이 아예 없어서 그 부분만 제거하고 나머지 스케이트보드
// 이동/턴/점프/땅체크/추가 낙하중력/_facingRotation 분리 구조는 그대로 유지함. 자세한 제거 내역은 각 자리의
// 주석 참고.
public class Movement : MonoBehaviour
{
    [Header("Player Control")]
    [SerializeField] private bool _allowMovement;
    [SerializeField] private bool _allowTurning;
    [SerializeField] private bool _allowJump;
    [Tooltip("Normalize Speed when Grounded")]
    [SerializeField] private bool _normalizeSWG;
    [Tooltip("Maximum Speed")]
    [SerializeField] private float _maxSpeed;
    [Tooltip("How fast you can turn")]
    [SerializeField] private float _turnSpeed;
    [Tooltip("Cooldown between jumps if enabled")]
    [SerializeField] private float _jumpCooldown;
    [Tooltip("Force of jumps if enabled")]
    [SerializeField] private float _jumpForce;
    [Tooltip("파도(Wave)에서 벗어날 때 위로 튕겨 올리는 마진/세기. 원래 이름(_trickMargin)은 Sandbox의 Trick " +
             "미니게임에서 왔지만, 이 프로젝트에는 Trick이 없어서 지금은 순수하게 '파도 위 점프 발판' 용도로만 씀 " +
             "(OnCollisionExit 참고). HalfpipeWaveGenerator.GetPeakWorldPosition()이 이 프로젝트에 없어서 " +
             "실제로는 사용되지 않음 - 아래 OnCollisionExit의 가드 주석 참고.")]
    [SerializeField] private float _trickMargin;
    [Tooltip("Force of wave when starting trick")]
    [SerializeField] private float _waveStrength;
    [Tooltip("How fast you return to max speed (%per tick)")]
    [SerializeField] private float _speedRamp;
    [Tooltip("3D Rigidbody has no per-object gravity scale (unlike Rigidbody2D), so this adds extra downward " +
             "acceleration only while falling (rb.linearVelocity.y < 0) to shorten jump hang time without " +
             "touching the global Physics.gravity setting or the rise portion of the jump. 1 = no change.")]
    [SerializeField] private float _fallGravityMultiplier = 2f;
    [SerializeField] private LayerMask _groundLayer;

    [Header("Landing Splash")]
    [Tooltip("착지(공중->지면 전환) 순간 스케이트보드 위치에 스폰되는 이펙트 프리팹(LandingSplash 등). 비워두면 스폰 안 함. " +
             "이 프로젝트에는 아직 LandingSplash 프리팹이 없으니 비워둬도 안전함(SpawnLandingSplash()가 null 체크 후 그냥 리턴).")]
    [SerializeField] private GameObject _landingSplashPrefab;
    [Tooltip("착지 지점보다 진행 방향으로 이만큼 앞에 스폰 - 플레이어가 계속 움직이는 동안 이펙트가 뒤에 처져 보이는 걸 보정.")]
    [SerializeField] private float _landingSplashForwardOffset = 1f;
    [Tooltip("착지 지점보다 Y축으로 이만큼 낮게/높게 스폰 (음수=더 아래). Instantiate에 월드 좌표를 직접 넘기기 때문에 프리팹 자체의 Y는 무시되니 여기서 조절.")]
    [SerializeField] private float _landingSplashYOffset = 0f;

    // Exposes _maxSpeed read-only so other systems (e.g. WaveSpawner) can compute a worst-case travel
    // distance for how far the player could possibly move during some time window, without needing their
    // own separate copy of this value to keep in sync.
    public float MaxSpeed => _maxSpeed;

    // Important variables
    public bool _isGrounded;
    private bool _canJump = true;
    private GameObject _skateBoard;
    private GameObject[] _groundCheck;
    private InputAction _moveAction;
    private InputAction _jumpAction;
    private Rigidbody _rb;
    private float _currSpeed;
    private Coroutine _slowdownCoroutine;

    // 이동 방향(=캐릭터가 "보는" 방향)의 유일한 출처. 비주얼(스케이트보드 mesh, 플레이어 루트)은 평소엔
    // 이 값을 그대로 따라가지만(TurnControl), 트릭 스핀/사미라 궁처럼 순수 연출용 회전을 줄 땐 비주얼만
    // 따로 돌리고 이 값은 전혀 안 건드림 - "비주얼 회전이 이동 방향에 영향을 주면 안 된다"는 문제를
    // 애초에 겸용하던 구조(_skateBoard.transform.forward가 곧 이동 방향)에서 분리해서 근본적으로 해결.
    // 이 트림 버전에는 지금 이 값을 오버라이드하는 연출(트릭 스핀 등)이 없지만, TurnControl/MovementControl이
    // 이미 이 구조를 기준으로 짜여 있고 나중에 Sandbox_GAM300_Laptop처럼 트릭/어빌리티 연출을 다시 붙일 때
    // 같은 방식으로 훅을 걸 수 있도록 그대로 남겨둠.
    private Quaternion _facingRotation;

    // SamiraUltEffect 등 외부 연출 시스템이 스케이트보드 비주얼을 직접 돌리기 위한 접근자. 위 _facingRotation과
    // 같은 이유로 작고 무해해서 그대로 유지.
    public Transform SkateBoardTransform => _skateBoard != null ? _skateBoard.transform : null;
    public Quaternion FacingRotation => _facingRotation;

    void Start()
    {
        _skateBoard = GameObject.Find("Skateboard");
        if (_skateBoard == null)
        {
            Debug.LogError("[Movement] No GameObject named 'Skateboard' found in the scene - ground check and " +
                            "turning will not work. Add a child named exactly 'Skateboard' under the player, with " +
                            "wheel-like children for ground raycasts.", this);
            _groundCheck = new GameObject[0];
        }
        else
        {
            _groundCheck = new GameObject[_skateBoard.transform.childCount];
            for (int i = 0; i < _skateBoard.transform.childCount; i++)
            {
                // 스케이트보드의 실제 자식(앞/뒤 바퀴 등)에서 각각 레이캐스트해서, 그중 하나라도 바닥에
                // 닿으면 grounded로 인정 - 예전엔 여기 전부 플레이어 자신의 Transform이 들어가 있어서
                // 사실상 한 지점에서만 검사하는 것과 같았고, 보드가 기울거나(파도 위 등) 플레이어 피벗
                // 위치가 표면에서 살짝 떠 있으면 감지를 놓치기 쉬웠음.
                _groundCheck[i] = _skateBoard.transform.GetChild(i).gameObject;
            }
            _facingRotation = _skateBoard.transform.rotation;
        }
        _currSpeed = _maxSpeed;
        _rb = GetComponent<Rigidbody>();
        if (_rb == null) Debug.LogError("[Movement] No Rigidbody on this GameObject - movement will not work. Add one.", this);

        if (InputSystem.actions == null)
        {
            Debug.LogError("[Movement] InputSystem.actions is null (no project-wide Input Actions asset assigned in " +
                            "Project Settings > Input System Package, or it failed to load) - Move/Jump won't work.", this);
        }
        else
        {
            _moveAction = InputSystem.actions.FindAction("Move");
            _jumpAction = InputSystem.actions.FindAction("Jump");
            if (_moveAction == null) Debug.LogError("[Movement] No 'Move' action found in the project-wide Input Actions asset.", this);
            if (_jumpAction == null) Debug.LogError("[Movement] No 'Jump' action found in the project-wide Input Actions asset.", this);
        }
    }

    void Update()
    {
        TurnControl();
        ActivateTrick();
    }
    void FixedUpdate()
    {
        NormalizeMovement();
        MovementControl();
        IsGrounded();
        ApplyExtraFallGravity();
    }

    // Only kicks in on the way down (velocity.y < 0), so the jump's rise (controlled by _jumpForce) and
    // normal ground movement are untouched - just makes the fall faster to cut the floaty hang time at the
    // top of the arc from lingering into the descent.
    void ApplyExtraFallGravity()
    {
        if (_rb == null) return;
        if (_rb.linearVelocity.y < 0f)
        {
            _rb.AddForce(Physics.gravity * (_fallGravityMultiplier - 1f), ForceMode.Acceleration);
        }
    }

    void TurnControl()
    {
        if (_allowTurning && _moveAction != null)
        {
            Vector2 _turn = _moveAction.ReadValue<Vector2>();
            if (_turn.x != 0)
            {
                Quaternion targetRotation = _facingRotation * Quaternion.Euler(0f, _turn.x * _turnSpeed, 0f);

                // Rotational Lerp <--
                _facingRotation = Quaternion.Slerp(
                    _facingRotation,
                    targetRotation,
                    Time.deltaTime * _turnSpeed
                );
            }
        }

        // 스케이트보드 비주얼은 그냥 _facingRotation을 따라감. Sandbox_GAM300_Laptop 원본은 여기서
        // _isVisualOverrideActive(트릭 스핀/사미라 궁 등 연출 코루틴이 직접 돌리는 중인지) 체크로 덮어쓰기를
        // 막았는데, 이 트림 버전엔 그런 연출이 없어서 그 가드째로 제거함 - 나중에 트릭 스핀류 연출을 다시
        // 붙일 때는 여기에 같은 패턴(bool 플래그로 감싸기)을 다시 넣으면 됨.
        if (_skateBoard != null) _skateBoard.transform.rotation = _facingRotation;
    }

    void MovementControl()
    {
        // 이동 방향은 오직 _facingRotation에서만 나옴 - 스케이트보드/플레이어의 "실제 렌더링 회전"이
        // 트릭 스핀 등 연출로 뭘 하든 전혀 영향받지 않음.
        if (_allowMovement && _rb != null)
        {
            NormalizeMovement();

            Vector3 _forwardVelocity = (_facingRotation * Vector3.forward) * _currSpeed;
            _rb.linearVelocity = new Vector3(_forwardVelocity.x, _rb.linearVelocity.y, _forwardVelocity.z);
        }
    }

    void NormalizeMovement()
    {
        if (!_normalizeSWG)
            return;
        _currSpeed = Mathf.Clamp(_currSpeed + (_speedRamp/100.0f), 0.0f, _maxSpeed);
    }

    // Knocks _currSpeed down by amount, then guarantees it's back to _maxSpeed after duration seconds -
    // independent of _normalizeSWG/_speedRamp (which only ramps up if configured with a nonzero speedRamp,
    // so relying on it alone left speed permanently reduced when speedRamp was 0/unset).
    public void Slowdown(float amount, float duration = 1f)
    {
        if (_slowdownCoroutine != null) StopCoroutine(_slowdownCoroutine);
        _slowdownCoroutine = StartCoroutine(SlowdownRoutine(amount, duration));
    }

    IEnumerator SlowdownRoutine(float amount, float duration)
    {
        _currSpeed = Mathf.Clamp(_currSpeed - amount, 0.0f, _maxSpeed);
        yield return new WaitForSeconds(duration);
        _currSpeed = _maxSpeed;
        _slowdownCoroutine = null;
    }

    void IsGrounded()
    {
        bool wasGrounded = _isGrounded;
        bool grounded = false;

        foreach (GameObject gam in _groundCheck)
        {
            if (Physics.Raycast(gam.transform.position, Vector3.down, 1.25f, _groundLayer))
            {
                grounded = true;
                break;
            }
        }

        _isGrounded = grounded;

        // 공중->지면으로 막 전환된 프레임(착지 순간)에만 스플래시를 한 번 스폰함.
        if (_isGrounded && !wasGrounded) SpawnLandingSplash();
    }

    void SpawnLandingSplash()
    {
        if (_landingSplashPrefab == null) return;

        // 스폰 시점의 위치 그대로 쓰면, 플레이어가 계속 앞으로 움직이는 동안 이펙트가 재생돼서
        // 상대적으로 "뒤에 처지는" 것처럼 보임 - 진행 방향으로 살짝 앞당겨서 보정.
        Vector3 spawnPos = _skateBoard.transform.position + (_facingRotation * Vector3.forward) * _landingSplashForwardOffset;
        spawnPos.y += _landingSplashYOffset;
        Instantiate(_landingSplashPrefab, spawnPos, Quaternion.identity);
    }

    // 이름은 Sandbox_GAM300_Laptop의 Trick(QTE) 미니게임에서 왔지만, 실제로는 그냥 "점프 입력 처리" 함수임 -
    // Trick 미니게임 자체와는 무관함. 원본 이름 그대로 포팅 (헷갈리지만 그대로 유지).
    void ActivateTrick()
    {
        if (_allowJump && _canJump && _isGrounded)
        {
            bool _jumpKey = _jumpAction.IsPressed();
            if (_jumpKey)
            {
                _rb.AddForce(new Vector3(0, _jumpForce, 0), ForceMode.Impulse);
                StartCoroutine(JumpCooldown());
            }
        }
    }

    void OnCollisionExit(Collision other)
    {
        if (other.gameObject.name.Contains("Wave"))
        {
            // Sandbox_GAM300_Laptop 원본은 여기서 HalfpipeWaveGenerator.GetPeakWorldPosition()으로 파도
            // 정점 높이를 구해서 "정점 근처에서 벗어났을 때만" 위로 튕겨줬고, 그 직후 Trick.Instance.DoTricks(...)로
            // QTE 트릭 미니게임을 시작시켰음. 이 프로젝트엔 Trick이 없으므로 그 호출은 통째로 제거했고,
            // HalfpipeWaveGenerator.GetPeakWorldPosition() 메서드 자체도 이 프로젝트의 HalfpipeWaveGenerator.cs에는
            // 없어서(GetApproxRadius()만 존재) 정점 높이 기반 마진 체크도 함께 뺐음 - 대신 파도와 부딪힌 채로
            // 떨어져 나가는 모든 경우에 무조건 위로 튕겨 올려줌. GetPeakWorldPosition()이 나중에 추가되면
            // _trickMargin을 다시 이용해 원래의 마진 체크를 되살릴 수 있음.
            _rb.AddForce(Vector3.up * _waveStrength, ForceMode.Impulse);
        }
    }

    IEnumerator JumpCooldown()
    {
        _canJump = false;
        yield return new WaitUntil(() => _isGrounded);
        yield return new WaitForSeconds(_jumpCooldown);
        _canJump = true;
    }

    public void ToggleCripplePlayer()
    {
        if (_allowMovement && _allowTurning)
        {
            _allowMovement = false;
            _allowTurning = false;
        } else
        {
            _allowMovement = true;
            _allowTurning = true;
        }
    }
}
