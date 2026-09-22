using System.Collections;
using UnityEngine;

// 착지(랜딩) 스플래시 하나짜리 재생 담당. 평면이 아니라 종이를 말아 휴지심처럼 세운 "열린 원통"
// 벽면(위/아래 뚜껑 없음)을 직접 만들어서 SplashRing.mat이 그 벽면에 스플래시 모양을 그리게 한다.
// SplashRing.mat의 _ExpandT를 MaterialPropertyBlock으로 0->1 애니메이션시켜서 꽃잎이 자라났다
// 사라지는 것처럼 보이게 한 뒤 스스로 파괴됨. Movement.cs가 착지 순간 이 컴포넌트가 붙은 프리팹을
// Instantiate만 해주면 나머지는 알아서 재생됨.
// GridMeshGenerator.cs와 같은 이유로 ExecuteAlways: Awake()는 플레이 모드에서만 호출돼서, 이게 없으면
// 에디터에서 프리팹/씬을 볼 때(플레이 안 한 상태) MeshFilter가 비어 메시가 안 보임.
[ExecuteAlways]
[RequireComponent(typeof(MeshRenderer), typeof(MeshFilter))]
public class SplashEffect : MonoBehaviour
{
    [SerializeField] private float _duration = 0.6f;
    [Tooltip("원통 벽을 몇 각형으로 쪼갤지 - 클수록 부드러운 원, 작을수록 각짐")]
    [SerializeField] private int _segments = 32;
    [Tooltip("바닥 쪽 반지름 (1 기준 비율) - 휴지심처럼 아래는 좁게")]
    [SerializeField] private float _bottomRadius = 0.2f;
    [Tooltip("꼭대기 쪽 반지름 (1 기준 비율) - 위로 갈수록 넓게 벌어짐")]
    [SerializeField] private float _topRadius = 0.5f;

    private static readonly int ExpandTID = Shader.PropertyToID("_ExpandT");

    // 반지름/높이가 1 기준으로 고정된 도형이라 모든 인스턴스가 같은 모양을 공유해도 됨(실제 크기는
    // 프리팹의 Transform Scale로 조절) - 스폰할 때마다 새로 만들지 않고 캐시해서 재사용.
    private static Mesh s_tubeMesh;

    private MeshRenderer _renderer;
    private MaterialPropertyBlock _propertyBlock;

    void OnEnable()
    {
        _renderer = GetComponent<MeshRenderer>();
        _propertyBlock ??= new MaterialPropertyBlock();

        if (s_tubeMesh == null) s_tubeMesh = BuildTubeMesh(_segments, _bottomRadius, _topRadius);
        GetComponent<MeshFilter>().sharedMesh = s_tubeMesh;

        // 코루틴(재생 애니메이션)은 플레이 모드에서만 - 에디터에서 프리팹을 볼 땐 메시만 보이면 됨.
        if (Application.isPlaying) StartCoroutine(PlayRoutine());
    }

#if UNITY_EDITOR
    // 인스펙터에서 _segments/_bottomRadius/_topRadius를 바꾸면 바로 반영되도록 다시 생성.
    void OnValidate()
    {
        s_tubeMesh = BuildTubeMesh(_segments, _bottomRadius, _topRadius);
        if (TryGetComponent(out MeshFilter meshFilter)) meshFilter.sharedMesh = s_tubeMesh;
    }
#endif

    IEnumerator PlayRoutine()
    {
        float t = 0f;
        while (t < _duration)
        {
            t += Time.deltaTime;
            SetExpandT(Mathf.Clamp01(t / _duration));
            yield return null;
        }

        Destroy(gameObject);
    }

    void SetExpandT(float value)
    {
        _renderer.GetPropertyBlock(_propertyBlock);
        _propertyBlock.SetFloat(ExpandTID, value);
        _renderer.SetPropertyBlock(_propertyBlock);
    }

    // 종이를 동그랗게 말아 휴지심처럼 세운 모양(옆면만 있는 열린 원통, 위/아래 뚜껑 없음) - 아래는
    // bottomRadius로 좁고 위는 topRadius로 넓게 벌어지는 원뿔대(frustum) 형태. 셰이더가 이 벽면
    // (UV.x=둘레 각도 0~1, UV.y=높이 0=바닥~1=꼭대기)에 스플래시 모양을 그림.
    // GridMeshGenerator.cs와 같은 "정점 배열 채우고 삼각형 인덱스 잇기" 패턴.
    static Mesh BuildTubeMesh(int segments, float bottomRadius, float topRadius)
    {
        segments = Mathf.Max(segments, 3);
        var mesh = new Mesh { name = "SplashTube" };

        int ringVertCount = segments + 1; // 이음매(UV.x 0과 1)가 겹치지 않도록 한 칸 더 둠
        var vertices = new Vector3[ringVertCount * 2];
        var normals = new Vector3[vertices.Length];
        var uvs = new Vector2[vertices.Length];

        const float height = 1f;

        // 원뿔대 옆면 하나의 기울기(생성선) 방향 (radial 증가량, 높이) -> 그 기울기에 수직인 2D 노멀.
        // bottomRadius==topRadius(일반 원통)이면 (0,1)이 되어 예전처럼 순수 수평 노멀이 나옴.
        Vector2 slope = new Vector2(topRadius - bottomRadius, height);
        Vector2 normal2D = new Vector2(slope.y, -slope.x).normalized;

        for (int i = 0; i < ringVertCount; i++)
        {
            float t = i / (float)segments;
            float angle = t * Mathf.PI * 2f;
            float cos = Mathf.Cos(angle);
            float sin = Mathf.Sin(angle);

            Vector3 normal = new Vector3(cos * normal2D.x, normal2D.y, sin * normal2D.x);

            vertices[i] = new Vector3(cos * bottomRadius, 0f, sin * bottomRadius);
            normals[i] = normal;
            uvs[i] = new Vector2(t, 0f);

            vertices[ringVertCount + i] = new Vector3(cos * topRadius, height, sin * topRadius);
            normals[ringVertCount + i] = normal;
            uvs[ringVertCount + i] = new Vector2(t, 1f);
        }

        var triangles = new int[segments * 6];
        int tri = 0;
        for (int i = 0; i < segments; i++)
        {
            int bottomA = i;
            int bottomB = i + 1;
            int topA = ringVertCount + i;
            int topB = ringVertCount + i + 1;

            triangles[tri++] = bottomA;
            triangles[tri++] = topA;
            triangles[tri++] = bottomB;

            triangles[tri++] = bottomB;
            triangles[tri++] = topA;
            triangles[tri++] = topB;
        }

        mesh.vertices = vertices;
        mesh.normals = normals;
        mesh.uv = uvs;
        mesh.triangles = triangles;
        mesh.RecalculateBounds();
        return mesh;
    }
}
