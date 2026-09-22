using UnityEngine;
using UnityEngine.InputSystem;

// 콜리전 테스트용 대충 만든 플레이어. WASD로 이동, Space로 점프.
// CharacterController를 쓰면 MeshCollider(오목한 파도 형태 포함) 위를 자연스럽게 걸어다닐 수 있음.
[RequireComponent(typeof(CharacterController))]
public class SimplePlayerController : MonoBehaviour
{
    public float moveSpeed = 6f;
    public float jumpHeight = 1.5f;
    public float gravity = -20f;

    CharacterController controller;
    float verticalVelocity;

    void Awake()
    {
        controller = GetComponent<CharacterController>();
    }

    void Update()
    {
        var kb = Keyboard.current;
        if (kb == null) return;

        Vector3 move = Vector3.zero;
        if (kb.wKey.isPressed) move += Vector3.forward;
        if (kb.sKey.isPressed) move += Vector3.back;
        if (kb.aKey.isPressed) move += Vector3.left;
        if (kb.dKey.isPressed) move += Vector3.right;
        move = Vector3.ClampMagnitude(move, 1f) * moveSpeed;

        if (controller.isGrounded)
        {
            verticalVelocity = -1f; // 바닥에 붙어있게 하는 작은 하향력
            if (kb.spaceKey.wasPressedThisFrame)
                verticalVelocity = Mathf.Sqrt(jumpHeight * -2f * gravity);
        }
        verticalVelocity += gravity * Time.deltaTime;

        Vector3 finalMove = move + Vector3.up * verticalVelocity;
        controller.Move(finalMove * Time.deltaTime);
    }
}
