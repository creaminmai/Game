using UnityEngine;

namespace SunshineHospital
{
    public sealed partial class HospitalGame
    {
        private GuideMoment replayGuide;
        private int replayLine;
        private float dialogueVisibleAt;
        private GuideMoment previousDialogue;
        private int growthDialogue;

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
            float panelWidth = Mathf.Min(665, width * .65f);
            float dialogueY = footer - 48 + (1 - appear) * 10;
            float panelLeft = width - panelWidth - 24;
            float portraitWidth = Mathf.Min(388f, width * .39f);
            float portraitHeight = 420f;
            float portraitBottom = footer + 127;
            Panel(new Rect(0, 0, width, footer + 126), new Color(.20f, .18f, .12f, .12f));
            Art(new Rect(18, portraitBottom - portraitHeight + (1 - appear) * 8, portraitWidth, portraitHeight),
                script.Expression == "greeting" ? "minji-greeting" : "minji-explaining");
            Art(new Rect(panelLeft - 31, dialogueY + 23, 47, 41), "bubble-tail");
            AlphaFrame(new Rect(panelLeft, dialogueY, panelWidth, 137));
            GUI.Box(new Rect(panelLeft + 28, dialogueY - 20, 95, 37), "민지", quiet);
            GUI.Box(new Rect(panelLeft + 118, dialogueY - 17, 113, 32), "접수 담당", dockSelected);
            Art(new Rect(panelLeft + panelWidth - 61, dialogueY - 23, 58, 58), "sun");
            GUI.Label(new Rect(panelLeft + 29, dialogueY + 23, panelWidth - 58, 52),
                growthDialogue == 0 ? script.Text : GrowthStory(growthDialogue), dialogueText);

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
            if (network.NextStory == growthDialogue) network.DismissStory(false);
            growthDialogue = 0;
        }

        private void AdvanceVisibleDialogue()
        {
            if (growthDialogue != 0) CloseGrowthDialogue();
            else if (replayGuide != GuideMoment.None)
            {
                if (replayGuide != GuideMoment.Welcome || ++replayLine >= HospitalDay.WelcomeLineCount)
                    replayGuide = GuideMoment.None;
            }
            else day.AdvanceGuide();
        }
    }
}
