
using UnityEngine;


[ExecuteInEditMode]
[AddComponentMenu("Post Process/Post Process")]
[RequireComponent(typeof(UnityEngine.Camera))]
public class PostProcess : MonoBehaviour
{
    enum Pass
    {
        Compose = 0,
        Mip = 1,
        Threshold = 2,
        Blur = 3,
        ZoomBlur = 4,
    };

    public Shader PostProcessShader;

    [Header("Bloom:")]
    [Range(0.0f, 3.0f)]
    public float BloomThreshold = 1.0f;

    [Range(0.0f, 1.0f)]
    public float BloomExtra = 0.1f;

    [Range(0.0f, 10.0f)]
    public float BloomAmount = 4.0f;

    [Range(1.0f, 8.0f)]
    public float BloomSpread = 6.0f;

    [Header("God Rays")]

	public Light _sunLight;

    [Range(0.0f, 1.0f)]
    public float GodRayGlow = 0.1f;

    [Range(0.0f, 5.0f)]
    public float GodRayAmount = 1.0f;

    [Range(0.0f, 1.0f)]
    public float GodRayLength = 1.0f;

    public int GodRaySteps = 10;

    private Material _postProcessMaterial;

    private RenderTexture _bloomThresholdTexture;
    private RenderTexture _bloomThresholdTextureMip1;
    private RenderTexture _bloomThresholdTextureMip2;
    private RenderTexture _bloomBlurX;
    private RenderTexture _bloomBlurY;

    private RenderTexture _godrayBlur1;
    private RenderTexture _godrayBlur2;

    private UnityEngine.Camera _thisCamera;

    private bool _initialized = false;    

    void OnActivate()
    {
        OnEnable();
    }

    void Start()
    {
        OnEnable();
    }

    void OnEnable()
    {
        if (_initialized == false)
        {
            _thisCamera = this.GetComponent<UnityEngine.Camera>();
            _thisCamera.depthTextureMode = DepthTextureMode.Depth;

            //Create Post Process Material
            if (PostProcessShader == null)
            {
                PostProcessShader = Shader.Find("Hidden/PostProcess");
            }

            if (PostProcessShader == null)
            {
                Debug.Log("#ERROR# Hidden/PostProcess Shader not found");
                return;
            }

            if (_postProcessMaterial != null)
            {
                _postProcessMaterial = null;
            }

            _postProcessMaterial = new Material(PostProcessShader);
            _postProcessMaterial.hideFlags = HideFlags.HideAndDontSave;

            _initialized = true;
        }
    }

    void CleanUpTextures()
    {
        if (_bloomThresholdTexture)
        {
            RenderTexture.ReleaseTemporary(_bloomThresholdTexture);
            _bloomThresholdTexture = null;
        }

        if (_bloomThresholdTextureMip1)
        {
            RenderTexture.ReleaseTemporary(_bloomThresholdTextureMip1);
            _bloomThresholdTextureMip1 = null;
        }

        if (_bloomThresholdTextureMip2)
        {
            RenderTexture.ReleaseTemporary(_bloomThresholdTextureMip2);
            _bloomThresholdTextureMip2 = null;
        }

        if (_bloomBlurX)
        {
            RenderTexture.ReleaseTemporary(_bloomBlurX);
            _bloomBlurX = null;
        }

        if (_bloomBlurY)
        {
            RenderTexture.ReleaseTemporary(_bloomBlurY);
            _bloomBlurY = null;
        }

        if (_godrayBlur1)
        {
            RenderTexture.ReleaseTemporary(_godrayBlur1);
            _godrayBlur1 = null;
        }

        if (_godrayBlur2)
        {
            RenderTexture.ReleaseTemporary(_godrayBlur2);
            _godrayBlur2 = null;
        }

    }

    void OnDisable()
    {
        CleanUpTextures();
        _initialized = false;
    }


    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {

        int _screenX = source.width;
        int _screenY = source.height;

        Vector2 _screenSize = new Vector2(source.width, source.height);
        Vector2 _screenSizeHalf = new Vector2(source.width / 2, source.height / 2);
        Vector2 _screenSizeQuarter = new Vector2(source.width / 4, source.height / 4);
        Vector2 _screenSizeEighth = new Vector2(source.width / 8, source.height / 8);

        //==================================================================//
        // 		Calculate threshold and bloom based on screen color			//
        //==================================================================//

        _postProcessMaterial.SetFloat("_BloomThreshold", BloomThreshold);
        _postProcessMaterial.SetFloat("_BloomExtra", BloomExtra);
        _postProcessMaterial.SetFloat("_ScreenX", _screenSizeHalf.x);
        _postProcessMaterial.SetFloat("_ScreenY", _screenSizeHalf.y);
        _postProcessMaterial.SetVector("_OneOverScreenSize", new Vector2(1.0f / _screenSizeHalf.x, 1.0f / _screenSizeHalf.y));

        if (_sunLight) {
            _postProcessMaterial.SetVector("_SunDir", _sunLight.transform.forward);
        } else {
            _postProcessMaterial.SetVector("_SunDir", Vector3.zero);
        }

        _postProcessMaterial.SetVector("_ViewDirTL", _thisCamera.ScreenPointToRay(new Vector3(0, _screenY, 0)).direction);
        _postProcessMaterial.SetVector("_ViewDirTR", _thisCamera.ScreenPointToRay(new Vector3(_screenX, _screenY, 0)).direction);
        _postProcessMaterial.SetVector("_ViewDirBL", _thisCamera.ScreenPointToRay(new Vector3(0, 0, 0)).direction);
        _postProcessMaterial.SetVector("_ViewDirBR", _thisCamera.ScreenPointToRay(new Vector3(_screenX, 0, 0)).direction);

        _bloomThresholdTexture = RenderTexture.GetTemporary((int) _screenSizeHalf.x, (int) _screenSizeHalf.y, 0, RenderTextureFormat.ARGBHalf);
        Graphics.Blit(source, _bloomThresholdTexture, _postProcessMaterial, (int) Pass.Threshold);

        _postProcessMaterial.SetFloat("_ScreenX", _screenSizeQuarter.x);
        _postProcessMaterial.SetFloat("_ScreenY", _screenSizeQuarter.y);
        _postProcessMaterial.SetVector("_OneOverScreenSize", new Vector2(1.0f / _screenSizeQuarter.x, 1.0f / _screenSizeQuarter.y));

        _bloomThresholdTextureMip1 = RenderTexture.GetTemporary((int) _screenSizeQuarter.x, (int) _screenSizeQuarter.y, 0, RenderTextureFormat.ARGBHalf);
        Graphics.Blit(_bloomThresholdTexture, _bloomThresholdTextureMip1, _postProcessMaterial, (int) Pass.Mip);

        _postProcessMaterial.SetFloat("_ScreenX", _screenSizeEighth.x);
        _postProcessMaterial.SetFloat("_ScreenY", _screenSizeEighth.y);
        _postProcessMaterial.SetVector("_OneOverScreenSize", new Vector2(1.0f / _screenSizeEighth.x, 1.0f / _screenSizeEighth.y));

        _bloomThresholdTextureMip2 = RenderTexture.GetTemporary((int) _screenSizeEighth.x, (int) _screenSizeEighth.y, 0, RenderTextureFormat.ARGBHalf);
        Graphics.Blit(_bloomThresholdTextureMip1, _bloomThresholdTextureMip2, _postProcessMaterial, (int) Pass.Mip);

        _bloomBlurX = RenderTexture.GetTemporary((int) _screenSizeEighth.x, (int) _screenSizeEighth.y, 0, RenderTextureFormat.DefaultHDR);
        _bloomBlurY = RenderTexture.GetTemporary((int) _screenSizeEighth.x, (int) _screenSizeEighth.y, 0, RenderTextureFormat.DefaultHDR);

        _postProcessMaterial.SetFloat("_BlurSpread", 1.0f);

        _postProcessMaterial.SetVector("_BlurDir", new Vector2(1.0f, 0.0f));
        Graphics.Blit(_bloomThresholdTextureMip1, _bloomBlurX, _postProcessMaterial, (int) Pass.Blur);

        _postProcessMaterial.SetVector("_BlurDir", new Vector2(0.0f, 1.0f));
        Graphics.Blit(_bloomBlurX, _bloomBlurY, _postProcessMaterial, (int) Pass.Blur);

        // Save tighter version of bloom
        Graphics.Blit(_bloomBlurY, _bloomThresholdTextureMip2);

        _postProcessMaterial.SetFloat("_BlurSpread", BloomSpread);

        _postProcessMaterial.SetVector("_BlurDir", new Vector2(1.0f, 0.0f));
        Graphics.Blit(_bloomBlurY, _bloomBlurX, _postProcessMaterial, (int) Pass.Blur);

        _postProcessMaterial.SetVector("_BlurDir", new Vector2(0.0f, 1.0f));
        Graphics.Blit(_bloomBlurX, _bloomBlurY, _postProcessMaterial, (int) Pass.Blur);

        // GodRays
        if (_sunLight)
        {
            _postProcessMaterial.SetMatrix("_CameraVPMatrix", _thisCamera.worldToCameraMatrix * _thisCamera.projectionMatrix);
            Vector3 _godRayScreenPos = _thisCamera.WorldToScreenPoint(_thisCamera.transform.position - _sunLight.transform.forward * 10000.0f);
            _postProcessMaterial.SetVector("_GodRayScreenPos", new Vector3(_godRayScreenPos.x / _screenX, _godRayScreenPos.y / _screenY, _godRayScreenPos.z));

            _godrayBlur1 = RenderTexture.GetTemporary((int) _screenSizeQuarter.x, (int) _screenSizeQuarter.y, 0, RenderTextureFormat.ARGBHalf);
            _godrayBlur2 = RenderTexture.GetTemporary((int) _screenSizeQuarter.x, (int) _screenSizeQuarter.y, 0, RenderTextureFormat.ARGBHalf);

            float fadeAmount = 1.0f;

            _postProcessMaterial.SetInt("_GodRaySteps", GodRaySteps);
            _postProcessMaterial.SetFloat("_GodRayLength", GodRayLength);
            _postProcessMaterial.SetFloat("_GodRayFalloff", 1.0f);
            _postProcessMaterial.SetVector("_GodrayGlow", _sunLight.color * _sunLight.intensity * GodRayGlow * fadeAmount);
            _postProcessMaterial.SetTexture("_GodRayTex", _bloomThresholdTextureMip1);
            Graphics.Blit(source, _godrayBlur1, _postProcessMaterial, (int) Pass.ZoomBlur);
            _postProcessMaterial.SetFloat("_GodRayLength", GodRayLength / GodRaySteps * 3.0f);
            _postProcessMaterial.SetFloat("_GodRayFalloff", 1.0f / GodRaySteps);
            _postProcessMaterial.SetVector("_GodrayGlow", Vector4.zero);
            _postProcessMaterial.SetTexture("_GodRayTex", _godrayBlur1);
            Graphics.Blit(source, _godrayBlur2, _postProcessMaterial, (int) Pass.ZoomBlur);

            _postProcessMaterial.SetTexture("_GodRayTex", _godrayBlur2);
            _postProcessMaterial.SetTexture("_GodRayTexAlt", _godrayBlur1);
        }
        else
        {
            _postProcessMaterial.SetTexture("_GodRayTex", Texture2D.blackTexture);
        }

        //==========================================================================================//
        // 									Comp it all together									//
        //==========================================================================================//

        _postProcessMaterial.SetTexture("_BloomTex", _bloomBlurY);
        _postProcessMaterial.SetTexture("_BloomTex2", _bloomThresholdTextureMip2);
		_postProcessMaterial.SetFloat("_BloomAmount", BloomAmount);
		_postProcessMaterial.SetFloat("_GodRayAmount", GodRayAmount);

        Graphics.Blit(source, destination, _postProcessMaterial, (int) Pass.Compose);

        CleanUpTextures();
    }
}
