#if UNITY_EDITOR
using System.Collections;
using System.IO;
using UnityEngine;

namespace SunshineHospital
{
    public sealed partial class HospitalGame
    {
        private bool minjiTurntable;

        private IEnumerator ReviewSimpleMinji(bool volume, bool connected)
        {
            if (recordingInput) yield break;
            if (!Expect(room.BeginSimpleMinjiReview(volume, connected), "simple Minji prefab, facial graphics and greeting clip loaded"))
                yield break;

            string folder = Path.GetFullPath(Path.Combine(Application.dataPath, "../../artifacts",
                connected ? "minji-simple-connected" : volume ? "minji-simple-volume" : "minji-simple-v1"));
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

                if (volume)
                {
                    yield return CaptureVolumeReview(folder, connected);
                    yield break;
                }

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
                minjiTurntable = false;
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

        private IEnumerator CaptureVolumeReview(string folder, bool connected)
        {
            room.LightVolumeReview(neutral: true);
            room.PoseSimpleMinji(0, 0);
            foreach (var (yaw, label) in new[] { (0f, "front"), (45f, "45"), (90f, "side"), (180f, "back") })
            {
                room.FrameSimpleMinji(yaw, true);
                yield return null;
                yield return new WaitForEndOfFrame();
                WritePortrait(Path.Combine(folder, $"unity-{label}.png"));
            }
            room.FrameSimpleMinji(10, false);
            room.PoseSimpleMinji(0, 1.10f);
            yield return null;
            yield return new WaitForEndOfFrame();
            WritePortrait(Path.Combine(folder, "unity-neutral-portrait.png"));

            var endOfFrame = new WaitForEndOfFrame();
            bool recording = false;
            if (connected)
            {
                room.FrameConnectedShoulder(35, -1.05f);
                foreach (var (angle, name) in new[] { (0f, "low"), (45f, "lift45"), (90f, "lift90") })
                {
                    room.PoseConnectedLift(angle);
                    yield return null;
                    yield return endOfFrame;
                    WritePortrait(Path.Combine(folder, $"unity-{name}.png"));
                }
            }
            else
            {
                room.FrameSimpleMinji(0, true);
                room.PoseSimpleMinji(0, 0);
                minjiTurntable = true;
                recording = true;
                StartCoroutine(RecordVisit(Path.Combine(folder, "minji-volume-turntable.mp4"), () => recording));
                try
                {
                    double start = Time.realtimeSinceStartupAsDouble;
                    while (Time.realtimeSinceStartupAsDouble - start < 12.7)
                    {
                        float elapsed = (float)(Time.realtimeSinceStartupAsDouble - start);
                        room.RotateSimpleMinji(360 * Mathf.Clamp01((elapsed - .3f) / 12f));
                        yield return null;
                    }
                }
                finally
                {
                    recording = false;
                    minjiTurntable = false;
                }
                yield return endOfFrame;
                yield return null;
            }

            room.LightVolumeReview(neutral: false);
            room.FrameSimpleMinji(10, false);
            room.PoseSimpleMinji(0, 1.10f);
            yield return endOfFrame;
            WritePortrait(Path.Combine(folder, "unity-dialogue-portrait.png"));
            WriteGameView(Path.Combine(folder, "unity-dialogue.png"));

            recording = true;
            string clipName = connected ? "minji-connected-greeting-walk.mp4" : "minji-volume-greeting-walk.mp4";
            StartCoroutine(RecordVisit(Path.Combine(folder, clipName), () => recording));
            try
            {
                double start = Time.realtimeSinceStartupAsDouble;
                float elapsed;
                while ((elapsed = (float)(Time.realtimeSinceStartupAsDouble - start)) < 4.6f)
                {
                    room.PoseSimpleMinji(0, elapsed);
                    yield return null;
                }
                day.SkipGuide();
                yield return null;
                yield return HudCapture(folder, "unity-operations");
                room.VolumeOperationClose = true;
                yield return null;
                yield return HudCapture(folder, "unity-operation-close");
                for (int pass = 0; pass < 2; pass++)
                {
                    room.BeginVolumeWalk();
                    start = Time.realtimeSinceStartupAsDouble;
                    while (Time.realtimeSinceStartupAsDouble - start < 2.45)
                    {
                        room.PoseVolumeWalk();
                        yield return null;
                    }
                }
            }
            finally { recording = false; }
            yield return endOfFrame;
            Debug.Log($"[Hospital QA] Minji geometry and motion review captured: {folder}");
        }
    }
}
#endif
