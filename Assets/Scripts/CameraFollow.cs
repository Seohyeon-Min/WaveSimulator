using UnityEngine;
using UnityEngine.InputSystem;

// Sandbox_GAM300_Laptop의 Assets/Important Stuff/04_Scripts/Camera.cs를 이식한 버전. 두 가지만 바꿈:
// 1) 클래스 이름을 Camera -> CameraFollow로 - 원본처럼 그대로 "Camera"라고 지으면 UnityEngine.Camera(전역
//    Camera 타입)를 이 프로젝트의 다른 스크립트에서 쓸 때 이 클래스가 가려버릴 위험이 있어서(같은
//    네임스페이스에 Camera라는 이름이 두 개), 동작은 완전히 동일하게 두고 이름만 충돌 안 나게 바꿈.
// 2) GameObject.Find("Player Image") -> GameObject.Find("Player") - 원본이 찾던 "Player Image"는 이
//    프로젝트에 없는 오브젝트라 그대로 두면 NullReferenceException만 남. 실제 플레이어 오브젝트 이름인
//    "Player"를 찾도록 바로잡음.
// + 추가: C키로 followPlayer를 토글 - "카메라 킴/끔"용 디버그 키.
public class CameraFollow : MonoBehaviour
{
    private GameObject playerImage;
    [SerializeField] private bool followPlayer = true;
    [SerializeField] private Vector3 offset;
    [Tooltip("이 키를 누르면 카메라 추적을 켜고 끔.")]
    [SerializeField] private Key _toggleKey = Key.C;

    void Start()
    {
        playerImage = GameObject.Find("Player");
    }

    void Update()
    {
        if (Keyboard.current != null && Keyboard.current[_toggleKey].wasPressedThisFrame)
        {
            followPlayer = !followPlayer;
        }

        if (followPlayer && playerImage != null)
        {
            transform.position = playerImage.transform.position + offset;
            transform.LookAt(playerImage.transform);
        }
    }
}
