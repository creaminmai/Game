using UnityEngine;

namespace SunshineHospital
{
    internal sealed partial class HospitalRoom
    {
        private readonly Transform[] ornaments = new Transform[8];
        private int lastDecorationMask;

        internal void ApplyDecorations(int mask)
        {
            if (lastDecorationMask == mask) return;
            lastDecorationMask = mask;
            for (int i = 0; i < ornaments.Length; i++)
            {
                bool enabled = (mask & (1 << i)) != 0;
                if (enabled && ornaments[i] == null) ornaments[i] = BuildDecoration(i);
                if (ornaments[i] != null) ornaments[i].gameObject.SetActive(enabled);
            }
        }

        private Transform BuildDecoration(int item)
        {
            var result = Group(root, AlphaCatalog.Decorations[item].Name, Vector3.zero);
            Color color = item % 2 == 0 ? Mint : Coral;
            switch (AlphaCatalog.Decorations[item].Slot)
            {
                case 0:
                    Shape(result, "유약 화분", PrimitiveType.Cylinder, new Vector3(5.83f, .29f, 5.34f), new Vector3(.61f, .29f, .61f), color);
                    for (int leaf = -1; leaf <= 1; leaf++)
                        Shape(result, "잎", PrimitiveType.Sphere, new Vector3(5.83f + leaf * .19f, .93f - Mathf.Abs(leaf) * .16f, 5.34f),
                            new Vector3(.26f, .75f, .28f), Mint);
                    break;
                case 1:
                    Box(result, "원목 액자", new Vector3(3.9f, 1.96f, -5.91f), new Vector3(1.2f, .82f, .13f), Wood);
                    Box(result, "종이", new Vector3(3.9f, 1.96f, -5.81f), new Vector3(1.03f, .65f, .07f), Cream);
                    Shape(result, "그림", PrimitiveType.Sphere, new Vector3(3.92f, 2.02f, -5.75f), new Vector3(.43f, .42f, .05f), color);
                    break;
                case 2:
                    Box(result, "조경 옆 대기석 받침", new Vector3(5.59f, .24f, 6.6f), new Vector3(1.56f, .43f, .65f), Wood);
                    Shape(result, "둥근 대기석", PrimitiveType.Sphere, new Vector3(5.59f, .53f, 6.6f), new Vector3(1.72f, .35f, .8f), item == 4 ? Mint : Wood);
                    break;
                default:
                    Shape(result, "직조 러그", PrimitiveType.Cylinder, new Vector3(-.35f, .021f, 6.38f), new Vector3(1.53f, .025f, .76f), item == 6 ? Cream : Coral);
                    break;
            }
            return result;
        }
    }
}
