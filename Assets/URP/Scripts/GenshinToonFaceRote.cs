using UnityEngine;

namespace Urp
{
    /// <summary>
    /// 面部朝向变更处理
    /// </summary>
    [ExecuteInEditMode]
    public class GenshinToonFaceRote : MonoBehaviour
    {
        [Header("头部Trs")]
        public Transform HeadTrs;
        [Header("面部材质")]
        public Material FaceMat;
        private void Update()
        {
            if (!HeadTrs || !FaceMat)
            {
                return;
            }
            
            FaceMat.SetVector("_HeadForward", HeadTrs.forward);
            FaceMat.SetVector("_HeadRight", HeadTrs.right);
            FaceMat.SetVector("_HeadUp", HeadTrs.up);
        }
    }
}