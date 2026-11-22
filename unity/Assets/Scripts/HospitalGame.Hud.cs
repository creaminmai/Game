using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace SunshineHospital
{
    public sealed partial class HospitalGame
    {
        private readonly Dictionary<string, Texture2D> uiArt = new();
        private Material cameraComposite;
        private GUIStyle frame, bubble, bubbleShadow, minjiBadge, nextCapsule, inset, iconButton, dockButton, dockSelected, smallText, numbers, compactTitle, dockTitle, dialogueText;
        private bool IsDialogueVisible => day.ActiveGuide != GuideMoment.None || replayGuide != GuideMoment.None || growthDialogue != 0;
        private bool useOldHud = false;
        private bool capturingHud = false;

        private void AlphaFrame(Rect box)
        {
            if (Event.current.type == EventType.Repaint) frame.Draw(box, GUIContent.none, false, false, false, false);
        }

        private void DialogueShadow(Rect rect)
        {
            if (Event.current.type != EventType.Repaint) return;
            Color previous = GUI.color;
            GUI.color = new Color(.34f, .23f, .12f, previous.a * .22f);
            bubbleShadow.Draw(rect, GUIContent.none, false, false, false, false);
            GUI.color = previous;
        }

        private void InitializeHud(Font body, Font display)
        {
            frame = useOldHud ? ButtonStyle(body, Paper, Paper, Ink) : EnamelStyle(body, Paper, Ink, 16);
            bubble = EnamelStyle(body, new Color(1f, .965f, .898f), Ink, 24);
            bubbleShadow = EnamelStyle(body, Color.white, Ink, 24);
            minjiBadge = EnamelStyle(display, new Color(.84f, .40f, .32f), Color.white, 20);
            nextCapsule = EnamelStyle(display, new Color(.22f, .58f, .49f), Color.white, 23);
            nextCapsule.fontSize = 20;
            inset = ButtonStyle(body, new Color(.95f, .88f, .75f), new Color(.95f, .88f, .75f), Ink);
            iconButton = ButtonStyle(display, new Color(.99f, .93f, .83f), new Color(1f, .98f, .90f), Ink);
            dockButton = ButtonStyle(display, new Color(.99f, .95f, .86f), Paper, Ink);
            dockSelected = ButtonStyle(display, new Color(.66f, .87f, .78f), new Color(.74f, .91f, .82f), Ink);
            smallText = new GUIStyle(label) { fontSize = 15, wordWrap = true };
            numbers = new GUIStyle(heading) { fontSize = 21, alignment = TextAnchor.MiddleRight };
            compactTitle = new GUIStyle(heading) { fontSize = 20 };
            dialogueText = new GUIStyle(label) { fontSize = 22, wordWrap = true, alignment = TextAnchor.MiddleLeft };
            dialogueText.normal.textColor = new Color(.045f, .115f, .09f);
            dialogueText.hover.textColor = dialogueText.normal.textColor;
            dockTitle = new GUIStyle(compactTitle) { fontSize = 17, alignment = TextAnchor.MiddleCenter };
        }

        private GUIStyle EnamelStyle(Font font, Color face, Color ink, int radius)
        {
            var style = new GUIStyle { font = font, fontSize = 18, alignment = TextAnchor.MiddleCenter,
                border = new RectOffset(radius + 1, radius + 1, radius + 1, radius + 1) };
            FillEnamel(style.normal, face, ink, radius, false);
            FillEnamel(style.hover, Color.Lerp(face, Color.white, .07f), ink, radius, false);
            FillEnamel(style.active, Color.Lerp(face, Ink, .11f), ink, radius, true);
            FillEnamel(style.focused, face, ink, radius, false);
            return style;
        }

        private void FillEnamel(GUIStyleState state, Color fill, Color ink, int radius, bool pressed)
        {
            const int size = 72;
            Color goldEdge = new(.64f, .40f, .19f);
            Color gold = new(.88f, .70f, .39f);
            Color ivory = new(1f, .96f, .81f);
            var texture = new Texture2D(size, size, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
            var pixels = new Color[size * size];
            for (int y = 0; y < size; y++)
            for (int x = 0; x < size; x++)
            {
                float dx = x - Mathf.Clamp(x, radius, size - 1 - radius);
                float dy = y - Mathf.Clamp(y, radius, size - 1 - radius);
                float depth = radius - Mathf.Sqrt(dx * dx + dy * dy);
                float height = Mathf.Clamp01((float)y / (size - 1));
                Color color = depth < 1.2f ? goldEdge :
                    depth < 3.4f ? Color.Lerp(goldEdge, gold, .4f + height * .6f) :
                    depth < 4.7f ? ivory : Color.Lerp(fill * .91f, Color.Lerp(fill, Color.white, .12f), pressed ? 1 - height : height);
                color.a = Mathf.Clamp01(depth + .5f);
                pixels[y * size + x] = color;
            }
            texture.SetPixels(pixels);
            texture.Apply(false, true);
            hudTextures.Add(texture);
            state.background = texture;
            state.textColor = ink;
        }

        private void Art(Rect box, string name)
        {
            if (!uiArt.TryGetValue(name, out var texture))
            {
                string resource = "HospitalUI/" + name;
                texture = Resources.Load<Texture2D>(resource);
                if (texture == null) texture = Resources.Load<Sprite>(resource)?.texture;
                uiArt[name] = texture;
            }
            if (texture != null) GUI.DrawTexture(box, texture, ScaleMode.ScaleToFit, true);
        }

        private void CameraArt(Rect box, RenderTexture texture, bool fit)
        {
            if (Event.current.type != EventType.Repaint) return;
            if (cameraComposite == null)
            {
                var shader = Resources.Load<Shader>("HospitalUI/PresentationGui");
                if (shader != null && shader.isSupported) cameraComposite = new Material(shader);
            }
            if (cameraComposite == null)
            {
                GUI.DrawTexture(box, texture, fit ? ScaleMode.ScaleToFit : ScaleMode.StretchToFill, true);
                return;
            }

            if (fit)
            {
                float scale = Mathf.Min(box.width / texture.width, box.height / texture.height);
                box = new Rect(box.center.x - texture.width * scale / 2, box.center.y - texture.height * scale / 2,
                    texture.width * scale, texture.height * scale);
            }
            var matrix = GUI.matrix;
            Vector3 topLeft = matrix.MultiplyPoint3x4(box.min);
            Vector3 bottomRight = matrix.MultiplyPoint3x4(box.max);
            GUI.matrix = Matrix4x4.identity;
            cameraComposite.SetFloat("_Opacity", GUI.color.a);
            Graphics.DrawTexture(Rect.MinMaxRect(topLeft.x, topLeft.y, bottomRight.x, bottomRight.y), texture, cameraComposite);
            GUI.matrix = matrix;
        }

        private Rect Dock(float width, float height) => new Rect(width / 2 - 235, height - 76, 470, 65);
        private Rect PatientCard(float width) => new Rect(width - 282, 83, 266, 163);

        private bool PointerInHud(Vector2 at, float width, float height)
        {
            if (at.y < 80 || new Rect(16, 85, 223, 45).Contains(at) || Dock(width, height).Contains(at)) return true;
            if (Selection != null && PatientCard(width).Contains(at)) return true;
            return (outside || day.Complete || day.ActiveGuide != GuideMoment.None) && at.y >= height - 180;
        }

        private bool Icon(Rect rect, string asset, string title, bool current, bool input)
        {
            bool pressed = GUI.Button(rect, GUIContent.none, current ? dockSelected : title == null ? iconButton : dockButton) && input;
            float size = title == null ? 27 : 26;
            Art(new Rect(rect.center.x - size / 2, title == null ? rect.center.y - size / 2 : rect.y + 3, size, size), asset);
            if (title != null)
            {
                var text = new Rect(rect.x + 4, rect.y + 27, rect.width - 8, 24);
                GUI.Label(text, title, dockTitle);
            }
            return pressed;
        }

        private void DrawPlayHud(float width, float height, bool input, bool guide)
        {
            var site = new Rect(15, 12, 232, 62);
            AlphaFrame(site);
            Art(new Rect(22, 18, 49, 49), "dialogue-sunflower");
            GUI.Label(new Rect(78, 19, 158, 28), ActiveHospitalName, compactTitle);
            GUI.Label(new Rect(79, 46, 156, 20), day.Site switch
            {
                HospitalSite.Riverside => "물빛 지역 · 강변",
                HospitalSite.Coast => "협력 지역 · 해안",
                _ => "본원 · 동네 병원"
            }, smallText);
            var money = new Rect(width / 2 - 83, 15, 166, 51);
            AlphaFrame(money);
            Art(new Rect(money.x + 9, money.y + 7, 36, 36), "coin");
            GUI.Label(new Rect(money.x + 43, money.y, 109, 50), $"{(LiveNetwork ? network.Funds : day.Funds):N0}만", numbers);
            var dayBox = new Rect(width - 289, 15, 164, 51);
            AlphaFrame(dayBox);
            GUI.Label(new Rect(dayBox.x + 13, dayBox.y + 2, 142, 45), $"{CurrentDate}일 · 완료 {day.Departed}/{day.Patients.Count}", label);
            if (!outside && Icon(new Rect(width - 112, 14, 44, 44), day.Paused ? "play" : "pause", null, day.Paused, input && !guide))
                network.TogglePause();
            if (Icon(new Rect(width - 60, 14, 44, 44), "settings", null, false, input)) alphaPage = AlphaPage.Help;
            if (Time.unscaledTime < saveNoticeUntil)
            {
                AlphaFrame(new Rect(width / 2 - 198, 74, 396, 31));
                GUI.Label(new Rect(width / 2 - 185, 74, 370, 30), saveNotice, smallText);
            }

            var quest = new Rect(16, 85, 223, 45);
            AlphaFrame(quest);
            Art(new Rect(23, 93, 28, 28), "plan");
            string objective = outside ? "진료 시간은 일시정지" : day.Complete ? "오늘의 진료 마감" :
                day.Patients.Any(p => p.Stage == VisitStage.AwaitingPlan) ? "치료 계획을 지시하세요" :
                day.Patients.Any(p => p.Stage == VisitStage.Reception) ? "접수할 환자가 있어요" : "오늘 예약을 진행하세요";
            if (!guide && LiveNetwork && network.NextStory != 0)
            {
                if (GUI.Button(new Rect(54, 90, 179, 35), "민지의 새 이야기", patientTag) && input)
                {
                    network.StartStory(network.NextStory);
                    outside = false;
                }
            }
            else GUI.Label(new Rect(56, 89, 178, 36), objective, smallText);

            if (guide && !outside)
            {
                DrawGuide(width, height - 126, input);
                return;
            }
            previousDialogue = GuideMoment.None;
            var dock = Dock(width, height);
            AlphaFrame(dock);
            Rect Item(int i) => new Rect(dock.x + 8 + i * 92, dock.y + 6, 88, 53);
            if (Icon(Item(0), "overview", "병원", !outside, input)) { outside = false; confirmExpansion = false; }
            if (Icon(Item(1), "people", "환자", false, input)) alphaPage = AlphaPage.Patients;
            if (Icon(Item(2), "build", "증축", outside, input)) { outside = !outside; confirmExpansion = false; }
            if (Icon(Item(3), "map", "지도", false, input)) { mapSelection = network.Site; mapOpen = true; }
            if (Icon(Item(4), "manage", "관리", false, input)) alphaPage = AlphaPage.Operations;
            if (LiveNetwork && network.NextStory != 0) Art(new Rect(Item(3).xMax - 18, Item(3).y + 3, 15, 15), "attention");

            if (outside || day.Complete)
            {
                AlphaFrame(new Rect(16, height - 170, width - 32, 85));
                DrawGrowth(width, height - 170, input);
                return;
            }
            if (Selection != null) DrawSelectedPatient(width, input);
        }

        private void DrawSelectedPatient(float width, bool input)
        {
            var patient = Selection;
            var box = PatientCard(width);
            AlphaFrame(box);
            Art(new Rect(box.x + 12, box.y + 12, 45, 45), "portrait-patient-" + patient.Id);
            GUI.Label(new Rect(box.x + 65, box.y + 12, 143, 28), patient.Name, heading);
            Art(new Rect(box.x + 65, box.y + 42, 20, 20), StageIcon(patient.Stage));
            GUI.Label(new Rect(box.x + 90, box.y + 38, 166, 29), Status(patient.Stage), smallText);
            if (Icon(new Rect(box.xMax - 39, box.y + 8, 31, 31), "close", null, false, input))
            {
                selectedId = 0;
                return;
            }
            GUI.Label(new Rect(box.x + 14, box.y + 70, 238, 37), patient.CourseVisit == 0 ? Guidance(patient) :
                $"치료 과정 {patient.CourseVisit}/3 · {Guidance(patient)}", smallText);
            if (patient.Stage == VisitStage.Reception || patient.Stage == VisitStage.AwaitingPlan)
            {
                bool enabled = GUI.enabled;
                GUI.enabled = enabled && !day.Paused;
                if (GUI.Button(new Rect(box.x + 14, box.y + 108, 238, 43),
                    patient.Stage == VisitStage.Reception ? "접수하기" : "계획 지시", primary) && input)
                {
                    ConfirmSelectedPatient();
                }
                GUI.enabled = enabled;
            }
            else if (patient.Duration > 0)
            {
                var bar = new Rect(box.x + 16, box.y + 120, 234, 12);
                if (Event.current.type == EventType.Repaint) inset.Draw(bar, GUIContent.none, false, false, false, false);
                Panel(new Rect(bar.x + 5, bar.y + 3, (bar.width - 10) * Mathf.Clamp01(patient.Elapsed / patient.Duration), 6), Mint);
            }
        }

        private static string StageIcon(VisitStage stage) => stage switch
        {
            VisitStage.Ct or VisitStage.CtQueue or VisitStage.WalkingToCt => "ct",
            VisitStage.AwaitingPlan or VisitStage.PlanQueue or VisitStage.Planning or VisitStage.WalkingToPlanning => "plan",
            VisitStage.Treatment or VisitStage.TreatmentQueue or VisitStage.WalkingToTreatment => "treatment",
            VisitStage.Complete or VisitStage.Leaving => "outside",
            _ => "people"
        };
    }
}
