using UnityEditor;
using UnityEngine;

internal static class MinjiSimpleReviewPrefab
{
    private const string Folder = "Assets/Editor/HospitalArt/";

    [MenuItem("Hospital QA/Create Simple Minji Review Prefab")]
    private static void Create()
    {
        string prefabPath = Folder + "MinjiSimpleReview.prefab";
        if (AssetDatabase.LoadAssetAtPath<GameObject>(prefabPath) != null) return;

        var model = AssetDatabase.LoadAssetAtPath<GameObject>(Folder + "minji-simple-v1.glb");
        if (model == null)
        {
            Debug.LogError("[Hospital QA] Import the simple Minji GLB first.");
            return;
        }

        var stage = new GameObject("Minji Simple Review");
        try
        {
            var visual = (GameObject)PrefabUtility.InstantiatePrefab(model, stage.transform);
            foreach (var item in visual.GetComponentsInChildren<Transform>(true))
                if (item.name is "FaceJoy" or "FaceExplain") item.gameObject.SetActive(false);
            var motion = visual.GetComponentInChildren<Animation>(true);
            if (motion != null) motion.playAutomatically = false;
            PrefabUtility.SaveAsPrefabAsset(stage, prefabPath);
            Debug.Log($"[Hospital QA] Created {prefabPath}");
        }
        finally
        {
            Object.DestroyImmediate(stage);
        }
    }
}
