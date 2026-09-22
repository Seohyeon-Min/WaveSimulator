using UnityEngine;

[ExecuteAlways]
[RequireComponent(typeof(MeshFilter))]
public class GridMeshGenerator : MonoBehaviour
{
    [Min(2)] public int resolution = 100; // 한 변에 놓일 정점 개수
    public float size = 10f;              // 전체 평면의 한 변 길이 (월드 단위)

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

    // public so callers that change resolution/size from code at runtime (e.g. InfiniteFloorTiler) can
    // force a rebuild - OnValidate() only fires from the editor Inspector, so a runtime field change
    // alone doesn't regenerate the mesh.
    public void Generate()
    {
        var mesh = new Mesh { name = "Grid" };
        mesh.indexFormat = resolution * resolution > 65000
            ? UnityEngine.Rendering.IndexFormat.UInt32
            : UnityEngine.Rendering.IndexFormat.UInt16;

        var vertices = new Vector3[resolution * resolution];
        var uvs = new Vector2[vertices.Length];
        float half = size * 0.5f;

        for (int z = 0; z < resolution; z++)
        {
            for (int x = 0; x < resolution; x++)
            {
                int i = z * resolution + x;
                float u = x / (float)(resolution - 1);
                float v = z / (float)(resolution - 1);
                vertices[i] = new Vector3(u * size - half, 0f, v * size - half);
                uvs[i] = new Vector2(u, v);
            }
        }

        var triangles = new int[(resolution - 1) * (resolution - 1) * 6];
        int t = 0;
        for (int z = 0; z < resolution - 1; z++)
        {
            for (int x = 0; x < resolution - 1; x++)
            {
                int i = z * resolution + x;
                triangles[t++] = i;
                triangles[t++] = i + resolution;
                triangles[t++] = i + 1;

                triangles[t++] = i + 1;
                triangles[t++] = i + resolution;
                triangles[t++] = i + resolution + 1;
            }
        }

        mesh.vertices = vertices;
        mesh.uv = uvs;
        mesh.triangles = triangles;
        mesh.RecalculateNormals();
        mesh.RecalculateBounds();

        GetComponent<MeshFilter>().sharedMesh = mesh;
    }
}
