using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RotateByTime : MonoBehaviour
{
    public float Speed = 1.0f;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        transform.rotation *= Quaternion.AngleAxis(Speed * Time.deltaTime, Vector3.right);
    }
}
