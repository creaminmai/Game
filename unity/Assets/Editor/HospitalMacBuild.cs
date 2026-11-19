using System.IO;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

internal static class HospitalMacBuild
{
    [MenuItem("Hospital QA/Build Mac player _F5")]
    private static void BuildMac()
    {
        if (EditorApplication.isPlayingOrWillChangePlaymode)
        {
            Debug.LogWarning("[Hospital Build] Exit Play mode before building.");
            return;
        }
        string folder = Path.GetFullPath(Path.Combine(Application.dataPath, "../../artifacts/unity-overnight/builds"));
        Directory.CreateDirectory(folder);
        string app = Path.Combine(folder, "SunshineHospital.app");
        var report = BuildPipeline.BuildPlayer(new BuildPlayerOptions
        {
            scenes = new[] { "Assets/Scenes/Hospital.unity" },
            locationPathName = app,
            target = BuildTarget.StandaloneOSX,
            options = BuildOptions.Development
        });
        Debug.Log($"[Hospital Build] Mac {report.summary.result}; errors {report.summary.totalErrors}; {app}");
    }
}
