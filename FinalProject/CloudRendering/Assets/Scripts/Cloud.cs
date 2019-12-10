using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Cloud : MonoBehaviour
{
    public Material cloudRendering;
    public Material cloudBlending;
    private Camera cam;
    private RenderTexture cloud;
    private RenderTexture cloudLastFrame;
    private Matrix4x4 previousVP;

    public RenderTexture skybox;
    // Start is called before the first frame update
    void Start()
    {
        previousVP = Camera.main.projectionMatrix * Camera.main.worldToCameraMatrix;
        //cloud = RenderTexture.active;
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    private void OnEnable()
    {
        cam = GetComponent<Camera>();
        cam.depthTextureMode = DepthTextureMode.Depth;
        cloud = new RenderTexture(1920, 1080, 24, RenderTextureFormat.Default);
        cloudLastFrame = new RenderTexture(1920, 1080, 24, RenderTextureFormat.Default);
        //cloud = RenderTexture.active;
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        cloudRendering.SetVector("_CameraPos", transform.position);
        cloudRendering.SetMatrix("_LastVP", previousVP);
        cloudRendering.SetTexture("_LastCloudTex", cloudLastFrame);
        cloudRendering.SetTexture("_SkyboxTex", skybox);
        CustomBlit(null, cloud, cloudRendering);
        Graphics.CopyTexture(cloud, cloudLastFrame);
        
        cloudBlending.SetTexture("_CloudTex", cloud);
        //Blend the cloud texture with background
        Graphics.Blit(source, destination, cloudBlending);
        previousVP = previousVP = Camera.main.projectionMatrix * Camera.main.worldToCameraMatrix;;
    }

    void CustomBlit(RenderTexture source, RenderTexture dest, Material mat)
    {

        float camFov = cam.fieldOfView;
        float camAspect = cam.aspect;

        float fovWHalf = camFov * 0.5f;

        var cameraTransform = cam.transform;
        Vector3 toRight = camAspect * Mathf.Tan(fovWHalf * Mathf.Deg2Rad) * cameraTransform.right;
        Vector3 toTop = Mathf.Tan(fovWHalf * Mathf.Deg2Rad) * cameraTransform.up;
        //direction of rays
        var forward = cameraTransform.forward;
        Vector3 topLeft = forward - toRight + toTop;
        Vector3 topRight = forward + toRight + toTop;
        Vector3 bottomRight = forward + toRight - toTop;
        Vector3 bottomLeft = forward - toRight - toTop;

        RenderTexture.active = dest;


        GL.PushMatrix();
        GL.LoadOrtho();

        mat.SetPass(0);

        GL.Begin(GL.QUADS);

        GL.MultiTexCoord2(0, 0.0f, 0.0f);
        GL.MultiTexCoord(1, bottomLeft);
        GL.Vertex3(0.0f, 0.0f, 0.0f);

        GL.MultiTexCoord2(0, 1.0f, 0.0f);
        GL.MultiTexCoord(1, bottomRight);
        GL.Vertex3(1.0f, 0.0f, 0.0f);

        GL.MultiTexCoord2(0, 1.0f, 1.0f);
        GL.MultiTexCoord(1, topRight);
        GL.Vertex3(1.0f, 1.0f, 0.0f);

        GL.MultiTexCoord2(0, 0.0f, 1.0f);
        GL.MultiTexCoord(1, topLeft);
        GL.Vertex3(0.0f, 1.0f, 0.0f);

        GL.End();
        GL.PopMatrix();
    }
}
