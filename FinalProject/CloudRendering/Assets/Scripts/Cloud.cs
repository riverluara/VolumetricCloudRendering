using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Cloud : MonoBehaviour
{
    public Material cloudRendering;
    public Material cloudBlending;
    private Camera cam;
    private RenderTexture cloud;
    private Matrix4x4 previousVP;
    // Start is called before the first frame update
    void Start()
    {
        
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
    }
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        cloudRendering.SetVector("_CameraPos", transform.position);
        
        CustomBlit(null, cloud, cloudRendering);
        cloudBlending.SetTexture("_CloudTex", cloud);
        //Blend the cloud texture with background
        Graphics.Blit(source, destination, cloudBlending);
    }

    void CustomBlit(RenderTexture source, RenderTexture dest, Material mat)
    {

        float camFov = cam.fieldOfView;
        float camAspect = cam.aspect;

        float fovWHalf = camFov * 0.5f;

        Vector3 toRight = cam.transform.right * Mathf.Tan(fovWHalf * Mathf.Deg2Rad) * camAspect;
        Vector3 toTop = cam.transform.up * Mathf.Tan(fovWHalf * Mathf.Deg2Rad);
        //direction of rays
        Vector3 topLeft = (cam.transform.forward - toRight + toTop);
        Vector3 topRight = (cam.transform.forward + toRight + toTop);
        Vector3 bottomRight = (cam.transform.forward + toRight - toTop);
        Vector3 bottomLeft = (cam.transform.forward - toRight - toTop);

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
