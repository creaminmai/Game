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
        private float originalFillIntensity, originalFillAngle, originalKeyIntensity;

        internal bool BeginSimpleMinjiReview()
        {
            const string path = "Assets/Editor/HospitalArt/MinjiSimpleReview.prefab";
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
            originalFillIntensity = portraitFill.intensity;
            originalFillAngle = portraitFill.spotAngle;
            originalKeyIntensity = portraitKey.intensity;
            portraitFill.transform.position = PortraitOrigin + new Vector3(-1.35f, 1.05f, 2.45f);
            portraitFill.transform.LookAt(PortraitOrigin + new Vector3(0, 1.23f, 0));
            portraitFill.spotAngle = 64f;
            portraitFill.intensity = 4.3f;
            portraitKey.intensity = 5.2f;
            simplePortrait.SetActive(true);
            return true;
        }

        internal void FrameSimpleMinji(float yaw, bool fullBody)
        {
            var focus = PortraitOrigin + (fullBody ? new Vector3(0, 1.035f, 0) : new Vector3(-.125f, 1.36f, 0));
            simplePortrait.transform.localRotation = Quaternion.Euler(0, yaw, 0);
            portraitCamera.transform.position = focus + new Vector3(0, .105f, 4);
            portraitCamera.transform.LookAt(focus);
            portraitCamera.orthographicSize = fullBody ? 1.14f : .82f;
        }

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
                portraitFill.intensity = originalFillIntensity;
                portraitFill.spotAngle = originalFillAngle;
                portraitKey.intensity = originalKeyIntensity;
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
