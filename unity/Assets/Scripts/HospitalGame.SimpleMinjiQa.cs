#if UNITY_EDITOR
using System.Collections;
using System.IO;
using UnityEngine;

namespace SunshineHospital
{
    public sealed partial class HospitalGame
    {
        private IEnumerator ReviewSimpleMinji()
        {
            if (recordingInput) yield break;
            if (!Expect(room.BeginSimpleMinjiReview(), "simple Minji prefab, facial graphics and greeting clip loaded"))
                yield break;

            string folder = Path.GetFullPath(Path.Combine(Application.dataPath, "../../artifacts/minji-simple-v1"));
            var previousNetwork = network;
            var previousPage = alphaPage;
            var previousReplay = replayGuide;
            int previousLine = replayLine, previousSelection = selectedId;
            bool previousTitle = titleOpen, previousOutside = outside, previousMap = mapOpen, previousStaff = staffOpen;
            bool recording = false;
            qaRunning = capturingHud = true;
            qaSpeed = 0;
            try
            {
                Directory.CreateDirectory(folder);
                titleOpen = outside = mapOpen = staffOpen = false;
                alphaPage = AlphaPage.None;
                replayGuide = GuideMoment.None;
                network = new HospitalNetwork(new HospitalDay(room.UsesOriginalArt));
                SetDay(network.Active);
                day.UpdateGuide(false);
                reviewExpression = "idle";

                room.FrameSimpleMinji(0, true);
                room.PoseSimpleMinji(0, 0);
                room.LightSimpleMinji(previousFill: true);
                yield return null;
                yield return new WaitForEndOfFrame();
                WritePortrait(Path.Combine(folder, "unity-reference-fill.png"));
                room.LightSimpleMinji();

                foreach (var (yaw, label) in new[] { (0f, "front"), (45f, "45"), (180f, "back") })
                {
                    room.FrameSimpleMinji(yaw, true);
                    room.PoseSimpleMinji(0, 0);
                    yield return new WaitForSecondsRealtime(.24f);
                    yield return new WaitForEndOfFrame();
                    WritePortrait(Path.Combine(folder, $"unity-{label}.png"));
                }

                room.FrameSimpleMinji(10f, false);
                foreach (var (face, frame, label) in new[] { (0, 0f, "smile"), (1, 0f, "joy"), (2, .60f, "explain"), (0, 1.10f, "wave") })
                {
                    room.PoseSimpleMinji(face, frame);
                    yield return new WaitForSecondsRealtime(.25f);
                    yield return new WaitForEndOfFrame();
                    WritePortrait(Path.Combine(folder, $"unity-{label}.png"));
                    if (label == "wave") WriteGameView(Path.Combine(folder, "unity-dialogue.png"));
                }

                recording = true;
                StartCoroutine(RecordVisit(Path.Combine(folder, "minji-simple-wave.mp4"), () => recording));
                double started = Time.realtimeSinceStartupAsDouble;
                bool secondLine = false;
                while (Time.realtimeSinceStartupAsDouble - started < 12)
                {
                    float time = (float)(Time.realtimeSinceStartupAsDouble - started);
                    if (time >= 6f && !secondLine)
                    {
                        AdvanceVisibleDialogue();
                        secondLine = true;
                    }
                    if (time < 4f) room.PoseSimpleMinji(0, time);
                    else if (time >= 6f && time < 9f)
                    {
                        float ease = 1f - Mathf.Abs(Mathf.Clamp01((time - 6f) / 3f) * 2f - 1f);
                        room.PoseSimpleMinji(2, Mathf.SmoothStep(0f, .59f, ease));
                    }
                    else room.PoseSimpleMinji(time >= 9f ? 1 : 0, 0);
                    yield return null;
                }
                recording = false;
                yield return new WaitForEndOfFrame();
                day.SkipGuide();
                yield return new WaitForSecondsRealtime(.3f);
                yield return HudCapture(folder, "unity-operations");
                Debug.Log($"[Hospital QA] Simple Minji review captured in the live hospital: {folder}");
            }
            finally
            {
                recording = false;
                room.EndSimpleMinjiReview();
                reviewExpression = null;
                qaSpeed = 1;
                qaRunning = capturingHud = false;
                network = previousNetwork;
                titleOpen = previousTitle;
                outside = previousOutside;
                mapOpen = previousMap;
                staffOpen = previousStaff;
                alphaPage = previousPage;
                replayGuide = previousReplay;
                replayLine = previousLine;
                SetDay(network.Active);
                Select(previousSelection);
            }
        }
    }
}
#endif
