using UnityEditor;
using UnityEngine;

internal static class MinjiSimpleReviewPrefab
{
    private const string Folder = "Assets/Editor/HospitalArt/";

    [MenuItem("Hospital QA/Create Simple Minji Review Prefab")]
    private static void Create() => Create("minji-simple-v1", "MinjiSimpleReview");

    [MenuItem("Hospital QA/Create Minji Volume Review Prefab")]
    private static void CreateVolume() => Create("minji-simple-volume", "MinjiVolumeReview");

    private static void Create(string modelName, string prefabName)
    {
        string prefabPath = Folder + prefabName + ".prefab";
        if (AssetDatabase.LoadAssetAtPath<GameObject>(prefabPath) != null) return;

        var model = AssetDatabase.LoadAssetAtPath<GameObject>(Folder + modelName + ".glb");
        if (model == null)
        {
            Debug.LogError($"[Hospital QA] Import {modelName}.glb first.");
            return;
        }

        var stage = new GameObject(prefabName);
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
