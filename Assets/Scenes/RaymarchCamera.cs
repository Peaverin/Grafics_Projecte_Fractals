using System.Collections;
using System.Collections.Generic;
using UnityEngine;
[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class RaymarchCamera : MonoBehaviour
{
    //ENVIAR A SHADER:
    [SerializeField]
    public int _currentScene;
    [SerializeField, Range(0.01F, 20.0F)]
    float _fractalPower;
    [SerializeField, Range(0.01F, 20.0F)]
    float _fractalScapeRatio;
    [SerializeField, Range(1, 150)]
    int _fractalIterations;
    [SerializeField, Range(0.01F, 10.0F)]
    float _fractalScale;
    [SerializeField, Range(0.01F, 2.0F)]
    float _foldingLimit;
    [SerializeField, Range(0.001F, 1.000F)]
    float _minRadius;
    [SerializeField, Range(0.500F, 10.000F)]
    float _fixedRadius;
    [SerializeField, Range(1, 50)]
    int _fractalOffset;
    [SerializeField, Range(1, 3000)]
    int _numIterations;
    //https://www.youtube.com/watch?v=82iBWIycU0o
    [SerializeField]
    private Shader _shader;

    public Material _rayMarchmaterial {
        get {
            if (!_rayMarchMat && _shader) {
                _rayMarchMat = new Material(_shader);
                _rayMarchMat.hideFlags = HideFlags.HideAndDontSave;
            }
            return _rayMarchMat;
        } 
    }
    private Material _rayMarchMat;

    public Camera _camera {
    get {
            if (!_cam) {
                _cam = GetComponent<Camera>();
            }
            return _cam;
        }
    }

    private Camera _cam;

    public float _maxDistance;

    public Transform _directionalLight;

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (!_rayMarchmaterial) {
            Graphics.Blit(source, destination);
            return;
        }
        //Enviament dades menus:
        _rayMarchmaterial.SetFloat("_fractalPower", _fractalPower);
        _rayMarchmaterial.SetFloat("_fractalScapeRatio", _fractalScapeRatio);
        _rayMarchmaterial.SetInt("_fractalIterations", _fractalIterations);
        _rayMarchmaterial.SetFloat("_fractalScale", _fractalScale);
        _rayMarchmaterial.SetFloat("_foldingLimit", _foldingLimit);
        _rayMarchmaterial.SetFloat("_minRadius", _minRadius);
        _rayMarchmaterial.SetFloat("_fixedRadius", _fixedRadius);
        _rayMarchmaterial.SetInt("_fractalOffset", _fractalOffset);
        _rayMarchmaterial.SetInt("_currentScene", _currentScene);
        //
        _rayMarchmaterial.SetVector("_LightDir", _directionalLight ? _directionalLight.forward : Vector3.down);
        _rayMarchmaterial.SetMatrix("_CamFrustum", CamFrustum(_camera));
        _rayMarchmaterial.SetMatrix("_CamToWorld", _camera.cameraToWorldMatrix);
        _rayMarchmaterial.SetFloat("_maxDistance", _maxDistance);
        _rayMarchmaterial.SetFloat("_numIterations", _numIterations);
        RenderTexture.active = destination;
        GL.PushMatrix();
        GL.LoadOrtho();
        _rayMarchmaterial.SetPass(0);
        GL.Begin(GL.QUADS);

        //BL
        GL.MultiTexCoord2(0, 0.0f, 0.0f);
        GL.Vertex3(0.0f, 0.0f, 3.0f);
        //BR
        GL.MultiTexCoord2(0, 1.0f, 0.0f);
        GL.Vertex3(1.0f, 0.0f, 2.0f);
        //TR
        GL.MultiTexCoord2(0, 1.0f, 1.0f);
        GL.Vertex3(1.0f, 1.0f, 1.0f);
        //TL
        GL.MultiTexCoord2(0, 0.0f, 1.0f);
        GL.Vertex3(0.0f, 1.0f, 0.0f);

        GL.End();
        GL.PopMatrix();

    }

    private Matrix4x4 CamFrustum(Camera cam) {

        Matrix4x4 frustum = Matrix4x4.identity;
        float fov = Mathf.Tan((cam.fieldOfView * 0.5f) * Mathf.Deg2Rad);

        Vector3 goUp = Vector3.up * fov;
        Vector3 goRight = Vector3.right * fov * cam.aspect;

        Vector3 TL = (-Vector3.forward - goRight + goUp);
        Vector3 TR = (-Vector3.forward + goRight + goUp);
        Vector3 BL = (-Vector3.forward - goRight - goUp);
        Vector3 BR = (-Vector3.forward + goRight - goUp);

        frustum.SetRow(0, TL);
        frustum.SetRow(1, TR);
        frustum.SetRow(2, BR);
        frustum.SetRow(3, BL);
        
        return frustum;
    }
}
