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
        private float qaSpeed = 1f;

        // F9 exercises the live scene at normal speed through the same actions
        // as the HUD, without simulating mouse clicks or modifying saved data.
        private IEnumerator VerifyVisit()
        {
            var previousDay = day;
            int previousSelection = selectedId;
            SetDay(new HospitalDay(room.UsesOriginalArt, 1));
            var visit = day.Patients[0];
            qaRunning = true;
            string folder = Path.GetFullPath(Path.Combine(Application.dataPath, "../../artifacts/unity-overnight/single-regression"));
            try
            {
                Directory.CreateDirectory(folder);
                StartCoroutine(RecordVisit(Path.Combine(folder, "visit.mp4")));
                yield return WaitForStage(visit, VisitStage.Reception, 15);
                if (!Expect(visit.Stage == VisitStage.Reception, "arrival at reception")) yield break;
                selectedId = 0;
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "reception.png"));
                yield return new WaitForSecondsRealtime(1);
                Select(1);
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "selected.png"));

                yield return new WaitForSecondsRealtime(1);
                if (!Expect(day.Admit(1) && !day.Admit(1) && (day.CtOwner == 1) && day.Funds == 900, "admission and CT reservation")) yield break;
                day.TogglePause();
                Vector3 pausedPosition = actors[0].Root.position;
                yield return new WaitForSecondsRealtime(1);
                if (!Expect(actors[0].Root.position == pausedPosition && visit.Stage == VisitStage.WalkingToCt, "paused movement")) yield break;
                day.TogglePause();

                yield return WaitForStage(visit, VisitStage.Ct, 20);
                if (!Expect(visit.Stage == VisitStage.Ct && (day.CtOwner == 1), "CT begins after arrival")) yield break;
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "ct.png"));
                yield return WaitForStage(visit, VisitStage.AwaitingPlan, 20);
                if (!Expect(visit.Stage == VisitStage.AwaitingPlan && !(day.CtOwner == 1) && day.AssignPlan(1) && !day.AssignPlan(1), "CT release and single plan assignment")) yield break;

                yield return WaitForStage(visit, VisitStage.Treatment, 22);
                if (!Expect(visit.Stage == VisitStage.Treatment && (day.TreatmentOwner == 1) && day.Funds == 900, "treatment begins without early reward")) yield break;
                yield return new WaitForSecondsRealtime(2);
                day.TogglePause();
                float pausedElapsed = visit.Elapsed;
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "treatment.png"));
                yield return new WaitForSecondsRealtime(1);
                if (!Expect(Mathf.Approximately(pausedElapsed, visit.Elapsed), "paused treatment timer")) yield break;
                day.TogglePause();

                yield return WaitForStage(visit, VisitStage.Leaving, 35);
                if (!Expect(visit.Stage == VisitStage.Leaving && day.Funds == 1100 && !(day.TreatmentOwner == 1), "single 200 reward at treatment end")) yield break;
                yield return WaitForStage(visit, VisitStage.Complete, 15);
                if (!Expect(visit.Stage == VisitStage.Complete && day.Funds == 1100 && !actors[0].Root.gameObject.activeSelf, "departure and unchanged funds")) yield break;
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "departure.png"));
                yield return new WaitForSecondsRealtime(1);
                Debug.Log($"[Hospital QA] Live normal-speed visit passed. Captures: {folder}");
            }
            finally
            {
                qaRunning = false;
                SetDay(previousDay);
                Select(previousSelection);
            }
        }

        private IEnumerator VerifyDay()
        {
            var previousDay = day;
            int previousSelection = selectedId;
            SetDay(new HospitalDay(room.UsesOriginalArt));
            qaRunning = true;
            qaSpeed = 10f;
            string folder = Path.GetFullPath(Path.Combine(Application.dataPath, "../../artifacts/unity-overnight/four-patient"));
            try
            {
                Directory.CreateDirectory(folder);
                float deadline = Time.realtimeSinceStartup + 40;
                while (day.Patients[3].Stage != VisitStage.Reception && Time.realtimeSinceStartup < deadline)
                    yield return null;
                if (!Expect(day.Patients[3].Stage == VisitStage.Reception, "four arrived at reception")) yield break;
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "reception.png"));

                int[] order = { 3, 1, 4, 2 };
                foreach (int id in order)
                {
                    Select(id);
                    if (!Expect(day.Admit(id) && !day.Admit(id), $"patient {id} admitted once")) yield break;
                }
                if (!Expect(day.CtOwner == 3 && day.Rank(1) == 1 && day.Rank(2) == 3, "CT FIFO and travel reservation")) yield break;

                int peakQueue = 0;
                while (!day.Complete && Time.realtimeSinceStartup < deadline)
                {
                    foreach (var patient in day.Patients)
                    {
                        if (patient.Stage == VisitStage.AwaitingPlan)
                        {
                            Select(patient.Id);
                            day.AssignPlan(patient.Id);
                        }
                        peakQueue = Mathf.Max(peakQueue, day.Rank(patient.Id));
                    }
                    yield return null;
                }
                if (!Expect(day.Complete && day.Departed == 4 && day.Income == 800 && day.Funds == 1700 && peakQueue >= 2,
                        "four departures, shared queue and 800 income")) yield break;
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "summary.png"));
                Debug.Log($"[Hospital QA] Four-patient live scene passed at 10×. Captures: {folder}");
            }
            finally
            {
                qaSpeed = 1f;
                qaRunning = false;
                SetDay(previousDay);
                Select(previousSelection);
            }
        }

        private void VerifySaveInEditor()
        {
            string folder = Path.Combine(Application.temporaryCachePath, "hospital-qa-" + System.Guid.NewGuid().ToString("N"));
            try
            {
                var testDay = new HospitalDay(room.UsesOriginalArt);
                var testStore = new HospitalSave(Path.Combine(folder, "first-day.bin"));
                for (int i = 0; i < 24; i++) testDay.Tick(1);
                testDay.Admit(3);
                testDay.Admit(1);
                testDay.Tick(.25f);
                testStore.Save(testDay);
                bool okay = testStore.Load(room.UsesOriginalArt, out var restored) == HospitalLoadResult.Loaded &&
                    restored.Paused && restored.CtOwner == 3 && restored.Rank(1) == 1 &&
                    restored.Patients[2].Position == testDay.Patients[2].Position && restored.Funds == 900;
                Expect(okay, "Unity save file reproduces paused travel and FIFO in isolated editor storage");
            }
            finally
            {
                if (Directory.Exists(folder)) Directory.Delete(folder, recursive: true);
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
                    if (!qaRunning) break;
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

        private IEnumerator WaitForStage(PatientVisit visit, VisitStage stage, float timeout)
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
