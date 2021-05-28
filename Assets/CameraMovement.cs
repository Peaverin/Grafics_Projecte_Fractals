using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CameraMovement : MonoBehaviour
{
    [SerializeField]
    public float forwardSpeed;
    void FixedUpdate()
    {
        if (Input.GetKey(KeyCode.W)) {
            transform.position = transform.position + transform.forward * forwardSpeed * Time.fixedDeltaTime;
        }
        else if (Input.GetKey(KeyCode.S))
        {
            transform.position = transform.position - transform.forward * forwardSpeed * Time.fixedDeltaTime;
        }
    }
}
