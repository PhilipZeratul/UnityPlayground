using UnityEngine;

public class GPUInstancingTest : MonoBehaviour
{

    public Transform prefab;

    public int instances = 5000;

    public float radius = 50f;

    void Start()
    {
        MaterialPropertyBlock propertyBlock = new MaterialPropertyBlock();

        for (int i = 0; i < instances; i++)
        {
            Transform t = Instantiate(prefab);
            t.localPosition = Random.insideUnitSphere * radius;
            t.SetParent(transform);            

            propertyBlock.SetColor("_Color", new Color(Random.value, Random.value, Random.value));
            Renderer renderer = t.GetComponent<Renderer>();
            if (renderer)
                renderer.SetPropertyBlock(propertyBlock);
            else
                foreach (Transform child in t)
                {
                    Renderer r = child.GetComponent<Renderer>();
                    if (r)
                        r.SetPropertyBlock(propertyBlock);
                }
        }
    }
}