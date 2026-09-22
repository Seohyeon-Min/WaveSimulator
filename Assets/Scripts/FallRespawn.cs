using UnityEngine;

// Safety net: if this object's Y position drops below fallYThreshold (e.g. pushed through the floor by a
// physics glitch, like getting pinched between a wave and the ground), snap Y back up to respawnY instead
// of falling forever. X/Z and rotation are left alone. Not a fix for the underlying cause - just a
// guaranteed last line of defense.
[RequireComponent(typeof(Rigidbody))]
public class FallRespawn : MonoBehaviour
{
    public float fallYThreshold = -10f;
    public float respawnY = 0f;

    Rigidbody rb;

    void Awake()
    {
        rb = GetComponent<Rigidbody>();
    }

    void Update()
    {
        if (transform.position.y < fallYThreshold) Respawn();
    }

    void Respawn()
    {
        Vector3 pos = transform.position;
        pos.y = respawnY;
        transform.position = pos;

        rb.linearVelocity = Vector3.zero;
        rb.angularVelocity = Vector3.zero;
    }
}
