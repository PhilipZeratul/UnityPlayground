using UnityEngine;
using UnityEngine.UI;


public class ChangeImage : MonoBehaviour
{
    public Image background;
    public Sprite image_1024;
    public Sprite image_2048;


	public void OnToggleClick(bool isOn)
    {
        if (isOn)
            background.sprite = image_1024;
        else
            background.sprite = image_2048;
    }
}