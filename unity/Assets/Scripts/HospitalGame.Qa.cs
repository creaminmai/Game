#if UNITY_EDITOR
using System.Collections;
using System.IO;
using System.Linq;
using UnityEngine;
using UnityEditor.Media;

namespace SunshineHospital
{
    public sealed partial class HospitalGame
    {
        private bool qaRunning;
        private float qaSpeed = 1f;
        private string reviewExpression;

        private bool recordingInput;
        private HospitalSave inputPreviousSave;
        private HospitalNetwork inputPreviousNetwork;
        private bool inputPreviousTitle, inputPreviousOutside, inputPreviousStaff, inputPreviousMap;
        private AlphaPage inputPreviousPage;
        private void ToggleDialogueRecording(bool regionalFixture)
        {
            if (recordingInput)
            {
                recordingInput = false;
                save = inputPreviousSave;
                network = inputPreviousNetwork;
                titleOpen = inputPreviousTitle;
                outside = inputPreviousOutside;
                staffOpen = inputPreviousStaff;
                mapOpen = inputPreviousMap;
                alphaPage = inputPreviousPage;
                SetDay(network.Active);
                return;
            }
            string folder = Path.GetFullPath(Path.Combine(Application.dataPath, "../../artifacts/unity-overnight",
                regionalFixture ? "graphics-v2" : "minji-dialogue"));
            Directory.CreateDirectory(folder);
            HospitalNetwork isolated = null;
            if (regionalFixture)
            {
                var fixture = new HospitalSave(Path.Combine(folder, "isolated.bin"));
                if (!Expect(fixture.LoadNetwork(room.UsesOriginalArt, out isolated) == HospitalLoadResult.Loaded &&
                    isolated.Available(HospitalSite.Coast), "regional input review loaded an isolated fixture")) return;
            }
            recordingInput = true;
            inputPreviousSave = save;
            inputPreviousNetwork = network;
            inputPreviousTitle = titleOpen;
            inputPreviousOutside = outside;
            inputPreviousStaff = staffOpen;
            inputPreviousMap = mapOpen;
            inputPreviousPage = alphaPage;
            save = new HospitalSave(Path.Combine(folder, "isolated-input.bin"));
            network = isolated ?? new HospitalNetwork(new HospitalDay(room.UsesOriginalArt));
            titleOpen = mapOpen = staffOpen = outside = false;
            CloseAlphaPage();
            if (regionalFixture)
            {
                network.Switch(HospitalSite.Main);
                mapSelection = HospitalSite.Main;
                mapOpen = true;
            }
            SetDay(network.Active);
            StartCoroutine(RecordVisit(Path.Combine(folder, regionalFixture ? "map-input.mp4" : "input.mp4")));
        }

        private IEnumerator VerifyHud()
        {
            var oldNetwork = network;
            var oldPage = alphaPage;
            bool oldTitle = titleOpen, oldOutside = outside, oldMap = mapOpen, oldStaff = staffOpen;
            int oldId = selectedId;
            string folder = GraphicsReviewFolder();
            qaRunning = capturingHud = true;
            qaSpeed = 0;
            try
            {
                Directory.CreateDirectory(folder);
                titleOpen = outside = mapOpen = staffOpen = false;
                alphaPage = AlphaPage.None;
                network = new HospitalNetwork(new HospitalDay(room.UsesOriginalArt));
                SetDay(network.Active);
                day.UpdateGuide(false);
                if (!Expect(room.UsesOriginalArt, "authored hospital meshes are present")) yield break;
                useOldHud = true;
                heading = null;
                yield return HudCapture(folder, "welcome-before");
                useOldHud = false;
                heading = null;
                yield return new WaitForSecondsRealtime(.3f);
                yield return HudCapture(folder, "welcome");
                if (!Expect(room.PortraitShapeCount > 0, "Minji glTF facial morph renderers are available")) yield break;
                var display = Resources.Load<Font>("Jua-Regular");
                if (!Expect(display != null && "햇살병원민지설정접수하기계획지시900만1,1000/600:30".All(display.HasCharacter),
                    "Jua covers representative Hangul, numbers and punctuation")) yield break;
                if (!Expect(new[] { "coin", "portrait-minji-v2", "map", "pause", "minji-greeting", "minji-explaining" }.All(name =>
                    Resources.Load<Texture2D>("HospitalUI/" + name) is Texture2D asset && asset.width > 8),
                    "HUD icons and portraits are available")) yield break;
                AdvanceVisibleDialogue();
                yield return new WaitForSecondsRealtime(.15f);
                yield return HudCapture(folder, "welcome-next");
                var dialogueSlot = new HospitalSave(Path.Combine(folder, "isolated-dialogue.bin"));
                dialogueSlot.SaveNetwork(network);
                if (!Expect(dialogueSlot.LoadNetwork(room.UsesOriginalArt, out var dialogRestored) == HospitalLoadResult.Loaded &&
                    dialogRestored.Main.ActiveGuide == GuideMoment.Welcome && dialogRestored.Main.GuideLine == 1,
                    "second greeting line restores from isolated save")) yield break;
                AdvanceVisibleDialogue();
                if (!Expect(day.ActiveGuide == GuideMoment.None && !day.Paused, "welcome finishes without changing pause")) yield break;
                day.SkipGuide();
                yield return HudCapture(folder, "interior");
                AdvanceTo(day, VisitStage.Reception);
                Select(1);
                yield return HudCapture(folder, "selected");
                alphaPage = AlphaPage.Patients;
                yield return HudCapture(folder, "patients");
                CloseAlphaPage();
                day.Admit(1);
                AdvanceTo(day, VisitStage.AwaitingPlan);
                yield return HudCapture(folder, "plan");
                day.AssignPlan(1);
                AdvanceTo(day, VisitStage.Treatment);
                yield return HudCapture(folder, "treatment");
                alphaPage = AlphaPage.Help;
                yield return HudCapture(folder, "settings");
                CloseAlphaPage();
                outside = true;
                yield return HudCapture(folder, "expansion");
                confirmExpansion = true;
                yield return HudCapture(folder, "expansion-preview");
                confirmExpansion = false;
                outside = false;
                network.ApplyDecoration(0);
                network.ApplyDecoration(7);
                alphaPage = AlphaPage.Decor;
                yield return HudCapture(folder, "decor");
                CloseAlphaPage();
                mapOpen = true;
                yield return HudCapture(folder, "locked-map");
                mapOpen = false;

                var main = network.Main;
                int capturedStories = 0;
                StartCoroutine(RecordVisit(Path.Combine(folder, "growth-review.mp4")));
                for (int date = 1; date < 80; date++)
                {
                    for (int step = 0; step < 12000 && !network.Complete; step++)
                    {
                        foreach (var patient in main.Patients)
                        {
                            if (!main.AutoAdmission && patient.Stage == VisitStage.Reception) main.Admit(patient.Id);
                            if (!main.AutoPlanning && patient.Stage == VisitStage.AwaitingPlan) main.AssignPlan(patient.Id);
                        }
                        network.Tick(.05f);
                    }
                    if (!Expect(network.Complete, $"alpha operating day {main.DayNumber} closed"))
                    {
                        Debug.LogWarning($"[Hospital QA] Main clock {main.Time:F2}, paused {main.Paused}, CT {main.CtOwner}, " +
                            $"planning {main.PlanOwner}, treatment {main.TreatmentOwnerAt(0)}/{main.TreatmentOwnerAt(1)}. " +
                            string.Join(", ", main.Patients.Select(p => $"{p.Id}:{p.Stage}@{p.Waypoint} {p.Position}")));
                        yield break;
                    }
                    if (date == 1)
                    {
                        yield return HudCapture(folder, "day-result");
                        yield return new WaitForSecondsRealtime(2.5f);
                        main.PurchaseExpansion();
                    }
                    if (main.ChapterTwo && main.TrainingDay == 0)
                    {
                        main.PurchaseTraining();
                        main.SetAutoPlanning(true);
                    }
                    if (main.ChapterThree && main.LabDay == 0) main.PurchaseLab();
                    for (int study = 4; study <= 6; study++)
                        if (main.StartResearch((HospitalResearch)study)) break;
                    if (network.CanOpenBranch) network.OpenBranch();
                    foreach (int moment in new[] { 1, 2, 4, 8, 16 })
                    {
                        if ((capturedStories & moment) != 0 || !network.StartStory(moment)) continue;
                        capturedStories |= moment;
                        yield return new WaitForSecondsRealtime(2.2f);
                        yield return HudCapture(folder, $"growth-{moment}-first");
                        network.AdvanceStory();
                        yield return new WaitForSecondsRealtime(3.1f);
                        yield return HudCapture(folder, $"growth-{moment}-next");
                        network.AdvanceStory();
                    }
                    if (network.CanOpenCoast)
                    {
                        if (!network.OpenCoast() || !network.StartNextDay(6)) yield break;
                        break;
                    }
                    network.StartNextDay(6);
                    main.SetAutoAdmission(true);
                    // The HUD still refers to the same day; actor slots are rebuilt after booking changes.
                    SetDay(main);
                }
                SetDay(main);
                if (!Expect(network.Available(HospitalSite.Coast), "third hospital unlocked with ordinary operating rules")) yield break;
                staffOpen = true;
                researchTab = false;
                yield return HudCapture(folder, "staff");
                researchTab = true;
                yield return HudCapture(folder, "research");
                staffOpen = false;
                mapOpen = true;
                yield return HudCapture(folder, "three-hospital-map");
                yield return new WaitForSecondsRealtime(2.5f);
                mapSelection = HospitalSite.Coast;
                yield return HudCapture(folder, "coast-map-detail");
                yield return new WaitForSecondsRealtime(2.5f);
                mapOpen = false;
                outside = true;
                yield return HudCapture(folder, "main-exterior");
                network.Switch(HospitalSite.Riverside);
                SetDay(network.Active);
                yield return HudCapture(folder, "riverside-exterior");
                network.Switch(HospitalSite.Coast);
                SetDay(network.Active);
                yield return HudCapture(folder, "coast-exterior");
                outside = false;
                yield return HudCapture(folder, "coast-interior");
                var slot = new HospitalSave(Path.Combine(folder, "isolated.bin"));
                slot.SaveNetwork(network);
                if (!Expect(slot.LoadNetwork(room.UsesOriginalArt, out var restored) == HospitalLoadResult.Loaded &&
                    restored.Site == HospitalSite.Coast && restored.Branch != null, "three hospital isolated save restores")) yield break;
                bool returnCaptured = false;
                for (int date = 0; date < 20 && !network.SeasonComplete; date++)
                {
                    foreach (var study in new[] { HospitalResearch.Ct, HospitalResearch.Planning, HospitalResearch.CtII })
                        if (main.StartResearch(study)) break;
                    var booking = day.Patients[0];
                    if (!returnCaptured && booking.CourseVisit >= 2)
                    {
                        for (int step = 0; step < 3000 && booking.Stage != VisitStage.Treatment; step++)
                            network.Tick(.05f);
                        if (!Expect(booking.Stage == VisitStage.Treatment, "return booking went from intake to treatment")) yield break;
                        Select(1);
                        yield return HudCapture(folder, "return-treatment");
                        yield return new WaitForSecondsRealtime(2.5f);
                        returnCaptured = true;
                    }
                    for (int step = 0; step < 14000 && !network.Complete; step++) network.Tick(.05f);
                    if (!Expect(network.Complete, "linked hospitals completed their scheduled visits")) yield break;
                    if (!day.Expanded) day.PurchaseExpansion();
                    if (!network.StartNextDay(6)) yield break;
                    SetDay(network.Active);
                }
                if (!Expect(network.SeasonComplete && returnCaptured && network.StartStory(64), "season ending was earned from operating records")) yield break;
                yield return new WaitForSecondsRealtime(.35f);
                yield return HudCapture(folder, "season-finale");
                yield return new WaitForSecondsRealtime(2.4f);
                network.AdvanceStory();
                var finaleSlot = new HospitalSave(Path.Combine(folder, "isolated-finale.bin"));
                finaleSlot.SaveNetwork(network);
                if (!Expect(finaleSlot.LoadNetwork(room.UsesOriginalArt, out var ending) == HospitalLoadResult.Loaded &&
                    ending.SeasonComplete && ending.StoryMoment == 64 && ending.StoryLine == 1, "season finale line restored")) yield break;
                yield return HudCapture(folder, "season-finale-next");
                yield return new WaitForSecondsRealtime(2.4f);
                network.AdvanceStory();
                Debug.Log($"[Hospital QA] Alpha HUD and three hospitals captured: {folder}");
            }
            finally
            {
                useOldHud = capturingHud = qaRunning = false;
                qaSpeed = 1;
                network = oldNetwork;
                titleOpen = oldTitle;
                outside = oldOutside;
                mapOpen = oldMap;
                staffOpen = oldStaff;
                alphaPage = oldPage;
                SetDay(network.Active);
                Select(oldId);
            }
        }

        private static string GraphicsReviewFolder() =>
            Path.GetFullPath(Path.Combine(Application.dataPath, "../../artifacts/unity-overnight/graphics-v2"));

        private IEnumerator ReviewMinjiFaceStudy()
        {
            var previousNetwork = network;
            var previousPage = alphaPage;
            var previousReplay = replayGuide;
            int previousLine = replayLine, previousSelection = selectedId;
            bool previousTitle = titleOpen, previousOutside = outside, previousMap = mapOpen, previousStaff = staffOpen;
            if (!room.PreviewFaceStudy(false))
            {
                Debug.LogError("[Hospital QA] Minji v3 face study could not be imported.");
                yield break;
            }
            string folder = Path.GetFullPath(Path.Combine(Application.dataPath, "../../artifacts/minji-face-study"));
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
                yield return new WaitForSecondsRealtime(.5f);
                yield return HudCapture(folder, "unity-v2");
                room.PreviewFaceStudy(true);
                yield return new WaitForSecondsRealtime(.25f);
                yield return HudCapture(folder, "unity-v3");
                Debug.Log($"[Hospital QA] Minji face study captured in the live dialogue: {folder}");
                yield return new WaitForSecondsRealtime(3f);
            }
            finally
            {
                room.ResetFaceStudyPreview();
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

        private IEnumerator ReviewMinji()
        {
            var previousNetwork = network;
            var previousPage = alphaPage;
            bool previousTitle = titleOpen, previousOutside = outside, previousMap = mapOpen, previousStaff = staffOpen;
            int previousSelection = selectedId;
            qaRunning = capturingHud = true;
            qaSpeed = 0;
            string folder = GraphicsReviewFolder();
            bool recordingExpressions = true;
            try
            {
                Directory.CreateDirectory(folder);
                titleOpen = outside = mapOpen = staffOpen = false;
                alphaPage = AlphaPage.None;
                network = new HospitalNetwork(new HospitalDay(room.UsesOriginalArt));
                SetDay(network.Active);
                day.UpdateGuide(false);
                reviewExpression = "idle";
                foreach (var angle in new[] { (0f, "front"), (45f, "45"), (90f, "side"), (180f, "back") })
                {
                    room.FramePortraitForReview(angle.Item1, true, true);
                    yield return new WaitForSecondsRealtime(.30f);
                    yield return new WaitForEndOfFrame();
                    WritePortrait(Path.Combine(folder, $"silhouette-{angle.Item2}.png"));
                }
                room.FramePortraitForReview(9f, false, false);
                StartCoroutine(RecordVisit(Path.Combine(folder, "minji-expressions.mp4"), () => recordingExpressions));
                foreach (string expression in new[] { "greeting", "explaining", "joyful", "worried", "relief" })
                {
                    reviewExpression = expression;
                    if (expression == "explaining") AdvanceVisibleDialogue();
                    yield return new WaitForSecondsRealtime(.68f);
                    yield return new WaitForEndOfFrame();
                    WritePortrait(Path.Combine(folder, $"portrait-{expression}.png"));
                    yield return HudCapture(folder, $"dialogue-{expression}");
                    yield return new WaitForSecondsRealtime(1.35f);
                }
                recordingExpressions = false;
                yield return new WaitForEndOfFrame();
                yield return MeasurePortraitFrames(folder);
                Debug.Log($"[Hospital QA] Isolated Minji geometry and expression review captured: {folder}");
            }
            finally
            {
                room.FramePortraitForReview(9f, false, false);
                room.ProfileSkipPortraitCamera = false;
                recordingExpressions = false;
                reviewExpression = null;
                qaSpeed = 1;
                qaRunning = capturingHud = false;
                network = previousNetwork;
                titleOpen = previousTitle;
                outside = previousOutside;
                mapOpen = previousMap;
                staffOpen = previousStaff;
                alphaPage = previousPage;
                SetDay(network.Active);
                Select(previousSelection);
            }
        }

        private IEnumerator MeasurePortraitFrames(string folder)
        {
            var timing = new System.Text.StringBuilder("portrait_renderer,median_frame_ms,p90_frame_ms\n");
            foreach (bool enabled in new[] { false, true, false, true })
            {
                room.ProfileSkipPortraitCamera = !enabled;
                yield return new WaitForSecondsRealtime(.35f);
                var intervals = new float[90];
                for (int i = 0; i < intervals.Length; i++)
                {
                    yield return null;
                    intervals[i] = Time.unscaledDeltaTime * 1_000f;
                }
                System.Array.Sort(intervals);
                timing.Append(System.FormattableString.Invariant($"{enabled},{intervals[45]:F3},{intervals[80]:F3}\n"));
            }
            File.WriteAllText(Path.Combine(folder, "editor-portrait-frame-time.csv"), timing.ToString());
        }

        private void WritePortrait(string path)
        {
            var target = room.PortraitTexture;
            if (target == null) return;
            var previous = RenderTexture.active;
            var image = new Texture2D(target.width, target.height, TextureFormat.RGBA32, false, true);
            try
            {
                RenderTexture.active = target;
                image.ReadPixels(new Rect(0, 0, target.width, target.height), 0, 0, false);
                if (QualitySettings.activeColorSpace == ColorSpace.Linear && !target.sRGB)
                {
                    var pixels = image.GetPixels();
                    for (int i = 0; i < pixels.Length; i++) pixels[i] = pixels[i].gamma;
                    image.SetPixels(pixels);
                }
                image.Apply(false);
                File.WriteAllBytes(path, image.EncodeToPNG());
            }
            finally
            {
                RenderTexture.active = previous;
                Destroy(image);
            }
        }

        private IEnumerator HudCapture(string folder, string name)
        {
            yield return new WaitForEndOfFrame();
            WriteGameView(Path.Combine(folder, name + ".png"));
        }

        private IEnumerator VerifyNetwork()
        {
            var previousNetwork = network;
            int previousSelection = selectedId;
            bool previousOutside = outside, previousStaff = staffOpen, previousMap = mapOpen;
            string folder = Path.GetFullPath(Path.Combine(Application.dataPath, "../../artifacts/unity-overnight/region"));
            qaRunning = true;
            qaSpeed = 0;
            outside = staffOpen = mapOpen = false;
            try
            {
                Directory.CreateDirectory(folder);
                var main = new HospitalDay(room.UsesOriginalArt);
                network = new HospitalNetwork(main);
                SetDay(main);
                outside = true;
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "main-before-annex.png"));

                for (int date = 1; date < 30; date++)
                {
                    for (int frame = 0; frame < 12000 && !main.Complete; frame++)
                    {
                        foreach (var patient in main.Patients)
                        {
                            if (!main.AutoAdmission && patient.Stage == VisitStage.Reception) main.Admit(patient.Id);
                            if (!main.AutoPlanning && patient.Stage == VisitStage.AwaitingPlan) main.AssignPlan(patient.Id);
                        }
                        network.Tick(.05f);
                    }
                    if (!Expect(main.Complete, "regional route day completed")) yield break;
                    if (date == 1)
                    {
                        if (!Expect(main.PurchaseExpansion(), "regional route annex")) yield break;
                        yield return new WaitForEndOfFrame();
                        WriteGameView(Path.Combine(folder, "main-after-annex.png"));
                    }
                    if (main.ChapterTwo && main.TrainingDay == 0)
                    {
                        main.PurchaseTraining();
                        main.SetAutoPlanning(true);
                    }
                    if (main.ChapterThree && main.LabDay == 0)
                    {
                        main.PurchaseLab();
                        main.StartResearch(HospitalResearch.Ct);
                    }
                    if (network.CanOpenBranch) break;
                    network.StartNextDay(6);
                    main.SetAutoAdmission(true);
                }
                if (!Expect(network.OpenBranch() && network.StartNextDay(6), "regional route opens on normal rules")) yield break;
                SetDay(network.Active);
                mapOpen = true;
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "map.png"));
                mapOpen = false;
                if (!Expect(network.Switch(true), "regional route switches to branch")) yield break;
                SetDay(network.Active);
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "branch-exterior.png"));

                outside = false;
                staffOpen = true;
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "branch-research.png"));
                staffOpen = false;
                var visit = day.Patients[0];
                Select(1);
                StartCoroutine(RecordVisit(Path.Combine(folder, "visit.mp4")));
                float deadline = Time.realtimeSinceStartup + 105;
                while (visit.Stage < VisitStage.Treatment && Time.realtimeSinceStartup < deadline)
                {
                    network.Tick(Time.deltaTime);
                    yield return null;
                }
                if (!Expect(visit.Stage == VisitStage.Treatment, "regional branch reaches treatment")) yield break;
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "branch-treatment.png"));
                var store = new HospitalSave(Path.Combine(folder, "isolated-qa.bin"));
                store.SaveNetwork(network);
                if (!Expect(store.LoadNetwork(room.UsesOriginalArt, out var restored) == HospitalLoadResult.Loaded &&
                    restored.ViewingBranch && restored.Branch.TreatmentOwner == 1, "regional branch restores treatment from isolated slot")) yield break;
                while (visit.Stage != VisitStage.Complete && Time.realtimeSinceStartup < deadline)
                {
                    network.Tick(Time.deltaTime);
                    yield return null;
                }
                if (!Expect(visit.Stage == VisitStage.Complete && day.Income == HospitalDay.VisitFee,
                    "regional visit departed and was paid once")) yield break;
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "branch-departure.png"));
                yield return new WaitForSecondsRealtime(.75f);
                Debug.Log($"[Hospital QA] Regional live scene passed. Captures: {folder}");
            }
            finally
            {
                network = previousNetwork;
                outside = previousOutside;
                staffOpen = previousStaff;
                mapOpen = previousMap;
                qaRunning = false;
                qaSpeed = 1;
                SetDay(network.Active);
                Select(previousSelection);
            }
        }

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

        private IEnumerator VerifyCampus()
        {
            var previousDay = day;
            int previousSelection = selectedId;
            bool previousExterior = outside;
            qaRunning = true;
            outside = false;
            qaSpeed = 1;
            string folder = Path.GetFullPath(Path.Combine(Application.dataPath, "../../artifacts/unity-overnight/campus"));
            try
            {
                Directory.CreateDirectory(folder);
                var fixture = new HospitalDay(room.UsesOriginalArt);
                if (!AdvanceTo(fixture, VisitStage.Reception) || !fixture.Admit(1) ||
                    !AdvanceTo(fixture, VisitStage.AwaitingPlan) || !fixture.AssignPlan(1) ||
                    !AdvanceTo(fixture, VisitStage.Leaving)) yield break;
                SetDay(fixture);
                outside = true;
                StartCoroutine(RecordVisit(Path.Combine(folder, "visit.mp4")));
                double time = day.Time;
                yield return new WaitForSecondsRealtime(.65f);
                if (!Expect(day.Time == time && day.Funds == 1100, "outside holds the hospital clock")) yield break;
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "outside-before.png"));
                if (!Expect(day.PurchaseExpansion() && !day.PurchaseExpansion() && day.Funds == 500,
                    "annex costs 600 exactly once")) yield break;
                yield return new WaitForSecondsRealtime(.65f);
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "outside-after.png"));

                outside = false;
                qaSpeed = 12f;
                float deadline = Time.realtimeSinceStartup + 75;
                yield return PlayQaDay(deadline, null);
                if (!Expect(day.Complete && day.Departed == 4 && day.Funds == 1100, "expanded first day closes with four")) yield break;
                if (!Expect(day.StartNextDay(6) && day.Funds == 1100 && day.DayNumber == 2, "next day opens six appointments")) yield break;
                SetDay(day);

                bool capturedDual = false;
                string savePath = Path.Combine(folder, "expanded-test.bin");
                yield return PlayQaDay(deadline, () =>
                {
                    int mainOwner = day.TreatmentOwnerAt(0);
                    int annexOwner = day.TreatmentOwnerAt(1);
                    if (capturedDual || mainOwner == 0 || annexOwner == 0 ||
                        day.Patients[mainOwner - 1].Stage != VisitStage.Treatment ||
                        day.Patients[annexOwner - 1].Stage != VisitStage.Treatment) return false;
                    capturedDual = true;
                    new HospitalSave(savePath).Save(day);
                    return true;
                }, Path.Combine(folder, "dual-treatment.png"));
                if (!Expect(capturedDual && day.Complete && day.Departed == 6 && day.Income == 1200 && day.Funds == 2300,
                    "six appointments, concurrent treatment and next-day ledger")) yield break;
                var store = new HospitalSave(savePath);
                if (!Expect(store.Load(room.UsesOriginalArt, out var restored) == HospitalLoadResult.Loaded &&
                    restored.Paused && restored.Expanded && restored.DayNumber == 2 &&
                    restored.TreatmentOwnerAt(0) != 0 && restored.TreatmentOwnerAt(1) != 0,
                    "both owners restore with the annex and date")) yield break;
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "six-summary.png"));
                yield return new WaitForSecondsRealtime(.8f);
                Debug.Log("[Hospital QA] Campus scene passed (fixture before first purchase, then 12× operation).");
            }
            finally
            {
                qaSpeed = 1;
                qaRunning = false;
                outside = previousExterior;
                SetDay(previousDay);
                Select(previousSelection);
            }
        }

        private IEnumerator CaptureGuide()
        {
            if (day.ActiveGuide == GuideMoment.None) yield break;
            capturing = true;
            try
            {
                string folder = Path.GetFullPath(Path.Combine(Application.dataPath, "../../artifacts/unity-overnight/guide"));
                Directory.CreateDirectory(folder);
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "welcome.png"));
                var testStore = new HospitalSave(Path.Combine(folder, "guide-test.bin"));
                testStore.Save(day);
                Expect(testStore.Load(room.UsesOriginalArt, out var loaded) == HospitalLoadResult.Loaded &&
                    loaded.Paused && loaded.ActiveGuide == day.ActiveGuide, "open guide restores from isolated editor save");
            }
            finally
            {
                capturing = false;
            }
        }

        private IEnumerator VerifyResearch()
        {
            var previous = day;
            int previousSelection = selectedId;
            bool previousExterior = outside;
            bool previousStaff = staffOpen;
            qaRunning = true;
            staffOpen = outside = false;
            qaSpeed = 16f;
            string folder = Path.GetFullPath(Path.Combine(Application.dataPath, "../../artifacts/unity-overnight/research"));
            try
            {
                var fixture = new HospitalDay(room.UsesOriginalArt);
                if (!PrepareTrainingFixture(fixture)) yield break;
                SetDay(fixture);
                Directory.CreateDirectory(folder);
                staffOpen = true;
                StartCoroutine(RecordVisit(Path.Combine(folder, "visit.mp4")));
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "training.png"));
                if (!Expect(day.PurchaseTraining() && day.SetAutoPlanning(true) && day.StartNextDay(4),
                    "training and next operating day")) yield break;
                SetDay(day);
                staffOpen = false;
                float deadline = Time.realtimeSinceStartup + 75;
                while (!day.Complete && Time.realtimeSinceStartup < deadline) yield return null;
                if (!Expect(day.Complete && day.ChapterThree && day.DelegatedDepartures == 4 && day.PurchaseLab() &&
                    day.StartResearch(HospitalResearch.Ct), "four fully delegated visits unlock and start research")) yield break;
                outside = true;
                yield return new WaitForSecondsRealtime(.7f);
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "laboratory.png"));
                if (!Expect(day.StartNextDay(4) && !day.ChapterFour, "research stays pending until another day closes")) yield break;
                SetDay(day);
                outside = false;
                while (!day.Complete && Time.realtimeSinceStartup < deadline) yield return null;
                if (!Expect(day.Complete && day.ResearchPoints == 4 && day.StartNextDay(4) && day.ChapterFour,
                    "one operating day completes research; effect starts on next day")) yield break;
                SetDay(day);
                while (day.Patients[0].Stage != VisitStage.Ct && Time.realtimeSinceStartup < deadline) yield return null;
                if (!Expect(day.Patients[0].Stage == VisitStage.Ct && day.Patients[0].Duration == 4,
                    "live CT uses applied four-second protocol")) yield break;
                var store = new HospitalSave(Path.Combine(folder, "research-test.bin"));
                store.Save(day);
                if (!Expect(store.Load(room.UsesOriginalArt, out var restored) == HospitalLoadResult.Loaded &&
                    restored.AutoAdmission && restored.AutoPlanning && restored.ChapterFour &&
                    restored.Patients[0].Duration == 4 && restored.Funds == day.Funds,
                    "research, funds and active CT duration restore")) yield break;
                Select(1);
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "improved-ct.png"));
                yield return new WaitForSecondsRealtime(.7f);
                Debug.Log("[Hospital QA] Staff and research scene passed (chapter-two fixture, then 16× live operation).");
            }
            finally
            {
                qaSpeed = 1;
                qaRunning = false;
                outside = previousExterior;
                staffOpen = previousStaff;
                SetDay(previous);
                Select(previousSelection);
            }
        }

        private static bool PrepareTrainingFixture(HospitalDay fixture)
        {
            for (int dayNumber = 1; dayNumber <= 3; dayNumber++)
            {
                for (int frame = 0; frame < 12000 && !fixture.Complete; frame++)
                {
                    foreach (var patient in fixture.Patients)
                    {
                        if (patient.Stage == VisitStage.Reception) fixture.Admit(patient.Id);
                        if (patient.Stage == VisitStage.AwaitingPlan) fixture.AssignPlan(patient.Id);
                    }
                    fixture.Tick(.05f);
                }
                if (!fixture.Complete) return false;
                if (dayNumber == 1 && !fixture.PurchaseExpansion()) return false;
                if (dayNumber < 3 && !fixture.StartNextDay(4)) return false;
            }
            return Expect(fixture.ChapterTwo && fixture.SetAutoAdmission(true), "isolated completed chapter-two fixture");
        }

        private IEnumerator PlayQaDay(float deadline, System.Func<bool> capture, string image = null)
        {
            while (!day.Complete && Time.realtimeSinceStartup < deadline)
            {
                foreach (var patient in day.Patients)
                {
                    if (patient.Stage == VisitStage.Reception) day.Admit(patient.Id);
                    if (patient.Stage == VisitStage.AwaitingPlan) day.AssignPlan(patient.Id);
                }
                if (capture != null && capture())
                {
                    yield return new WaitForEndOfFrame();
                    WriteGameView(image);
                }
                yield return null;
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

        private IEnumerator RecordVisit(string path, System.Func<bool> keepRecording = null)
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
                while (keepRecording?.Invoke() ?? (qaRunning || recordingInput))
                {
                    yield return endOfFrame;
                    if (!(keepRecording?.Invoke() ?? (qaRunning || recordingInput))) break;
                    long elapsed = (long)((Time.realtimeSinceStartupAsDouble - start) * 1000);
                    if (elapsed < next) continue;
                    next = elapsed + 1000 / rate;
                    ScreenCapture.CaptureScreenshotIntoRenderTexture(full);
                    // MediaEncoder interprets the first texture row as the top of the frame.
                    Graphics.Blit(full, small, new Vector2(1, -1), new Vector2(0, 1));
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
