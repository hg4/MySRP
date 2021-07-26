using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[System.Serializable]
public class CustomGradient 
{
    public enum BlendMode
    {
        Linear,
        Discrete
    };
    public BlendMode blendMode;

    [SerializeField]
    List<ColorKey> keys = new List<ColorKey>();
    public CustomGradient()
    {
        AddKey(Color.black, 0);
        AddKey(Color.white, 1);
    }
    public Color Evaluate(float precent)
    {
  
        ColorKey keyLeft = keys[0];
        ColorKey keyRight = keys[keys.Count - 1];
        for (int i = 0; i < keys.Count - 1; i++)
        {
            //if (keys[i].Precent <= precent && keys[i + 1].Precent >= precent)
            //{
            //    keyLeft = keys[i];
            //    keyRight = keys[i + 1];
            //    break;
            //}
            if (keys[i].Precent <= precent)
            {
                keyLeft = keys[i];
            }
            if (keys[i].Precent >= precent)
            {
                keyRight = keys[i];
                break;
            }
        }
        if (blendMode == BlendMode.Linear)
        {
            float blendPrecent = Mathf.InverseLerp(keyLeft.Precent, keyRight.Precent, precent);
            return Color.Lerp(keyLeft.Col, keyRight.Col, blendPrecent);
        }
        return keyRight.Col;
    }
    public int AddKey(Color color, float precent)
    {
        ColorKey newKey = new ColorKey(color, precent);
        for (int i = 0; i < keys.Count; i++)
        {
            if (newKey.Precent < keys[i].Precent)
            {
                keys.Insert(i, newKey);
                return i;
            }
        }
        keys.Add(newKey);
        return keys.Count - 1;
    }
    public void RemoveKey(int index)
    {
        if (keys.Count >= 2)
        {
            keys.RemoveAt(index);
        }
    }
    public int UpdateKeyPrecent(int index, float precent)
    {
        Color col = keys[index].Col;
        RemoveKey(index);
        return AddKey(col, precent);
    }
    public void UpdateKeyColor(int index, Color col)
    {
        keys[index] = new ColorKey(col, keys[index].Precent);
    }
    public int NumKeys
    {
        get
        {
            return keys.Count;
        }
    }

    public ColorKey GetKey(int i)
    {
        return keys[i];
    }

    public Texture2D GetTexture(int width)
    {
        Texture2D texture = new Texture2D(width, 1);
        Color[] colors = new Color[width];
        for (int i = 0; i < width; i++)
        {
            colors[i] = Evaluate((float)i / (width));
        }
        texture.SetPixels(colors);
        texture.Apply();
        return texture;
    }
    [System.Serializable]
    public struct ColorKey
    {
        [SerializeField]
        Color col;
        [SerializeField]
        float precent;

        public ColorKey(Color col, float precent)
        {
            this.col = col;
            this.precent = precent;
        }

        public Color Col
        {
            set
            {
                col = value;
            }
            get
            {
                return col;
            }
        }
        public float Precent
        {
            set
            {
                precent = value;
            }
            get
            {
                return precent;
            }

        }

    }

}
