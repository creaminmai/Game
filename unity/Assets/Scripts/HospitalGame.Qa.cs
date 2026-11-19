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
                StartCoroutine(RecordVisit(Path.Combine(folder, "visit.mp4")));
                float deadline = Time.realtimeSinceStartup + 60;
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

                var moving = day.Patients[2];
                day.TogglePause();
                var position = moving.Position;
                yield return new WaitForSecondsRealtime(1);
                if (!Expect(moving.Position == position && moving.Stage == VisitStage.WalkingToCt, "four-patient movement pauses")) yield break;
                day.TogglePause();

                bool checkedTreatmentPause = false;
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
                    if (!checkedTreatmentPause && moving.Stage == VisitStage.Treatment && moving.Elapsed > 2f)
                    {
                        day.TogglePause();
                        float elapsed = moving.Elapsed;
                        yield return new WaitForEndOfFrame();
                        WriteGameView(Path.Combine(folder, "paused-treatment.png"));
                        yield return new WaitForSecondsRealtime(1);
                        if (!Expect(moving.Elapsed == elapsed && day.Funds == 900, "four-patient treatment pauses without payment")) yield break;
                        checkedTreatmentPause = true;
                        day.TogglePause();
                    }
                    yield return null;
                }
                if (!Expect(day.Complete && day.Departed == 4 && day.Income == 800 && day.Funds == 1700 && peakQueue >= 2 && checkedTreatmentPause,
                        "four departures, shared queue and 800 income")) yield break;
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "summary.png"));
                yield return new WaitForSecondsRealtime(1);
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
            string folder = Path.GetFullPath(Path.Combine(Application.dataPath, "../../artifacts/unity-overnight/restart-qa"));
            string processFile = Path.Combine(folder, "writer-process.txt");
            int processId = System.Diagnostics.Process.GetCurrentProcess().Id;
            var beforeStore = new HospitalSave(Path.Combine(folder, "before-treatment-end.bin"));
            var afterStore = new HospitalSave(Path.Combine(folder, "after-treatment-end.bin"));
            if (File.Exists(processFile))
            {
                if (!Expect(File.ReadAllText(processFile) != processId.ToString(), "restore runs in a different Unity editor process")) return;
                var before = ReadBoundary(beforeStore);
                var after = ReadBoundary(afterStore);
                if (!Expect(before != null && after != null, "both boundary saves loaded paused")) return;
                bool beforeReady = before.Patients[0].Stage == VisitStage.Treatment && before.Funds == 900;
                bool afterReady = after.Patients[0].Stage == VisitStage.Leaving && after.Funds == 1100;
                if (!Expect(beforeReady && afterReady, "pre- and post-payment snapshots restored")) return;
                foreach (var dayToFinish in new[] { before, after })
                {
                    dayToFinish.TogglePause();
                    if (!AdvanceTo(dayToFinish, VisitStage.Complete)) return;
                }
                Expect(before.Funds == 1100 && after.Funds == 1100 && before.Income == 200 && after.Income == 200,
                    "both restored saves pay exactly once after departure");
                return;
            }

            var testDay = new HospitalDay(room.UsesOriginalArt);
            if (!AdvanceTo(testDay, VisitStage.Reception) || !testDay.Admit(1) ||
                !AdvanceTo(testDay, VisitStage.AwaitingPlan) || !testDay.AssignPlan(1) ||
                !AdvanceTo(testDay, VisitStage.Treatment)) return;
            for (int i = 0; i < 599; i++) testDay.Tick(.05f);
            if (!Expect(testDay.Patients[0].Stage == VisitStage.Treatment && testDay.Funds == 900, "checkpoint just before treatment payment")) return;
            beforeStore.Save(testDay);
            testDay.Tick(.05f);
            if (!Expect(testDay.Patients[0].Stage == VisitStage.Leaving && testDay.Funds == 1100, "checkpoint just after treatment payment")) return;
            afterStore.Save(testDay);
            File.WriteAllText(processFile, processId.ToString());
            Debug.Log("[Hospital QA] Isolated restart checkpoints written; reload in a new editor process with F11.");
        }

        private HospitalDay ReadBoundary(HospitalSave store)
        {
            return store.Load(room.UsesOriginalArt, out var restored) == HospitalLoadResult.Loaded && restored.Paused
                ? restored : null;
        }

        private static bool AdvanceTo(HospitalDay day, VisitStage target)
        {
            for (int i = 0; i < 1600 && day.Patients[0].Stage != target; i++) day.Tick(.05f);
            return Expect(day.Patients[0].Stage == target, $"restart test reached {target}");
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
