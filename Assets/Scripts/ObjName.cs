using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

//显示物体名称
public class ObjName : MonoBehaviour
{
    [Header("Obj名称")]
    [SerializeField]
    private string _name;
    [Header("Obj名称偏移量")]
    [SerializeField]
    private float _offset = 3.5f;

    private Camera _camera;

    private void Start()
    {
        _camera = Camera.main;
        
        
    }

    private void OnGUI()
    {
        //获取Obj位置+偏移量
        Vector3 pos = transform.position 
                      + new Vector3(0, _offset, 0);
        //转换为屏幕坐标
        Vector2 namePos = _camera.WorldToScreenPoint(pos);
        
        //获取名称大小
        Vector2 nameSize = GUI.skin.label.CalcSize(new GUIContent(_name));
        
        //展示标签
        GUI.color = Color.yellow;
        GUI.Label(new Rect(namePos.x - nameSize.x / 2, namePos.y - nameSize.y / 2, nameSize.x, nameSize.y), _name);
    }
}
