using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class ScenesMenu : MonoBehaviour
{
    [SerializeField]
    int scenesAmount;
    [SerializeField]
    GameObject sceneBtnPrefab;
    private void Start()
    {
        //rayMarch.GetComponent<RaymarchCamera>()._currentScene;
        for (int i = 0; i < scenesAmount; i++) {
            GameObject btn = Instantiate(sceneBtnPrefab, transform, false);
            RectTransform rT = btn.GetComponent<RectTransform>();
            Vector3 position = rT.anchoredPosition;
            rT.anchoredPosition = new Vector3(i * 90, position.y, position.z);
            btn.GetComponent<SceneButton>().scene = i;
            btn.GetComponentInChildren<Text>().text = i.ToString();
        }
    }
}
