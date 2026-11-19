using UnityEngine;

namespace SunshineHospital
{
    public sealed partial class HospitalGame
    {
        private GuideMoment replayGuide;
        private int replayLine;
        private float dialogueVisibleAt;
        private GuideMoment previousDialogue;
        private GuideMoment GuideOnScreen => replayGuide != GuideMoment.None ? replayGuide : day.ActiveGuide;
        private string DialoguePose
        {
            get
            {
                if (growthDialogue == 64 || GuideOnScreen is GuideMoment.CloseDay or GuideMoment.FirstTreatment) return "joyful";
                if (growthDialogue == 8 && network.StoryLine == 0) return "worried";
                if (growthDialogue != 0) return network.StoryLine == 0 ? "greeting" : "explaining";
                return HospitalDay.Dialogue(GuideOnScreen, replayGuide != GuideMoment.None ? replayLine : day.GuideLine).Expression;
            }
        }
        private int growthDialogue => network.StoryMoment;

        private void DrawGuide(float width, float footer, bool acceptInput)
        {
            var moment = replayGuide != GuideMoment.None ? replayGuide : day.ActiveGuide;
            int line = replayGuide != GuideMoment.None ? replayLine : day.GuideLine;
            if (useOldHud)
            {
                GUI.Label(new Rect(34, footer + 7, width - 298, 35), "민지", heading);
                GUI.Label(new Rect(34, footer + 43, width - 298, 35), "어서 오세요! 햇살병원에 첫 환자분이 오고 있어요.", label);
                GUI.Button(new Rect(width - 245, footer + 21, 102, 46), "안내 끄기", patientTag);
                GUI.Button(new Rect(width - 134, footer + 21, 114, 46), "계속", primary);
                return;
            }
            if (previousDialogue != moment || dialogueVisibleAt == 0)
            {
                previousDialogue = moment;
                dialogueVisibleAt = Time.unscaledTime;
            }

            var script = HospitalDay.Dialogue(moment, line);
            if (growthDialogue == 0 && moment is GuideMoment.SelectPatient or GuideMoment.ReviewPlan)
            {
                float x = width - 505;
                AlphaFrame(new Rect(x, footer, 482, 96));
                Art(new Rect(x + 10, footer + 11, 55, 55), "portrait-minji");
                GUI.Label(new Rect(x + 73, footer + 12, 386, 33), script.Text, smallText);
                if (GUI.Button(new Rect(x + 350, footer + 49, 112, 35), "확인", primary) && acceptInput)
                    AdvanceVisibleDialogue();
                return;
            }
            float appear = Mathf.SmoothStep(0, 1, (Time.unscaledTime - dialogueVisibleAt) / .18f);
            Color previous = GUI.color;
            GUI.color = new Color(1, 1, 1, appear);
            float panelWidth = Mathf.Min(665, width * .64f);
            float dialogueY = footer - 48 + (1 - appear) * 10;
            float panelLeft = width - panelWidth - 24;
            float portraitWidth = Mathf.Min(442f, width * .43f);
            float portraitHeight = 505f;
            float portraitBottom = footer + 198;
            Panel(new Rect(0, 0, width, footer + 126), new Color(.20f, .18f, .12f, .12f));
            if (room.PortraitTexture != null)
                GUI.DrawTexture(new Rect(4, footer - 294 + (1 - appear) * 5, portraitWidth, 446f),
                    room.PortraitTexture, ScaleMode.ScaleToFit, true);
            else
                Art(new Rect(18, portraitBottom - portraitHeight, portraitWidth, portraitHeight),
                    DialoguePose == "greeting" ? "minji-greeting" : "minji-explaining");
            DialogueShadow(new Rect(panelLeft - 2, dialogueY + 4, panelWidth + 4, 140));
            Art(new Rect(panelLeft - 31, dialogueY + 23, 47, 41), "bubble-tail");
            AlphaFrame(new Rect(panelLeft, dialogueY, panelWidth, 137));
            GUI.Box(new Rect(panelLeft + 28, dialogueY - 20, 95, 37), "민지", quiet);
            GUI.Box(new Rect(panelLeft + 118, dialogueY - 17, 113, 32), "접수 담당", dockSelected);
            Art(new Rect(panelLeft + panelWidth - 61, dialogueY - 23, 58, 58), "dialogue-sunflower");
            GUI.Label(new Rect(panelLeft + 29, dialogueY + 23, panelWidth - 58, 52),
                growthDialogue == 0 ? script.Text : GrowthStory(growthDialogue, network.StoryLine), dialogueText);

            if (GUI.Button(new Rect(panelLeft + 29, dialogueY + 89, 100, 38), "건너뛰기", patientTag) && acceptInput)
            {
                if (growthDialogue != 0) CloseGrowthDialogue();
                else if (replayGuide != GuideMoment.None) replayGuide = GuideMoment.None;
                else day.SkipGuide();
            }
            float nextX = panelLeft + panelWidth - 135;
            if (GUI.Button(new Rect(nextX, dialogueY + 83, 113, 43), "다음    ", primary) && acceptInput)
                AdvanceVisibleDialogue();
            Art(new Rect(nextX + 77, dialogueY + 94, 23, 23), "next");
            if (moment == GuideMoment.Welcome && growthDialogue == 0)
                for (int i = 0; i < HospitalDay.WelcomeLineCount; i++)
                    Art(new Rect(panelLeft + panelWidth / 2 - 13 + i * 16, dialogueY + 107, 10, 10), i == line ? "dot-active" : "dot");
            GUI.color = previous;
        }

        private void CloseGrowthDialogue()
        {
            network.AdvanceStory(skip: true);
        }

        private void AdvanceVisibleDialogue()
        {
            if (growthDialogue != 0) network.AdvanceStory();
            else if (replayGuide != GuideMoment.None)
            {
                if (replayGuide != GuideMoment.Welcome || ++replayLine >= HospitalDay.WelcomeLineCount)
                    replayGuide = GuideMoment.None;
            }
            else day.AdvanceGuide();
        }
    }
}
