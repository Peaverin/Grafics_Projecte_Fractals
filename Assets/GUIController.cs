using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GUIController : MonoBehaviour
{
    [SerializeField]
    public GameObject canvas;
    [SerializeField]
    public GameObject camera;
    public Transform slidersContainer;
    public GameObject sliderPrefab;
    public FloatVariable[] sliderVariables;
    private bool active;

    private void Awake()
    {
        active = true;
        UpdateGui();
        for (int i = 0; i < sliderVariables.Length; i++) {
            GameObject slider = Instantiate(sliderPrefab, slidersContainer, false);
            slider.GetComponent<MenuSlider>().floatVariable = sliderVariables[i];
            slider.GetComponent<MenuSlider>().Init();
        }
        lantern = false;
    }

    void Update()
    {
        if (Input.GetKeyDown(KeyCode.P) || Input.GetKeyDown(KeyCode.Escape)) {
            active = !active;
            if (active)
            {
                Cursor.visible = true;
            }
            else {
                Cursor.visible = false;
                
            }
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

    public void ResetCamera() {
        GameObject.FindObjectOfType<FlyCamera>().Reset();
    }

    public void LightsOnOff() {
        RaymarchCamera c = GameObject.FindObjectOfType<RaymarchCamera>();
        c._enableLight = !c._enableLight;
    }


    private bool lantern;
    private Vector3 dirLightPos;
    private Quaternion dirLightRot;
    public void LanterOnOff() {
        Light dirLight = GameObject.FindObjectOfType<Light>();
        lantern = !lantern;
        if (lantern)//activada
        {
            dirLightPos = dirLight.transform.position;
            dirLightRot = dirLight.transform.rotation;
            dirLight.transform.parent = GameObject.FindObjectOfType<Camera>().transform;
            dirLight.transform.localPosition = new Vector3(0, 0, 0);
            dirLight.transform.localRotation = Quaternion.Euler(0, 0, 0);
        }
        else {
            dirLight.transform.parent = null;
            dirLight.transform.localPosition = dirLightPos;
            dirLight.transform.localRotation = dirLightRot;
        }
    }
}
