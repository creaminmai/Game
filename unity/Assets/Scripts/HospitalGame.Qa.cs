#if UNITY_EDITOR
using System.Collections;
using System.IO;
using UnityEngine;
using UnityEditor.Media;

namespace SunshineHospital
{
    public sealed partial class HospitalGame
    {
        private bool qaRunning;

        // F9 exercises the live scene at normal speed through the same actions
        // as the HUD, without simulating mouse clicks or modifying saved data.
        private IEnumerator VerifyVisit()
        {
            if (visit.Paused) yield break;
            qaRunning = true;
            string folder = Path.GetFullPath(Path.Combine(Application.dataPath, "../../artifacts/unity-overnight/live"));
            try
            {
                Directory.CreateDirectory(folder);
                StartCoroutine(RecordVisit(Path.Combine(folder, "visit.mp4")));
                yield return WaitForStage(VisitStage.Reception, 15);
                if (!Expect(visit.Stage == VisitStage.Reception, "arrival at reception")) yield break;
                selected = false;
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "reception.png"));
                yield return new WaitForSecondsRealtime(1);
                selected = true;
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "selected.png"));

                yield return new WaitForSecondsRealtime(1);
                if (!Expect(visit.Admit() && !visit.Admit() && visit.CtReserved && visit.Funds == 900, "admission and CT reservation")) yield break;
                visit.TogglePause();
                Vector3 pausedPosition = room.Patient.position;
                yield return new WaitForSecondsRealtime(1);
                if (!Expect(room.Patient.position == pausedPosition && visit.Stage == VisitStage.WalkingToCt, "paused movement")) yield break;
                visit.TogglePause();

                yield return WaitForStage(VisitStage.Ct, 20);
                if (!Expect(visit.Stage == VisitStage.Ct && visit.CtReserved, "CT begins after arrival")) yield break;
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "ct.png"));
                yield return WaitForStage(VisitStage.AwaitingPlan, 20);
                if (!Expect(visit.Stage == VisitStage.AwaitingPlan && !visit.CtReserved && visit.AssignPlan() && !visit.AssignPlan(), "CT release and single plan assignment")) yield break;

                yield return WaitForStage(VisitStage.Treatment, 22);
                if (!Expect(visit.Stage == VisitStage.Treatment && visit.TreatmentReserved && visit.Funds == 900, "treatment begins without early reward")) yield break;
                yield return new WaitForSecondsRealtime(2);
                visit.TogglePause();
                float pausedElapsed = visit.Elapsed;
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "treatment.png"));
                yield return new WaitForSecondsRealtime(1);
                if (!Expect(Mathf.Approximately(pausedElapsed, visit.Elapsed), "paused treatment timer")) yield break;
                visit.TogglePause();

                yield return WaitForStage(VisitStage.Leaving, 35);
                if (!Expect(visit.Stage == VisitStage.Leaving && visit.Funds == 1100 && !visit.TreatmentReserved, "single 200 reward at treatment end")) yield break;
                yield return WaitForStage(VisitStage.Complete, 15);
                if (!Expect(visit.Stage == VisitStage.Complete && visit.Funds == 1100 && !room.Patient.gameObject.activeSelf, "departure and unchanged funds")) yield break;
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "departure.png"));
                yield return new WaitForSecondsRealtime(1);
                Debug.Log($"[Hospital QA] Live normal-speed visit passed. Captures: {folder}");
            }
            finally
            {
                if (visit.Paused) visit.TogglePause();
                qaRunning = false;
            }
        }

        private IEnumerator RecordVisit(string path)
        {
            const int rate = 15;
            const int width = 960;
            int height = Mathf.Max(2, Mathf.RoundToInt(width * Screen.height / (float)Screen.width / 2) * 2);
            string recordingPath = Path.Combine(Path.GetDirectoryName(path), "visit-recording.mp4");
            MediaEncoder encoder;
            try
            {
                encoder = new MediaEncoder(recordingPath, new VideoTrackAttributes
                {
                    frameRate = new MediaRational(rate),
                    width = (uint)width,
                    height = (uint)height,
                    includeAlpha = false
                });
            }
            catch (System.Exception error)
            {
                Debug.LogWarning($"[Hospital QA] Video encoder unavailable: {error.Message}");
                yield break;
            }

            var full = RenderTexture.GetTemporary(Screen.width, Screen.height, 0, RenderTextureFormat.ARGB32);
            var small = RenderTexture.GetTemporary(width, height, 0, RenderTextureFormat.ARGB32);
            var frame = new Texture2D(width, height, TextureFormat.RGBA32, false);
            double start = Time.realtimeSinceStartupAsDouble;
            long next = 0;
            int frames = 0;
            var endOfFrame = new WaitForEndOfFrame();
            try
            {
                while (qaRunning)
                {
                    yield return endOfFrame;
                    long elapsed = (long)((Time.realtimeSinceStartupAsDouble - start) * 1000);
                    if (elapsed < next) continue;
                    next = elapsed + 1000 / rate;
                    ScreenCapture.CaptureScreenshotIntoRenderTexture(full);
                    Graphics.Blit(full, small);
                    var previous = RenderTexture.active;
                    try
                    {
                        RenderTexture.active = small;
                        frame.ReadPixels(new Rect(0, 0, width, height), 0, 0, false);
                        frame.Apply(false);
                    }
                    finally
                    {
                        RenderTexture.active = previous;
                    }

                    if (!encoder.AddFrame(frame, new MediaTime(frames == 0 ? 0 : elapsed, 1000)))
                    {
                        Debug.LogWarning("[Hospital QA] Video encoder rejected a frame.");
                        yield break;
                    }
                    frames++;
                }
            }
            finally
            {
                encoder.Dispose();
                RenderTexture.ReleaseTemporary(full);
                RenderTexture.ReleaseTemporary(small);
                Destroy(frame);
            }
            if (frames == 0) yield break;
            File.Copy(recordingPath, path, true);
            File.Delete(recordingPath);
            Debug.Log($"[Hospital QA] Recorded {frames} timestamped Game view frames to {path}");
        }

        private IEnumerator WaitForStage(VisitStage stage, float timeout)
        {
            float deadline = Time.realtimeSinceStartup + timeout;
            while (visit.Stage != stage && Time.realtimeSinceStartup < deadline)
                yield return null;
        }

        private static bool Expect(bool condition, string description)
        {
            if (!condition) Debug.LogError($"[Hospital QA] Failed: {description}");
            else Debug.Log($"[Hospital QA] Passed: {description}");
            return condition;
        }
    }
}
#endif
