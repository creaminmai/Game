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
        private Transform portraitActor, nurseActor;
        private MinjiPerformance portraitPerformance, nursePerformance;
        private readonly Vector3[] mapNodes = { new(3.4f, .4f, -.6f), new(.1f, .4f, .9f), new(-3.2f, .4f, -.25f) };
        private readonly Transform[] mapMarkers = new Transform[3];
        private Actor nurseWalk;
        private Vector3 nurseStation;
        private float nurseTime;
        private Light portraitKey, portraitFill;
        private bool portraitWasShowing;
        private static readonly Vector3 PortraitFocus = new(.248f, 1.41f, 0);
        private const float PortraitScale = .76f;

        internal RenderTexture PortraitTexture => portraitCamera == null ? null : portraitCamera.targetTexture;
        internal RenderTexture MapTexture => mapCamera == null ? null : mapCamera.targetTexture;
        internal int PortraitShapeCount => portraitPerformance?.ShapeRendererCount ?? 0;

        private void ConfigureNurse(Transform nurse, bool authored)
        {
            nurseActor = nurse;
            nurseStation = nurse.localPosition;
            if (authored) nursePerformance = new MinjiPerformance(nurse);
            nurseWalk = new Actor(nurse, nurse, null);
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
            // Keep camera samples linear until the screen composition pass.
            camera.targetTexture = new RenderTexture(width, height, 16, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear)
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
            var authored = LoadArt("minji-v2");
            var model = authored != null ? authored : LoadArt("nurse");
            if (model == null) return;
            portraitActor = PlacePerson(model, Camera.transform.parent, PortraitOrigin, false, false);
            portraitActor.localRotation = Quaternion.Euler(0, 9, 0);
            if (authored != null) portraitPerformance = new MinjiPerformance(portraitActor);
            SetLayer(portraitActor, PortraitLayer);
            portraitCamera = NewPresentationCamera("민지 3D 초상", PortraitLayer, PortraitOrigin + PortraitFocus + new Vector3(0, .12f, 4),
                PortraitOrigin + PortraitFocus, PortraitScale, 768, 896, Color.clear);
            portraitKey = PortraitLight("따뜻한 주광", new Vector3(.8f, 2.7f, 2.8f), new Color(1, .955f, .89f), 6.5f);
            portraitFill = PortraitLight("부드러운 보조광", new Vector3(-1.6f, 1.9f, 2.2f), new Color(.86f, .94f, 1), 2.25f);
        }

        private Light PortraitLight(string name, Vector3 relative, Color color, float intensity)
        {
            var light = Group(Camera.transform.parent, name, PortraitOrigin + relative).gameObject.AddComponent<Light>();
            light.type = LightType.Spot;
            light.range = 7;
            light.spotAngle = 46;
            light.color = color;
            light.intensity = intensity;
            light.cullingMask = 1 << PortraitLayer;
            light.transform.LookAt(PortraitOrigin + new Vector3(0, 1.52f, 0));
            return light;
        }

        internal void UpdatePresentation(bool dialogue, string pose, bool map, HospitalSite selected, bool operating)
        {
            if (operating && nurseActor != null)
            {
                nurseTime += Time.deltaTime;
                float step = Mathf.Clamp(nurseTime % 9f - 5f, 0, 2);
                nurseActor.localPosition = nurseStation + Vector3.left * (Mathf.PingPong(step, 1f) * .34f);
                nurseWalk.PoseWalk(nurseActor.position, step > 0 && step < 2f);
                nursePerformance?.Play("idle", Time.deltaTime);
            }
            if (dialogue && portraitCamera == null) BuildPortrait();
            if (portraitCamera != null)
            {
                portraitCamera.enabled = dialogue;
#if UNITY_EDITOR
                if (ProfileSkipPortraitCamera) portraitCamera.enabled = false;
#endif
                portraitKey.enabled = dialogue;
                portraitFill.enabled = dialogue;
                if (dialogue) portraitPerformance?.Play(pose, Time.unscaledDeltaTime);
                else if (portraitWasShowing) portraitPerformance?.EndScene();
                portraitWasShowing = dialogue;
            }
            if (map && mapCamera == null) BuildSpaceMap();
            if (mapCamera != null)
            {
                mapCamera.enabled = map;
                for (int i = 0; i < mapMarkers.Length; i++) mapMarkers[i].gameObject.SetActive(map && i == (int)selected);
            }
        }

#if UNITY_EDITOR
        internal bool ProfileSkipPortraitCamera { get; set; }
        private readonly System.Collections.Generic.Dictionary<Renderer, Material[]> portraitOriginalMaterials = new();
        private Transform faceStudyActor;

        internal bool PreviewFaceStudy(bool revised)
        {
            const string path = "Assets/Editor/HospitalArt/minji-v3-face-study.glb";
            if (portraitCamera == null) BuildPortrait();
            if (portraitCamera == null) return false;
            if (faceStudyActor == null)
            {
                var study = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(path);
                if (study == null) return false;
                faceStudyActor = PlacePerson(study, Camera.transform.parent, PortraitOrigin, false, false);
                faceStudyActor.localRotation = Quaternion.Euler(0, 12, 0);
                SetLayer(faceStudyActor, PortraitLayer);
            }
            portraitActor.gameObject.SetActive(!revised);
            faceStudyActor.gameObject.SetActive(revised);
            portraitActor.localRotation = faceStudyActor.localRotation;
            var target = PortraitOrigin + new Vector3(0, 1.56f, 0);
            portraitCamera.transform.position = target + new Vector3(0, .12f, 4);
            portraitCamera.transform.LookAt(target);
            portraitCamera.orthographicSize = .54f;
            return true;
        }

        internal void ResetFaceStudyPreview()
        {
            if (faceStudyActor == null) return;
            faceStudyActor.gameObject.SetActive(false);
            portraitActor.gameObject.SetActive(true);
            FramePortraitForReview(9f, false, false);
        }

        internal void FramePortraitForReview(float yaw, bool fullBody, bool neutral)
        {
            if (portraitCamera == null) BuildPortrait();
            if (portraitCamera == null) return;
            var view = fullBody ? new Vector3(0, 1.035f, 0) : PortraitFocus;
            portraitActor.localRotation = Quaternion.Euler(0, yaw, 0);
            portraitCamera.transform.position = PortraitOrigin + view + new Vector3(0, .12f, 4);
            portraitCamera.transform.LookAt(PortraitOrigin + view);
            portraitCamera.orthographicSize = fullBody ? 1.09f : PortraitScale;
            if (neutral)
            {
                var grey = MaterialFor(new Color(.56f, .56f, .56f));
                foreach (var renderer in portraitActor.GetComponentsInChildren<Renderer>())
                {
                    var assignments = renderer.sharedMaterials;
                    if (!portraitOriginalMaterials.TryAdd(renderer, assignments)) continue;
                    var neutralSlots = new Material[assignments.Length];
                    System.Array.Fill(neutralSlots, grey);
                    renderer.sharedMaterials = neutralSlots;
                }
            }
            else
            {
                foreach (var assignment in portraitOriginalMaterials)
                    assignment.Key.sharedMaterials = assignment.Value;
                portraitOriginalMaterials.Clear();
            }
        }
#endif

        internal Vector2 MapAnchor(HospitalSite site)
        {
            if (mapCamera == null) return new Vector2(.5f, .5f);
            var point = mapCamera.WorldToViewportPoint(MapOrigin + mapNodes[(int)site]);
            return new Vector2(point.x, 1f - point.y);
        }

        private void BuildSpaceMap()
        {
            var stage = Group(Camera.transform.parent, "공간형 지역 지도", MapOrigin);
            BuildMapLandscape(stage);
            for (int i = 0; i < 3; i++)
            {
                Transform campus = Group(stage, "병원 모형 " + i, mapNodes[i] - Vector3.up * .25f);
                float width = i == 0 ? 1.48f : i == 1 ? 1.10f : 1.26f;
                float height = i == 0 ? .80f : i == 1 ? .64f : .70f;
                Color roofColor = i == 0 ? new Color(.30f,.57f,.48f) : i == 1 ? new Color(.22f,.53f,.57f) : Coral;
                Box(campus, "크림 벽", new Vector3(0,height*.5f,0), new Vector3(width,height,.72f), Cream);
                Box(campus, "기단", new Vector3(0,.06f,.02f), new Vector3(width+.12f,.12f,.85f), Wood);
                for (int side = -1; side <= 1; side += 2)
                {
                    var roof = Shape(campus, "지붕 양면", PrimitiveType.Cube,
                        new Vector3(side * width * .24f,height + .095f,0), new Vector3(width*.56f,.12f,.86f), roofColor);
                    roof.transform.rotation = Quaternion.Euler(0,0,side * (i == 1 ? -18f : -12f));
                    for (int window = 0; window < (i == 0 ? 2 : 1); window++)
                    {
                        Vector3 at = new(side*(width*.34f),.32f+window*.23f,.37f);
                        Box(campus,"따뜻한 창틀",at,new Vector3(.249f,.17f,.04f),Wood);
                        Box(campus,"창 유리",at+Vector3.forward*.026f,new Vector3(.203f,.125f,.024f),new Color(.86f,.74f,.50f));
                    }
                }
                Box(campus, "입구 문", new Vector3(0,.22f,.382f), new Vector3(.255f,.40f,.055f), Mint);
                Box(campus, "입구 처마", new Vector3(0,.45f,.49f), new Vector3(.50f,.095f,.30f), roofColor);
                if (i == 2)
                {
                    Shape(campus,"작은 등대",PrimitiveType.Cylinder,new Vector3(-.84f,.32f,-.12f),new Vector3(.16f,.32f,.16f),Cream);
                    Shape(campus,"등대 머리",PrimitiveType.Cylinder,new Vector3(-.84f,.65f,-.12f),new Vector3(.23f,.054f,.23f),Coral);
                }
                var marker = Group(campus, "선택 테두리", new Vector3(0,.028f,0));
                for (int segment=0; segment<18; segment++)
                {
                    float a = segment * Mathf.PI * 2 / 18f;
                    Shape(marker,"골드 링",PrimitiveType.Sphere,new Vector3(Mathf.Cos(a)*.93f,0,Mathf.Sin(a)*.64f),
                        new Vector3(.18f,.039f,.14f), new Color(.99f,.74f,.28f));
                }
                mapMarkers[i] = marker;
            }
            SetLayer(stage, MapLayer);
            mapCamera = NewPresentationCamera("지역 지도 3D 카메라", MapLayer, MapOrigin + new Vector3(1, 9.3f, 7.5f),
                MapOrigin, 3.78f, 640, 368, new Color(.59f, .79f, .78f));
        }

        internal void ReleasePresentation()
        {
            foreach (Mesh surface in mapSurfaces) Object.Destroy(surface);
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
