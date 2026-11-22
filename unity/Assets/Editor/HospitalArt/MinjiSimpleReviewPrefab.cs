using UnityEditor;
using UnityEngine;

internal static class MinjiSimpleReviewPrefab
{
    private const string Folder = "Assets/Editor/HospitalArt/";

    [MenuItem("Hospital QA/Create Simple Minji Review Prefab")]
    private static void Create() => Create("minji-simple-v1", "MinjiSimpleReview");

    [MenuItem("Hospital QA/Create Minji Volume Review Prefab")]
    private static void CreateVolume() => Create("minji-simple-volume", "MinjiVolumeReview");

    [MenuItem("Hospital QA/Create Minji Connected Review Prefab")]
    private static void CreateConnected() => Create("minji-simple-connected", "MinjiConnectedReview", refresh: true);

    private static void Create(string modelName, string prefabName, bool refresh = false)
    {
        string prefabPath = Folder + prefabName + ".prefab";
        if (!refresh && AssetDatabase.LoadAssetAtPath<GameObject>(prefabPath) != null) return;

        string modelPath = Folder + modelName + ".glb";
        if (refresh && AssetImporter.GetAtPath(modelPath) is { } importer)
        {
            var settings = new SerializedObject(importer);
            var animation = settings.FindProperty("importSettings.animationMethod");
            if (animation != null && animation.intValue != (int)GLTFast.AnimationMethod.Legacy)
            {
                animation.intValue = (int)GLTFast.AnimationMethod.Legacy;
                settings.ApplyModifiedPropertiesWithoutUndo();
                importer.SaveAndReimport();
            }
            else AssetDatabase.ImportAsset(modelPath, ImportAssetOptions.ForceUpdate | ImportAssetOptions.ForceSynchronousImport);
        }
        var model = AssetDatabase.LoadAssetAtPath<GameObject>(modelPath);
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
            if (motion == null || motion.clip == null)
            {
                Debug.LogError($"[Hospital QA] {modelName}.glb needs a Legacy animation clip for the review sampler.");
                return;
            }
            motion.playAutomatically = false;
            PrefabUtility.SaveAsPrefabAsset(stage, prefabPath);
            Debug.Log($"[Hospital QA] Created {prefabPath}");
        }
        finally
        {
            Object.DestroyImmediate(stage);
        }
    }
}
