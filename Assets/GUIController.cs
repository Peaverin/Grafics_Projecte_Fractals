using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class GUIController : MonoBehaviour
{
    [SerializeField]
    public GameObject canvas;
    [SerializeField]
    public GameObject camera;
    public Transform rightSlidersContainer;
    public Transform leftSlidersContainer;
    public GameObject sliderPrefab;
    public FloatVariable[] leftSliderVariables;
    public FloatVariable[] rightSliderVariables;
    public Text lightsText;
    public Text shadowsText;
    public Text lanternText;
    public Text phongText;
    public FloatVariable fractalIterations;
    private bool active;

    private void Awake()
    {
        active = true;
        UpdateGui();
        for (int i = 0; i < rightSliderVariables.Length; i++) {
            GameObject slider = Instantiate(sliderPrefab, rightSlidersContainer, false);
            slider.GetComponent<MenuSlider>().floatVariable = rightSliderVariables[i];
            slider.GetComponent<MenuSlider>().Init();
        }
        for (int i = 0; i < leftSliderVariables.Length; i++)
        {
            GameObject slider = Instantiate(sliderPrefab, leftSlidersContainer, false);
            slider.GetComponent<MenuSlider>().floatVariable = leftSliderVariables[i];
            slider.GetComponent<MenuSlider>().Init();
        }
        lantern = false;
    }

    void Update()
    {
        if (Input.GetKeyDown(KeyCode.Tab) || Input.GetKeyDown(KeyCode.P) || Input.GetKeyDown(KeyCode.Escape)) {
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
        if (Input.GetKeyDown(KeyCode.Alpha1))
        {
            fractalIterations.SetValue(fractalIterations.IntValue - 1);
        }
        else if (Input.GetKeyDown(KeyCode.Alpha2)) {
            fractalIterations.SetValue(fractalIterations.IntValue + 1);
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
        if (c._enableLight)
        {
            lightsText.text = "Disable Lights";
            phongText.GetComponentInParent<Button>().interactable = true;
        }
        else {
            lightsText.text = "Enable Lights";
            phongText.GetComponentInParent<Button>().interactable = false;
        }
    }

    public void ShadowsOnOff() {
        RaymarchCamera c = GameObject.FindObjectOfType<RaymarchCamera>();
        c._enableShadows = !c._enableShadows;
        if (c._enableShadows)
        {
            shadowsText.text = "Disable Shadows";
        }
        else {
            shadowsText.text = "Enable Shadows";
        }
    }

    public void BPOnOff()
    {
        RaymarchCamera c = GameObject.FindObjectOfType<RaymarchCamera>();
        c._blinnPhong = !c._blinnPhong;
        if (c._blinnPhong)
        {
            phongText.text = "Use Basic Lightning";
        }
        else
        {
            phongText.text = "Use B-P Lightning";
        }
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
            lanternText.text = "Deactivate Lantern";
        }
        else {
            dirLight.transform.parent = null;
            dirLight.transform.localPosition = dirLightPos;
            dirLight.transform.localRotation = dirLightRot;
            lanternText.text = "Activate Lantern";
        }
    }
}
