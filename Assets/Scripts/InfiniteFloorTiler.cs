using UnityEngine;

// True infinite floor: keeps a fixed (2*gridRadius+1)^2 grid of tile GameObjects permanently around the
// player. Nothing is ever created or destroyed after Start() - when the player crosses from one tile cell
// into the next, the whole grid's world positions are just recentered around the player's new cell,
// recycling the same tile objects. That's what makes the ground look endless using a constant, bounded
// number of tiles instead of spawning more as the player travels.
//
// All tiles are identical in shape (same resolution/size), so rather than every tile building its own copy
// of that mesh (9 tiles = 9x the vertex data for the exact same shape), the mesh is generated ONCE via a
// throwaway GridMeshGenerator, cloned into a second copy, and every tile's MeshFilter just points at
// whichever of those two cached Mesh assets its checkerboard position picks - GPU/memory cost stays at 2
// meshes total no matter how big the grid gets. (Two rather than one so neighboring tiles can be told apart
// if that's ever needed - e.g. offsetting one variant's UVs later to break up an obviously-repeating look.)
public class InfiniteFloorTiler : MonoBehaviour
{
    public Transform player;
    public float tileSize = 100f;
    [Min(0)] public int gridRadius = 1; // 1 => 3x3 grid of tiles, 2 => 5x5, etc.
    [Min(2)] public int tileResolution = 223; // Vertices per tile side, used once to build the shared cached mesh
    public Material tileMaterial;
    public LayerMask floorLayer; // Applied to every tile's GameObject so ground-check raycasts (see Movement._groundLayer) hit them
    public float colliderThickness = 1f;

    GameObject[,] tiles;
    Vector2Int centerCell;
    bool initialized;

    void Start()
    {
        Mesh meshA = BuildSharedMesh();
        Mesh meshB = Instantiate(meshA);
        meshB.name = meshA.name + " (B)";

        int gridSize = gridRadius * 2 + 1;
        tiles = new GameObject[gridSize, gridSize];

        for (int x = 0; x < gridSize; x++)
        {
            for (int z = 0; z < gridSize; z++)
            {
                Mesh mesh = (x + z) % 2 == 0 ? meshA : meshB;
                tiles[x, z] = BuildTile(x, z, mesh);
            }
        }

        // Forces RepositionAll() to run on the very first Update no matter what cell the player starts in
        centerCell = WorldToCell(player != null ? player.position : transform.position) + Vector2Int.one;
        initialized = true;
        RepositionAll();
    }

    // Builds the one real copy of the tile mesh via a throwaway GridMeshGenerator, then discards the
    // GameObject/component - only the Mesh asset itself is kept.
    Mesh BuildSharedMesh()
    {
        var temp = new GameObject("TempFloorMeshBuilder");
        temp.AddComponent<MeshFilter>();
        var generator = temp.AddComponent<GridMeshGenerator>();
        generator.resolution = tileResolution;
        generator.size = tileSize;
        generator.Generate();

        Mesh mesh = temp.GetComponent<MeshFilter>().sharedMesh;
        Destroy(temp);
        return mesh;
    }

    GameObject BuildTile(int x, int z, Mesh mesh)
    {
        var tile = new GameObject($"FloorTile_{x}_{z}");
        tile.transform.SetParent(transform, false);
        tile.layer = LayerMaskToLayer(floorLayer);

        tile.AddComponent<MeshFilter>().sharedMesh = mesh;

        var renderer = tile.AddComponent<MeshRenderer>();
        if (tileMaterial != null) renderer.sharedMaterial = tileMaterial;

        var collider = tile.AddComponent<BoxCollider>();
        collider.size = new Vector3(tileSize, colliderThickness, tileSize);
        collider.center = new Vector3(0f, -colliderThickness * 0.5f, 0f);

        return tile;
    }

    static int LayerMaskToLayer(LayerMask mask)
    {
        int value = mask.value;
        for (int i = 0; i < 32; i++)
        {
            if ((value & (1 << i)) != 0) return i;
        }
        return 0;
    }

    void Update()
    {
        if (!initialized || player == null) return;

        Vector2Int playerCell = WorldToCell(player.position);
        if (playerCell != centerCell)
        {
            centerCell = playerCell;
            RepositionAll();
        }
    }

    Vector2Int WorldToCell(Vector3 worldPos)
    {
        return new Vector2Int(
            Mathf.FloorToInt(worldPos.x / tileSize),
            Mathf.FloorToInt(worldPos.z / tileSize)
        );
    }

    // GridMeshGenerator centers its mesh on its own local origin (from -size/2 to +size/2), so a tile
    // representing cell (cellX, cellZ) needs to sit at that cell's CENTER, not its corner.
    void RepositionAll()
    {
        int gridSize = gridRadius * 2 + 1;
        float floorY = transform.position.y;

        for (int x = 0; x < gridSize; x++)
        {
            for (int z = 0; z < gridSize; z++)
            {
                int cellX = centerCell.x + (x - gridRadius);
                int cellZ = centerCell.y + (z - gridRadius);
                tiles[x, z].transform.position = new Vector3((cellX + 0.5f) * tileSize, floorY, (cellZ + 0.5f) * tileSize);
            }
        }
    }
}
