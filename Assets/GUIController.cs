using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GUIController : MonoBehaviour
{
    [SerializeField]
    public GameObject canvas;
    [SerializeField]
    public GameObject camera;
    private bool active;

    private void Start()
    {
        active = true;
        UpdateGui();
    }

    void Update()
    {
        if (Input.GetKeyDown(KeyCode.Escape)) {
            active = !active;
            UpdateGui();
        }
    }

    void UpdateGui() {
        camera.GetComponent<FlyCamera>().enabled = !active;
        for (int i = 0; i < canvas.transform.childCount; i++)
        {
            canvas.transform.GetChild(i).gameObject.SetActive(active);
        }
    }
}
