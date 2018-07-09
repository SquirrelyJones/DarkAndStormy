

using UnityEngine;
using System.Collections;
#if UNITY_EDITOR
using UnityEditor;
#endif

[ExecuteInEditMode]
public class MatchEditorCamera : MonoBehaviour {

	private Camera myCamera;
	public bool matchCameraDurringPlay = true;
	public float swimAmount = 0.5f;
	public float swimSpeed = 0.5f;
	public float smoothing = 10f;
	public float speed = 5.0f;
	
	private Vector3 targetPos = Vector3.zero;
	private Quaternion targetRotation = Quaternion.identity;
	private Vector3 mousePos = Vector3.zero;
	private float targetFov = 60.0f;
	
	private Transform targetTransform;

#if UNITY_EDITOR
	private SceneView sceneView;
	private EditorApplication.CallbackFunction cbf_UpdateCamera;
#endif
	
	// Use this for initialization
	void Start () {
		myCamera = this.GetComponent<Camera>();	
		
//#if UNITY_EDITOR

//#else
		if( Application.isPlaying == true && matchCameraDurringPlay ){
			targetTransform = new GameObject().transform;
			targetTransform.name = "CameraTargetTransform";
			targetTransform.position = myCamera.transform.position;
			targetTransform.rotation = myCamera.transform.rotation;
		}
//#endif
	}
	
#if UNITY_EDITOR
	void UpdateCamera() {

		if( Application.isPlaying == false || matchCameraDurringPlay == true ){
		
			if( myCamera != null ){
				myCamera.ResetProjectionMatrix();
				if( SceneView.currentDrawingSceneView != null ){
					sceneView = SceneView.currentDrawingSceneView;
				}
				if( sceneView != null ){
					targetRotation = sceneView.camera.transform.rotation;
					targetPos = sceneView.camera.transform.position;
					targetFov = sceneView.camera.fieldOfView;
					

					float randRotX = Mathf.Sin( Time.fixedTime * 2.17f * swimSpeed ) + Mathf.Sin( Time.fixedTime * 0.73f * swimSpeed );
					float randRotY = Mathf.Sin( Time.fixedTime * 2.73f * swimSpeed ) + Mathf.Sin( Time.fixedTime * 1.17f * swimSpeed );
					float randRotZ = Mathf.Sin( Time.fixedTime * 3.17f * swimSpeed ) + Mathf.Sin( Time.fixedTime * 1.31f * swimSpeed );
						
					targetRotation = targetRotation * Quaternion.Euler( randRotX * swimAmount, randRotY * swimAmount, randRotZ * swimAmount );
					
					myCamera.transform.position += ( targetPos - myCamera.transform.position ) * Mathf.Clamp01( 1.0f / smoothing );
					myCamera.transform.rotation = Quaternion.Slerp( myCamera.transform.rotation, targetRotation, Mathf.Clamp01( 1.0f / smoothing ) );
					
					//myCamera.transform.position = targetPos;
					//myCamera.transform.rotation = targetRotation;
					
					myCamera.fieldOfView = targetFov;

				}
				
			}
		}

	}
#endif
	
	void OnEnable() {
		//Debug.Log(this + " OnEnable");
#if UNITY_EDITOR
		cbf_UpdateCamera = new EditorApplication.CallbackFunction(UpdateCamera);
		EditorApplication.update += cbf_UpdateCamera;
#endif
	}
	
	void OnDisable() {
		//Debug.Log(this + " OnDisable");
#if UNITY_EDITOR
		EditorApplication.update -= cbf_UpdateCamera;
#endif
	}
	
	// Update is called once per frame
	void Update () {

#if UNITY_EDITOR		
		if( Application.isPlaying == true && matchCameraDurringPlay == false ){
#endif		
			/*
			float deltaTime = Time.deltaTime;
			
			float horizontal = Input.GetAxis("R_Horizontal");
			float vertical = Input.GetAxis("R_Vertical");
			
			float motionRight = Input.GetAxis("Horizontal");
			float motionForward = Input.GetAxis("Vertical");
			
			float motionUp = 0.0f;
			if( Input.GetButton("Jump") ){
				motionUp += speed;
			}
			if( Input.GetButton("Fire1") ){
				motionUp -= speed;
			}
			if( Input.GetButton("Fire2") ){
				motionUp -= speed;
			}
			if( Input.GetButton("Fire3") ){
				motionUp -= speed;
			}
		
			targetTransform.RotateAround( targetTransform.position, Vector3.up, horizontal * 200.0f * deltaTime );
			targetTransform.RotateAround( targetTransform.position, targetTransform.right, vertical * 150.0f * deltaTime );
			
			targetTransform.position += targetTransform.right * motionRight * speed * deltaTime;
			targetTransform.position += targetTransform.forward * motionForward * speed * deltaTime;
			
			targetTransform.position += new Vector3( 0.0f, motionUp * deltaTime, 0.0f );
			
			float randRotX = Mathf.Sin( Time.fixedTime * 2.17f * swimSpeed ) + Mathf.Sin( Time.fixedTime * 0.73f * swimSpeed );
			float randRotY = Mathf.Sin( Time.fixedTime * 2.73f * swimSpeed ) + Mathf.Sin( Time.fixedTime * 1.17f * swimSpeed );
			float randRotZ = Mathf.Sin( Time.fixedTime * 3.17f * swimSpeed ) + Mathf.Sin( Time.fixedTime * 1.31f * swimSpeed );
			
			targetRotation = targetTransform.rotation * Quaternion.Euler( randRotX * swimAmount, randRotY * swimAmount, randRotZ * swimAmount );
	
			
			myCamera.transform.rotation = Quaternion.Slerp( myCamera.transform.rotation, targetRotation, smoothing * deltaTime );
			myCamera.transform.position += ( targetTransform.position - myCamera.transform.position ) * smoothing * deltaTime;
			*/
#if UNITY_EDITOR		
		}
#endif			
	}
}
