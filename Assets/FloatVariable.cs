using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu]
public class FloatVariable : ScriptableObject
{
    [SerializeField]
    private float value;
    [SerializeField]
    public string text;
    [SerializeField]
    public float minValue;
    [SerializeField]
    public float maxValue;
    [SerializeField]
    public bool isInt; 

    public float Value {
        get => isInt ? (int)value : value;
    }
    public int IntValue { get => (int)value; }
    public void SetValue(float value ) {
        this.value = value;
    }

}
