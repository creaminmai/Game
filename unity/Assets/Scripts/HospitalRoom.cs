using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace SunshineHospital
{
    internal sealed class HospitalRoom
    {
        private readonly Dictionary<Color, Material> materials = new();
        private readonly Shader shader = Shader.Find("Universal Render Pipeline/Lit");

        private static readonly Color Cream = new(1f, .94f, .82f);
        private static readonly Color Mint = new(.54f, .79f, .69f);
        private static readonly Color Coral = new(.93f, .57f, .49f);
        private static readonly Color Wood = new(.76f, .54f, .32f);
        private static readonly Color Ink = new(.27f, .31f, .29f);
        private static readonly Color White = new(.98f, .97f, .93f);

        public Camera Camera { get; }
        public Transform Patient { get; }
        public Transform PatientBody { get; }
        public Transform Selection { get; }
        public Renderer CtLamp { get; }
        public Renderer TreatmentLamp { get; }

        public HospitalRoom(Transform root)
        {
            RenderSettings.ambientMode = AmbientMode.Flat;
            RenderSettings.ambientLight = new Color(.71f, .69f, .64f);
            Camera = Group(root, "고정 카메라", new Vector3(11, 18, 20)).gameObject.AddComponent<Camera>();
            Camera.transform.LookAt(new Vector3(0, 0, .1f));
            Camera.orthographic = true;
            Camera.orthographicSize = 8.6f;
            Camera.clearFlags = CameraClearFlags.SolidColor;
            Camera.backgroundColor = new Color(.86f, .91f, .86f);

            var light = Group(root, "햇빛", Vector3.zero).gameObject.AddComponent<Light>();
            light.type = LightType.Directional;
            light.color = new Color(1f, .91f, .78f);
            light.intensity = 1.65f;
            light.shadows = LightShadows.Soft;
            light.transform.rotation = Quaternion.Euler(49, -38, 0);

            Box(root, "건물 바닥", new Vector3(0, -.25f, 0), new Vector3(14, .5f, 12), Wood);
            Box(root, "중앙 복도", new Vector3(0, .02f, 0), new Vector3(13.8f, .06f, 11.8f), Cream);
            Floor(root, "접수", -3.8f, 2.9f, new Color(.94f, .77f, .58f));
            Floor(root, "CT", -3.8f, -3, Mint);
            Floor(root, "계획", 3.8f, -3, new Color(.83f, .85f, .72f));
            Floor(root, "치료", 3.8f, 2.9f, new Color(.96f, .82f, .75f));
            Box(root, "북쪽 벽", new Vector3(0, .8f, -5.9f), new Vector3(14, 1.6f, .23f), Cream);
            Box(root, "서쪽 벽", new Vector3(-6.9f, .8f, 0), new Vector3(.23f, 1.6f, 12), Cream);

            Box(root, "접수대", new Vector3(-4.4f, .55f, 3.65f), new Vector3(2.7f, 1f, .75f), Wood);
            Box(root, "접수대 상판", new Vector3(-4.4f, 1.08f, 3.65f), new Vector3(2.82f, .15f, .88f), White);
            Station(root, -4.4f, 3.65f, 1.17f);
            Person(root, "민지", new Vector3(-4.65f, 0, 4.53f), Mint);
            for (int i = 0; i < 3; i++)
            {
                float z = .9f + i * .7f;
                Shape(root, "대기 의자", PrimitiveType.Sphere, new Vector3(-5.9f, .5f, z), new Vector3(.9f, .55f, .65f), Coral);
            }
            Box(root, "계획 작업대", new Vector3(4.1f, .52f, -3.15f), new Vector3(2.4f, .96f, .7f), Wood);
            Station(root, 4.1f, -3.15f, 1f);
            Plant(root, -6, -4.8f);
            Plant(root, 6.2f, -4.8f);
            Plant(root, 6.2f, 4.95f);

            for (int i = 0; i < 24; i++)
            {
                float angle = i * 2 * Mathf.PI / 24;
                var point = new Vector3(-4.25f + .96f * Mathf.Cos(angle), 1.26f + .96f * Mathf.Sin(angle), -3.65f);
                Shape(root, "CT 링", PrimitiveType.Sphere, point, new Vector3(.53f, .53f, .72f), White);
            }
            Couch(root, "CT 침대", -4.25f, -2.5f, Mint);
            CtLamp = Lamp(root, new Vector3(-4.25f, 2.22f, -3.23f));

            Box(root, "치료기 기둥", new Vector3(5.3f, 1.1f, 2.6f), new Vector3(.67f, 2.1f, .87f), White);
            Shape(root, "치료기 곡선 암", PrimitiveType.Capsule, new Vector3(4.74f, 2.14f, 2.6f),
                new Vector3(.65f, .83f, .65f), White).transform.rotation = Quaternion.Euler(0, 0, 90);
            Shape(root, "치료기 헤드", PrimitiveType.Cylinder, new Vector3(4.08f, 1.96f, 2.6f),
                new Vector3(.95f, .27f, .95f), Coral);
            Couch(root, "치료 침대", 4.08f, 2.6f, Coral);
            TreatmentLamp = Lamp(root, new Vector3(5.3f, 1.75f, 3.08f));

            Patient = Group(root, "김영수", new Vector3(0, 0, 6.6f));
            Selection = Shape(Patient, "선택 표시", PrimitiveType.Cylinder, new Vector3(0, .05f, 0),
                new Vector3(1.06f, .02f, 1.06f), Mint).transform;
            PatientBody = Person(Patient, "환자 캐릭터", Vector3.zero, Coral);
        }

        public void SetLamp(Renderer lamp, bool active) => lamp.sharedMaterial = MaterialFor(active ? Mint : Ink);

        private void Floor(Transform root, string name, float x, float z, Color color) =>
            Box(root, name, new Vector3(x, .063f, z), new Vector3(5.9f, .03f, 4.9f), color);

        private void Station(Transform root, float x, float z, float y) =>
            Box(root, "모니터", new Vector3(x, y + .26f, z), new Vector3(.63f, .44f, .1f), Ink);

        private void Couch(Transform root, string name, float x, float z, Color color)
        {
            Box(root, name + " 받침", new Vector3(x, .32f, z), new Vector3(.62f, .54f, 1.25f), White);
            Shape(root, name, PrimitiveType.Capsule, new Vector3(x, .65f, z),
                new Vector3(.69f, 1.04f, .26f), color).transform.rotation = Quaternion.Euler(90, 0, 0);
        }

        private Renderer Lamp(Transform root, Vector3 position) =>
            Shape(root, "시설 사용등", PrimitiveType.Sphere, position, Vector3.one * .2f, Ink).GetComponent<Renderer>();

        private Transform Person(Transform parent, string name, Vector3 position, Color clothes)
        {
            var person = Group(parent, name, position);
            Color skin = new(.96f, .76f, .58f);
            Shape(person, "몸", PrimitiveType.Capsule, new Vector3(0, .59f, 0), new Vector3(.64f, .46f, .52f), clothes);
            Shape(person, "머리", PrimitiveType.Sphere, new Vector3(0, 1.21f, 0), new Vector3(.72f, .71f, .69f), skin);
            Shape(person, "머리카락", PrimitiveType.Sphere, new Vector3(0, 1.43f, -.06f), new Vector3(.74f, .43f, .68f), Wood);
            for (int side = -1; side <= 1; side += 2)
            {
                Shape(person, "눈", PrimitiveType.Sphere, new Vector3(side * .13f, 1.25f, .31f), Vector3.one * .075f, Ink);
                Shape(person, "발", PrimitiveType.Sphere, new Vector3(side * .18f, .18f, .06f), new Vector3(.28f, .24f, .36f), Ink);
            }
            return person;
        }

        private void Plant(Transform root, float x, float z)
        {
            Shape(root, "화분", PrimitiveType.Cylinder, new Vector3(x, .27f, z), new Vector3(.52f, .23f, .52f), Coral);
            Shape(root, "잎", PrimitiveType.Sphere, new Vector3(x, .83f, z), new Vector3(.76f, .85f, .69f), Mint);
        }

        private static Transform Group(Transform parent, string name, Vector3 position)
        {
            Transform item = new GameObject(name).transform;
            item.SetParent(parent, false);
            item.localPosition = position;
            return item;
        }

        private void Box(Transform root, string name, Vector3 at, Vector3 size, Color color) =>
            Shape(root, name, PrimitiveType.Cube, at, size, color);

        private GameObject Shape(Transform parent, string name, PrimitiveType type, Vector3 at, Vector3 size, Color color)
        {
            var item = GameObject.CreatePrimitive(type);
            item.name = name;
            item.transform.SetParent(parent, false);
            item.transform.localPosition = at;
            item.transform.localScale = size;
            item.GetComponent<Renderer>().sharedMaterial = MaterialFor(color);
            // Selection uses a dedicated patient collider. Room meshes need no physics.
            Object.Destroy(item.GetComponent<Collider>());
            return item;
        }

        private Material MaterialFor(Color color)
        {
            if (materials.TryGetValue(color, out Material material)) return material;
            material = new Material(shader) { color = color };
            material.SetFloat("_Smoothness", .28f);
            materials.Add(color, material);
            return material;
        }
    }
}
