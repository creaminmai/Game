using UnityEngine;

namespace SunshineHospital
{
    internal sealed partial class HospitalRoom
    {
        private const int PortraitLayer = 30;
        private const int MapLayer = 29;
        private static readonly Vector3 PortraitOrigin = new(0, -60, 0);
        private static readonly Vector3 MapOrigin = new(0, -90, 0);
        private Camera portraitCamera, mapCamera;
        private Transform portraitActor, nurseActor, portraitHead, portraitArm;
        private Quaternion headRest, armRest;
        private readonly Vector3[] mapNodes = { new(3.4f, .4f, -.6f), new(.1f, .4f, .9f), new(-3.2f, .4f, -.25f) };
        private readonly Transform[] mapMarkers = new Transform[3];
        private Quaternion nurseRest;
        private Transform nurseLids, portraitLids;
        private Actor nurseWalk;
        private Vector3 nurseStation;
        private Mesh minjiSphere;
        private float nurseTime;
        private Transform nurseHead;
        private string activePose;
        private float poseStarted;

        internal RenderTexture PortraitTexture => portraitCamera == null ? null : portraitCamera.targetTexture;
        internal RenderTexture MapTexture => mapCamera == null ? null : mapCamera.targetTexture;

        private void ConfigureNurse(Transform nurse)
        {
            nurseActor = nurse;
            nurseHead = FindPart(nurse, "Head");
            if (nurseHead != null) nurseRest = nurseHead.localRotation;
            nurseLids = AddMinjiDetails(nurse);
            nurseStation = nurse.localPosition;
            nurseWalk = new Actor(nurse, nurse, null);
        }

        private static Transform FindPart(Transform root, string name)
        {
            foreach (Transform part in root.GetComponentsInChildren<Transform>(true))
                if (part.name == name) return part;
            return null;
        }

        private Transform AddMinjiDetails(Transform actor)
        {
            Transform lids = null;
            var skin = new Color(.965f, .81f, .71f);

            var head = FindPart(actor, "Head");
            if (head != null)
            {
                lids = Group(head, "눈깜빡임 눈꺼풀", Vector3.zero);

                for (int side = -1; side <= 1; side += 2)
                {
                    MinjiDetail(lids, "닫힌 눈꺼풀", new Vector3(side * .126f, .068f, .282f),
                        new Vector3(.134f, .146f, .046f), skin);
                    MinjiDetail(lids, "닫힌 눈선", new Vector3(side * .126f, .068f, .307f),
                        new Vector3(.09f, .009f, .012f), new Color(.31f, .17f, .12f));
                    var lockShape = MinjiDetail(head, "앞머리 결",
                        new Vector3(side * .145f, .254f, .185f), new Vector3(.33f, .21f, .105f),
                        new Color(.48f, .32f, .24f));
                    lockShape.transform.localRotation = Quaternion.Euler(-9f, side * 30f, side * -24f);
                }
            }
            lids?.gameObject.SetActive(false);
            foreach (string armName in new[] { "Arm_L", "Arm_R" })
            {
                var arm = FindPart(actor, armName);
                if (arm == null) continue;
                float side = armName == "Arm_L" ? 1f : -1f;
                for (int finger = 0; finger < 4; finger++)
                    MinjiDetail(arm, "둥근 손가락",
                        new Vector3(side * .068f + (finger - 1.5f) * .024f, -.603f - .008f * (finger is 1 or 2 ? 1 : 0), .064f),
                        new Vector3(.026f, .065f, .039f), skin);
            }
            var sunflower = Group(actor, "입체 해바라기 배지", new Vector3(.157f, 1.075f, .216f));
            for (int i = 0; i < 8; i++)
            {
                float turn = i * Mathf.PI / 4f;
                MinjiDetail(sunflower, "꽃잎", new Vector3(Mathf.Cos(turn) * .033f, Mathf.Sin(turn) * .033f, 0),
                    new Vector3(.030f, .030f, .013f), new Color(.98f, .72f, .23f));
            }
            MinjiDetail(sunflower, "꽃 중심", new Vector3(0, 0, .013f), new Vector3(.036f, .036f, .017f), Wood);
            for (int i = 0; i < 3; i++)
                MinjiDetail(actor, "진주 단추", new Vector3(0, .99f - .091f * i, .202f),
                    new Vector3(.027f, .027f, .018f), White);
            return lids;
        }

        private GameObject MinjiDetail(Transform parent, string name, Vector3 position, Vector3 scale, Color color)
        {
            if (minjiSphere == null)
            {
                const int segments = 12, rings = 6;
                var vertices = new Vector3[(rings + 1) * segments];
                var normals = new Vector3[vertices.Length];
                var indices = new int[rings * segments * 6];
                int output = 0;
                for (int ring = 0; ring <= rings; ring++)
                    for (int segment = 0; segment < segments; segment++)
                    {
                        float phi = ring * Mathf.PI / rings, theta = segment * Mathf.PI * 2f / segments;
                        int slot = ring * segments + segment;
                        var normal = new Vector3(Mathf.Sin(phi) * Mathf.Cos(theta), Mathf.Cos(phi), Mathf.Sin(phi) * Mathf.Sin(theta));
                        vertices[slot] = normal * .5f;
                        normals[slot] = normal;
                        if (ring == rings) continue;
                        int next = ring * segments + (segment + 1) % segments;
                        indices[output++] = slot;
                        indices[output++] = next;
                        indices[output++] = slot + segments;
                        indices[output++] = next;
                        indices[output++] = next + segments;
                        indices[output++] = slot + segments;
                    }
                minjiSphere = new Mesh { name = "민지 디테일 144 삼각형" };
                minjiSphere.vertices = vertices;
                minjiSphere.normals = normals;
                minjiSphere.triangles = indices;
            }
            var item = Shape(parent, name, PrimitiveType.Sphere, position, scale, color);
            item.GetComponent<MeshFilter>().sharedMesh = minjiSphere;
            return item;
        }

        private Camera NewPresentationCamera(string title, int layer, Vector3 position, Vector3 focus, float scale, int width, int height, Color clear)
        {
            Camera.cullingMask &= ~(1 << layer);
            var camera = Group(Camera.transform.parent, title, position).gameObject.AddComponent<Camera>();
            camera.transform.LookAt(focus);
            camera.cullingMask = 1 << layer;
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = clear;
            camera.orthographic = true;
            camera.orthographicSize = scale;
            camera.allowHDR = false;
            camera.allowMSAA = false;
            camera.targetTexture = new RenderTexture(width, height, 16, RenderTextureFormat.ARGB32)
            {
                name = title,
                filterMode = FilterMode.Bilinear
            };
            return camera;
        }

        private static void SetLayer(Transform root, int layer)
        {
            foreach (Transform item in root.GetComponentsInChildren<Transform>(true))
                item.gameObject.layer = layer;
        }

        private void BuildPortrait()
        {
            var model = LoadArt("nurse");
            if (model == null) return;
            portraitActor = PlacePerson(model, Camera.transform.parent, PortraitOrigin, false, false);
            portraitActor.localRotation = Quaternion.Euler(0, 9, 0);
            portraitLids = AddMinjiDetails(portraitActor);
            SetLayer(portraitActor, PortraitLayer);
            portraitHead = FindPart(portraitActor, "Head");
            portraitArm = FindPart(portraitActor, "Arm_L");
            if (portraitHead != null) headRest = portraitHead.localRotation;
            if (portraitArm != null) armRest = portraitArm.localRotation;
            portraitCamera = NewPresentationCamera("민지 3D 초상", PortraitLayer, PortraitOrigin + new Vector3(0, 1.39f, 4),
                PortraitOrigin + new Vector3(0, 1.23f, 0), .82f, 448, 512, Color.clear);
        }

        internal void UpdatePresentation(bool dialogue, string pose, bool map, HospitalSite selected, bool operating)
        {
            float now = Time.unscaledTime;
            if (operating && nurseActor != null)
            {
                nurseTime += Time.deltaTime;
                float step = Mathf.Clamp(nurseTime % 9f - 5f, 0, 2);
                nurseActor.localPosition = nurseStation + Vector3.left * (Mathf.PingPong(step, 1f) * .34f);
                nurseWalk.PoseWalk(nurseActor.position, step > 0 && step < 2f);
                if (nurseHead != null)
                    nurseHead.localRotation = nurseRest * Quaternion.Euler(Mathf.Sin(now * 1.6f) * 2f, Mathf.Sin(now * .8f) * 5f, 0);
            }
            if (nurseLids != null) nurseLids.gameObject.SetActive(operating && now % 4.7f > 4.55f);
            if (dialogue && portraitCamera == null) BuildPortrait();
            if (portraitCamera != null)
            {
                portraitCamera.enabled = dialogue;
                if (dialogue)
                {
                    if (activePose != pose) { activePose = pose; poseStarted = now; }
                    float elapsed = now - poseStarted;
                    if (portraitLids != null) portraitLids.gameObject.SetActive(elapsed % 3.7f > 3.55f);
                    float turn = pose switch { "greeting" => -12f, "joyful" => -6f, "worried" => 12f, _ => 8f };
                    if (portraitHead != null)
                        portraitHead.localRotation = headRest * Quaternion.Euler((pose == "worried" ? 9f : 0f) + 2f * Mathf.Sin(elapsed * 3f), 3f, turn);
                    if (portraitArm != null)
                    {
                        float lift = pose == "greeting" ? 128f + 12f * Mathf.Sin(elapsed * 8f) : pose == "joyful" ? 68f : pose == "worried" ? 23f : 47f;
                        portraitArm.localRotation = armRest * Quaternion.Euler(-18f, 0, lift);
                    }
                }
                else activePose = null;
            }
            if (map && mapCamera == null) BuildSpaceMap();
            if (mapCamera != null)
            {
                mapCamera.enabled = map;
                for (int i = 0; i < mapMarkers.Length; i++) mapMarkers[i].gameObject.SetActive(map && i == (int)selected);
            }
        }

        internal Vector2 MapAnchor(HospitalSite site)
        {
            if (mapCamera == null) return new Vector2(.5f, .5f);
            var point = mapCamera.WorldToViewportPoint(MapOrigin + mapNodes[(int)site]);
            return new Vector2(point.x, 1f - point.y);
        }

        private void BuildSpaceMap()
        {
            var stage = Group(Camera.transform.parent, "공간형 지역 지도", MapOrigin);
            Box(stage, "바다", new Vector3(0, -.30f, 0), new Vector3(11, .35f, 6), new Color(.32f, .66f, .74f));
            var meadow = new Color(.65f, .76f, .43f);
            for (int i = 0; i < 3; i++)
            {
                var at = mapNodes[i];
                var land = new Vector3(at.x, -.1f, at.z);
                Shape(stage, "지역 지형", PrimitiveType.Cylinder, land, new Vector3(3.1f, .24f, 3f),
                    i == 2 ? new Color(.84f, .69f, .45f) : meadow);
                Box(stage, "병원 크림 벽", at + new Vector3(0, .10f, 0), new Vector3(1.1f, .88f, .68f), Cream);
                var roof = Shape(stage, "병원별 지붕", i == 2 ? PrimitiveType.Sphere : PrimitiveType.Cube,
                    at + Vector3.up * .59f, new Vector3(1.25f, .24f, .8f),
                    i == 0 ? Mint : i == 1 ? new Color(.28f, .57f, .65f) : Coral);
                roof.transform.rotation = Quaternion.Euler(0, 9f * i, 0);
                Box(stage, "입구", at + new Vector3(0, -.03f, .35f), new Vector3(.22f, .43f, .06f), Wood);
                for (int j = -1; j <= 1; j += 2)
                {
                    Box(stage, "창틀", at + new Vector3(j * .32f, .18f, .36f), new Vector3(.2f, .24f, .055f), White);
                    Shape(stage, "나무", PrimitiveType.Sphere, land + new Vector3(j * 1.05f, .73f, -.52f),
                        new Vector3(.58f, .68f, .51f), i == 2 ? Mint : new Color(.41f, .63f, .38f));
                }
                mapMarkers[i] = Shape(stage, "선택 병원", PrimitiveType.Cylinder, land + Vector3.up * .27f,
                    new Vector3(1.68f, .026f, 1.32f), new Color(.98f, .70f, .30f)).transform;
                if (i == 0) continue;
                Vector3 a = mapNodes[i - 1] + new Vector3(0, -.25f, 0);
                Vector3 b = at + new Vector3(0, -.25f, 0);
                var walk = Shape(stage, "연결 통행로", PrimitiveType.Cube, (a + b) / 2,
                    new Vector3(.28f, .10f, Vector3.Distance(a, b)), Wood);
                walk.transform.rotation = Quaternion.LookRotation(b - a);
            }
            SetLayer(stage, MapLayer);
            mapCamera = NewPresentationCamera("지역 지도 3D 카메라", MapLayer, MapOrigin + new Vector3(1, 8, 8),
                MapOrigin, 3.55f, 640, 368, new Color(.59f, .79f, .78f));
        }

        internal void ReleasePresentation()
        {
            if (minjiSphere != null) Object.Destroy(minjiSphere);
            foreach (var view in new[] { portraitCamera, mapCamera })
                if (view != null && view.targetTexture != null)
                {
                    var texture = view.targetTexture;
                    view.targetTexture = null;
                    texture.Release();
                    Object.Destroy(texture);
                }
        }
    }
}
