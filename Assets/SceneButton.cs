using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SceneButton : MonoBehaviour
{
    public int scene;

    public void OnClick() {
        GameObject.FindObjectOfType<RaymarchCamera>()._currentScene = scene;
        GameObject.FindObjectOfType<FlyCamera>().Reset();
    }
}
