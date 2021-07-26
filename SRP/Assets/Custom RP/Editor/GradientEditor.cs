using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
public class GradientEditor : EditorWindow
{
    CustomGradient gradient;
    const int borderSize = 10;
    const float keyWidth = 10;
    const float keyHeight = 20;

    Rect[] keyRects;
    private bool mouseIsDownOverKey;
    private int selectKeyIndex;
    private bool needRepaint;
    private Rect gradientRect;

    private void OnGUI()
    {

        Draw();
        HandleInput();
        if (needRepaint)
        {
            needRepaint = false;
            Repaint();
        }
    }
    void Draw()
    {
        gradientRect = new Rect(borderSize, borderSize, position.width - borderSize * 2, 25);
        GUI.DrawTexture(gradientRect, gradient.GetTexture((int)gradientRect.width));

        keyRects = new Rect[gradient.NumKeys];
        for (int i = 0; i < gradient.NumKeys; i++)
        {
            CustomGradient.ColorKey key = gradient.GetKey(i);
            Rect keyRect = new Rect(gradientRect.x + gradientRect.width * key.Precent - keyWidth / 2f,
                gradientRect.yMax + borderSize, keyWidth, keyHeight);
            if (i == selectKeyIndex)
            {
                EditorGUI.DrawRect(new Rect(keyRect.x - 2, keyRect.y - 2,
                    keyRect.width + 4, keyRect.height + 4), Color.black);
            }
            EditorGUI.DrawRect(keyRect, key.Col);
            keyRects[i] = keyRect;
        }
        Rect settingsRect = new Rect(borderSize, keyRects[0].yMax + borderSize, position.width - borderSize * 2, position.height);
        GUILayout.BeginArea(settingsRect);
        EditorGUI.BeginChangeCheck();
        Color newCol = EditorGUILayout.ColorField(gradient.GetKey(selectKeyIndex).Col);
        if (EditorGUI.EndChangeCheck())
        {
            gradient.UpdateKeyColor(selectKeyIndex, newCol);
        }
        gradient.blendMode = (CustomGradient.BlendMode)EditorGUILayout.EnumPopup("Blend mode", gradient.blendMode);
        GUILayout.EndArea();
    }
    void HandleInput()
    {
        Event guiEvent = Event.current;
        if (guiEvent.type == EventType.MouseDown && guiEvent.button == 0)
        {
            for (int i = 0; i < keyRects.Length; i++)
            {
                if (keyRects[i].Contains(guiEvent.mousePosition))
                {
                    mouseIsDownOverKey = true;
                    selectKeyIndex = i;
                    needRepaint = true;
                    break;
                }
            }
            if (!mouseIsDownOverKey)
            {
                if (guiEvent.mousePosition.y <= gradientRect.yMax + borderSize *3)
                {
                    float keyPrecent = Mathf.InverseLerp(gradientRect.x, gradientRect.xMax, guiEvent.mousePosition.x);
                    Color color = gradient.Evaluate(keyPrecent);
                    selectKeyIndex = gradient.AddKey(color, keyPrecent);
                    mouseIsDownOverKey = true;
                    needRepaint = true;
                }
                
            }
        }
        if (guiEvent.type == EventType.MouseUp && guiEvent.button == 0)
        {
            mouseIsDownOverKey = false;
        }
        if (mouseIsDownOverKey && guiEvent.type == EventType.MouseDrag && guiEvent.button == 0)
        {
            if (guiEvent.mousePosition.y <= gradientRect.yMax + borderSize * 6)
            {
                float keyPrecent = Mathf.InverseLerp(gradientRect.x, gradientRect.xMax, guiEvent.mousePosition.x);
                gradient.UpdateKeyPrecent(selectKeyIndex, keyPrecent);
                needRepaint = true;
            }
            else
            {
                gradient.RemoveKey(selectKeyIndex);
                if (selectKeyIndex >= gradient.NumKeys)
                {
                    selectKeyIndex--;
                }
                mouseIsDownOverKey = false;
                needRepaint = true;
            }
        }

        if (guiEvent.keyCode == KeyCode.Backspace && guiEvent.type == EventType.KeyDown)
        {
            gradient.RemoveKey(selectKeyIndex);
            if (selectKeyIndex >= gradient.NumKeys)
            {
                selectKeyIndex--;
            }
            needRepaint = true;
        }
     

    }
    public CustomGradient Gradient
    {
        set
        {
            gradient = value;
        }
    }
    private void OnEnable()
    {
        titleContent.text = "Gradient Editor";
        position.Set(position.x, position.y, 400, 150);
        minSize = new Vector2(200, 150);
        maxSize = new Vector2(1920, 150);
    }

    private void OnDisable()
    {
        UnityEditor.SceneManagement.EditorSceneManager.MarkSceneDirty(UnityEngine.SceneManagement.SceneManager.GetActiveScene());
    }

}
