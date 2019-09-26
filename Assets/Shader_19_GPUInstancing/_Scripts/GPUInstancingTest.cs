using UnityEngine;

public class GPUInstancingTest : MonoBehaviour
{

    public Transform prefab;

    public int instances = 5000;

    public float radius = 50f;

    void Start()
    {
        for (int i = 0; i < instances; i++)
        {
            Transform t = Instantiate(prefab);
            t.localPosition = Random.insideUnitSphere * radius;
            t.SetParent(transform);
        }
    }
}