using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class RaymarchCamera : MonoBehaviour
{
    //ENVIAR A SHADER:
    [SerializeField]
    public int _currentScene;
    [SerializeField]
    FloatVariable _fractalPower;
    [SerializeField]
    FloatVariable _fractalScapeRatio;
    [SerializeField]
    FloatVariable _fractalIterations;
    [SerializeField]
    FloatVariable _fractalScale;
    [SerializeField]
    FloatVariable _foldingLimit;
    [SerializeField]
    FloatVariable _minRadius;
    [SerializeField]
    FloatVariable _fixedRadius;
    [SerializeField]
    FloatVariable _fractalOffset;
    [SerializeField]
    FloatVariable _numIterations;
    [SerializeField]
    FloatVariable _linearDEOffset; // https://github.com/buddhi1980/mandelbulber_doc/releases/tag/2.24.0
    [SerializeField]
    FloatVariable _maxDistance;
    [SerializeField]
    public bool _enableLight;
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

    public Transform _directionalLight;

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (!_rayMarchmaterial) {
            Graphics.Blit(source, destination);
            return;
        }
        //Enviament dades menus:
        _rayMarchmaterial.SetFloat("_fractalPower", _fractalPower.Value);
        _rayMarchmaterial.SetFloat("_fractalScapeRatio", _fractalScapeRatio.Value);
        _rayMarchmaterial.SetInt("_fractalIterations", _fractalIterations.IntValue);
        _rayMarchmaterial.SetFloat("_fractalScale", _fractalScale.Value);
        _rayMarchmaterial.SetFloat("_foldingLimit", _foldingLimit.Value);
        _rayMarchmaterial.SetFloat("_minRadius", _minRadius.Value);
        _rayMarchmaterial.SetFloat("_fixedRadius", _fixedRadius.Value);
        _rayMarchmaterial.SetInt("_fractalOffset", _fractalOffset.IntValue);
        _rayMarchmaterial.SetInt("_currentScene", _currentScene);
        _rayMarchmaterial.SetFloat("_linearDEOffset", _linearDEOffset.Value);
        _rayMarchmaterial.SetInt("_enableLight", _enableLight ? 1 : 0);
        //
        _rayMarchmaterial.SetVector("_LightDir", _directionalLight ? _directionalLight.forward : Vector3.down);
        _rayMarchmaterial.SetMatrix("_CamFrustum", CamFrustum(_camera));
        _rayMarchmaterial.SetMatrix("_CamToWorld", _camera.cameraToWorldMatrix);
        _rayMarchmaterial.SetFloat("_maxDistance", _maxDistance.Value);
        _rayMarchmaterial.SetFloat("_numIterations", _numIterations.IntValue); 
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

