using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
public class GradientToolWindow : EditorWindow
{
    Editor gradientEditor;
    [MenuItem("Tools/GradientTool")]
    private static void init()
    {
        GradientToolWindow window = GetWindow<GradientToolWindow>();
        window.gradientEditor = Editor.CreateEditor(ScriptableObject.CreateInstance<CustomGradientForEditor>());
        window.Show();
    }

    private void OnGUI()
    {
        if (gradientEditor != null)
        {
            gradientEditor.OnInspectorGUI();
        }

    }
}
