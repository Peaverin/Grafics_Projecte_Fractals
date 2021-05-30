using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class MenuSlider : MonoBehaviour
{
    public FloatVariable floatVariable;

    private Slider sliderComponent;
    private Text textComponent;
    private string text;
    public void Init()
    {
        sliderComponent = GetComponent<Slider>();
        textComponent = GetComponentInChildren<Text>();

        sliderComponent.minValue = floatVariable.minValue;
        sliderComponent.maxValue = floatVariable.maxValue;
        sliderComponent.wholeNumbers = floatVariable.isInt;
        sliderComponent.onValueChanged.AddListener(SliderUpdate);
        sliderComponent.value = floatVariable.Value;
        text = floatVariable.text;
       
        int index = transform.parent.transform.childCount - 1;
        RectTransform r = GetComponent<RectTransform>();
        r.anchoredPosition = new Vector3(0, -60 - 100 * index, 0);

        UpdateText();
    }

    void SliderUpdate(float value)
    {
        floatVariable.SetValue(value);
        UpdateText();
    }

    void UpdateText() {
        textComponent.text = text + ": " + floatVariable.Value;
    }

}
