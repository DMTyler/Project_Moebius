using UnityEditor;
using UnityEngine;

public class Vector2Range : PropertyAttribute
{
    public float MinX { get; }
    public float MaxX { get; }
    public float MinY { get; }
    public float MaxY { get; }
    
    public Vector2Range(float minX, float maxX, float minY, float maxY)
    {
        MinX = minX;
        MaxX = maxX;
        MinY = minY;
        MaxY = maxY;
    }
}

[CustomPropertyDrawer(typeof(Vector2Range))]
public class Vector2RangeDrawer : PropertyDrawer
{
    public override void OnGUI(Rect position, SerializedProperty property, GUIContent label)
    {
        if (property.propertyType != SerializedPropertyType.Vector2)
        {
            EditorGUI.LabelField(position, label.text, "Use Vector2Range with Vector2.");
            return;
        }
        
        var range = (Vector2Range)attribute;
        EditorGUI.BeginProperty(position, label, property);
        
        EditorGUI.PrefixLabel(position, label);
        
        var vec2Value = property.vector2Value;

        var x = EditorGUILayout.Slider("X", vec2Value.x, range.MinX, range.MaxX);
        var y = EditorGUILayout.Slider("Y", vec2Value.y, range.MinY, range.MaxY);
        
        property.vector2Value = new Vector2(x, y);

        EditorGUI.EndProperty();
    }
}