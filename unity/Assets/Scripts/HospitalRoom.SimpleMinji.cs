#if UNITY_EDITOR
using System.Linq;
using UnityEditor;
using UnityEngine;

namespace SunshineHospital
{
    internal sealed partial class HospitalRoom
    {
        private GameObject simplePortrait, simpleOperation;
        private Transform[] simpleFaces;
        private Animation simpleMotion;
        private Vector3 originalFillPosition;
        private Quaternion originalFillRotation;
        private Color originalFillColor, originalKeyColor;
        private float originalFillIntensity, originalFillAngle, originalKeyIntensity;
        private bool volumeReview;
        internal bool VolumeOperationClose { get; set; }
        private CameraPose volumeCameraPose;
        private Color volumeAmbient;
        private (Light light, int mask)[] volumeLightMasks;
        private Transform[] volumeWalkJoints;
        private Quaternion[] volumeRestAngles;
        private Vector3 volumeStation;
        private float volumeNurseTime;

        private readonly struct CameraPose
        {
            private readonly Vector3 position;
            private readonly Quaternion rotation;
            private readonly float size;

            internal CameraPose(Camera camera)
            {
                position = camera.transform.position;
                rotation = camera.transform.rotation;
                size = camera.orthographicSize;
            }

            internal void Restore(Camera camera)
            {
                camera.transform.SetPositionAndRotation(position, rotation);
                camera.orthographicSize = size;
            }
        }

        internal bool BeginSimpleMinjiReview(bool volume = false)
        {
            string path = volume
                ? "Assets/Editor/HospitalArt/MinjiVolumeReview.prefab"
                : "Assets/Editor/HospitalArt/MinjiSimpleReview.prefab";
            var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(path);
            if (prefab == null || nurseActor == null || nurseActor.childCount == 0) return false;
            if (portraitCamera == null) BuildPortrait();
            if (portraitCamera == null) return false;

            simplePortrait = PlacePerson(prefab, Camera.transform.parent, PortraitOrigin, false, false).gameObject;
            simplePortrait.SetActive(false);
            SetLayer(simplePortrait.transform, PortraitLayer);
            var rig = simplePortrait.GetComponentsInChildren<Transform>(true);
            simpleFaces = new[] { "FaceSmile", "FaceJoy", "FaceExplain" }
                .Select(name => rig.SingleOrDefault(part => part.name == name)).ToArray();
            simpleMotion = simplePortrait.GetComponentInChildren<Animation>(true);
            if (simpleMotion == null || simpleMotion.clip == null || simpleFaces.Any(part => part == null))
            {
                EndSimpleMinjiReview();
                return false;
            }

            simpleOperation = PlacePerson(prefab, nurseActor, Vector3.zero, false, false).gameObject;
            simpleOperation.transform.localScale = Vector3.one * .97f;
            nurseActor.GetChild(0).gameObject.SetActive(false);
            portraitActor.gameObject.SetActive(false);
            originalFillPosition = portraitFill.transform.position;
            originalFillRotation = portraitFill.transform.rotation;
            originalFillColor = portraitFill.color;
            originalKeyColor = portraitKey.color;
            originalFillIntensity = portraitFill.intensity;
            originalFillAngle = portraitFill.spotAngle;
            originalKeyIntensity = portraitKey.intensity;
            LightSimpleMinji();
            if (volume) BeginVolumeReview();
            simplePortrait.SetActive(true);
            return true;
        }

        private void BeginVolumeReview()
        {
            volumeReview = true;
            volumeCameraPose = new CameraPose(Camera);
            volumeStation = nurseActor.localPosition;
            volumeNurseTime = nurseTime;
            volumeAmbient = RenderSettings.ambientLight;
            volumeLightMasks = root.GetComponentsInChildren<Light>()
                .Where(light => light.type == LightType.Directional)
                .Select(light => (light, light.cullingMask)).ToArray();
            foreach (var (light, mask) in volumeLightMasks)
                light.cullingMask = mask & ~(1 << PortraitLayer);

            var parts = simpleOperation.GetComponentsInChildren<Transform>(true);
            volumeWalkJoints = new[] { "LegL", "LegR", "ShoulderL", "ShoulderR" }
                .Select(name => parts.First(part => part.name == name)).ToArray();
            volumeRestAngles = volumeWalkJoints.Select(part => part.localRotation).ToArray();
            var head = parts.First(part => part.name == "Round head").GetComponent<Renderer>();
            var skin = head.sharedMaterial;
            bool unifiedSkin = parts.Where(part => part.name.StartsWith("Mitten palm"))
                .All(part => part.GetComponent<Renderer>().sharedMaterial == skin);
            Debug.Log($"[Hospital QA] Minji skin {skin.GetColor("baseColorFactor")}, shader {skin.shader.name}, " +
                $"same head and mitten material {unifiedSkin}, color space {QualitySettings.activeColorSpace}, portrait sRGB {PortraitTexture.sRGB}.");
        }

        internal void LightVolumeReview(bool neutral)
        {
            RenderSettings.ambientLight = neutral ? new Color(.55f, .55f, .55f) : volumeAmbient;
            portraitKey.color = neutral ? Color.white : new Color(1f, .988f, .984f);
            portraitFill.color = Color.white;
            portraitKey.intensity = 4.7f;
            portraitFill.intensity = 4.35f;
        }

        internal void FrameVolumeOperation()
        {
            Vector3 focus = nurseActor.parent.TransformPoint(nurseStation) + new Vector3(-.14f, 1.0f, 0);
            Camera.transform.position = focus - Camera.transform.forward * 23;
            Camera.orthographicSize = 2.55f;
        }

        internal void BeginVolumeWalk() => nurseTime = 5;

        internal void PoseVolumeWalk()
        {
            float step = Mathf.Clamp(nurseTime % 9 - 5, 0, 2);
            float swing = Mathf.Sin(step * Mathf.PI / 2) * Mathf.Sin(step * Mathf.PI * 3.2f);
            for (int i = 0; i < volumeWalkJoints.Length; i++)
            {
                float degrees = swing * (i < 2 ? 21f : -14f) * (i % 2 == 0 ? 1 : -1);
                volumeWalkJoints[i].localRotation = volumeRestAngles[i] * Quaternion.Euler(degrees, 0, 0);
            }
        }

        internal void LightSimpleMinji(bool previousFill = false)
        {
            var fillPosition = previousFill ? new Vector3(-1.35f, 1.05f, 2.45f) : new Vector3(-.95f, .62f, 2.37f);
            var target = new Vector3(0, previousFill ? 1.23f : 1.11f, 0);
            portraitFill.transform.position = PortraitOrigin + fillPosition;
            portraitFill.transform.LookAt(PortraitOrigin + target);
            portraitFill.color = previousFill ? originalFillColor : new Color(1f, .971f, .933f);
            portraitFill.spotAngle = previousFill ? 64f : 72f;
            portraitFill.intensity = previousFill ? 4.3f : 5.1f;
            portraitKey.intensity = 5.2f;
        }

        internal void FrameSimpleMinji(float yaw, bool fullBody)
        {
            var focus = PortraitOrigin + (fullBody ? new Vector3(0, 1.035f, 0) : new Vector3(-.150f, 1.36f, 0));
            simplePortrait.transform.localRotation = Quaternion.Euler(0, yaw, 0);
            float lift = volumeReview && fullBody ? 0 : .105f;
            portraitCamera.transform.position = focus + new Vector3(0, lift, 4);
            portraitCamera.transform.LookAt(focus);
            portraitCamera.orthographicSize = fullBody ? 1.14f : .855f;
        }

        internal void RotateSimpleMinji(float yaw) =>
            simplePortrait.transform.localRotation = Quaternion.Euler(0, yaw, 0);

        internal void PoseSimpleMinji(int face, float seconds)
        {
            for (int i = 0; i < simpleFaces.Length; i++)
                simpleFaces[i].gameObject.SetActive(i == face);
            var clip = simpleMotion.clip;
            clip.SampleAnimation(simpleMotion.gameObject, Mathf.Clamp(seconds, 0, clip.length));
        }

        internal void EndSimpleMinjiReview()
        {
            if (simpleOperation != null)
            {
                simpleOperation.SetActive(false);
                Object.Destroy(simpleOperation);
                nurseActor.GetChild(0).gameObject.SetActive(true);
                portraitFill.transform.SetPositionAndRotation(originalFillPosition, originalFillRotation);
                portraitFill.color = originalFillColor;
                portraitKey.color = originalKeyColor;
                portraitFill.intensity = originalFillIntensity;
                portraitFill.spotAngle = originalFillAngle;
                portraitKey.intensity = originalKeyIntensity;
            }
            if (volumeReview)
            {
                VolumeOperationClose = false;
                volumeCameraPose.Restore(Camera);
                RenderSettings.ambientLight = volumeAmbient;
                foreach (var (light, mask) in volumeLightMasks)
                    light.cullingMask = mask;
                nurseActor.localPosition = volumeStation;
                nurseTime = volumeNurseTime;
                volumeReview = false;
            }
            if (simplePortrait != null)
            {
                simplePortrait.SetActive(false);
                Object.Destroy(simplePortrait);
                portraitActor.gameObject.SetActive(true);
                FramePortraitForReview(9f, false, false);
            }
            simplePortrait = simpleOperation = null;
            simpleMotion = null;
            simpleFaces = null;
        }
    }
}
#endif
