using System.Linq;
using UnityEngine;

namespace SunshineHospital
{
    public sealed partial class HospitalGame
    {
        private enum AlphaPage { None, Operations, Decor, Stories, Help, Patients }
        private AlphaPage alphaPage;
        private bool titleOpen = true, confirmNew;
        private int previewDecoration = -1;

        private void CloseAlphaPage()
        {
            alphaPage = AlphaPage.None;
            previewDecoration = -1;
        }

        private int PreviewDecorations()
        {
            int pair = 3 << (AlphaCatalog.Decorations[previewDecoration].Slot * 2);
            return (network.Decorations & ~pair) | (1 << previewDecoration);
        }

        private static string GrowthStory(int moment) => moment switch
        {
            1 => "첫 환자들이 귀가했어요. 병원 밖에 치료별관 자리가 있어요.",
            2 => "이제 두 치료실에서 환자를 함께 돌볼 수 있어요.",
            4 => "접수와 계획은 제게 맡기세요. 직원 화면에서 업무를 정해 주세요.",
            8 => "윤서진 선생님이 기록을 살펴보고 있어요. 연구는 완료 다음 날부터 적용돼요.",
            16 => "물빛 분원은 다음 운영일부터 문을 열어요.",
            32 => "바다빛 협력병원이 다음 운영일에 환자를 맞아요.",
            _ => null
        };

        private void DrawAlphaPage(float width, float height, bool input)
        {
            float x = (width - 760) / 2, y = (height - 444) / 2;
            if (alphaPage == AlphaPage.Decor)
            {
                x = 12;
                AlphaFrame(new Rect(x, y, 380, 444));
                GUI.Label(new Rect(x + 18, y + 12, 240, 34), "병원 꾸미기", heading);
                if (GUI.Button(new Rect(x + 277, y + 12, 83, 34), "닫기", quiet) && input) CloseAlphaPage();
                for (int i = 0; i < AlphaCatalog.Decorations.Count; i++)
                {
                    var item = AlphaCatalog.Decorations[i];
                    float row = y + 53 + i * 38;
                    string owned = network.Owns(i) ? "보유" : $"{item.Cost}만";
                    if (GUI.Button(new Rect(x + 18, row, 342, 34), $"{item.Name}   ·   {owned}", previewDecoration == i ? primary : patientTag) && input)
                        previewDecoration = i;
                }
                if (previewDecoration >= 0)
                {
                    if (GUI.Button(new Rect(x + 18, y + 371, 125, 43), "취소", quiet) && input) previewDecoration = -1;
                    if (GUI.Button(new Rect(x + 153, y + 371, 207, 43), network.Owns(previewDecoration) ? "적용" : "구매 및 적용", primary) && input)
                    {
                        if (network.ApplyDecoration(previewDecoration)) { previewDecoration = -1; SaveDay(); }
                        else SetSaveNotice("공동 자금이 부족해요");
                    }
                    GUI.Label(new Rect(x + 18, y + 415, 342, 24), Time.unscaledTime < saveNoticeUntil ? saveNotice : "병원별 지정 슬롯 · 미리보기 중", label);
                }
                return;
            }

            Panel(new Rect(0, 0, width, height), new Color(.15f, .24f, .20f, .34f));
            AlphaFrame(new Rect(x, y, 760, 444));
            if (titleOpen)
            {
                GUI.Label(new Rect(x + 34, y + 27, 600, 45), "햇살병원", heading);
                GUI.Label(new Rect(x + 34, y + 83, 680, 42), "민지와 함께 오늘의 진료를 시작해요.", label);
                if (GUI.Button(new Rect(x + 34, y + 148, 260, 55), "이어하기 · 저장 불러오기", primary) && input)
                {
                    LoadDay(reportMissing: true);
                    titleOpen = false;
                    confirmNew = false;
                }
                if (GUI.Button(new Rect(x + 34, y + 215, 260, 55), confirmNew ? "새 게임 시작 확인" : "새 게임", quiet) && input)
                {
                    if (confirmNew)
                    {
                        try { save.Archive(); }
                        catch (System.Exception error) when (error is System.IO.IOException or System.UnauthorizedAccessException)
                        {
                            SetSaveNotice("기존 저장을 백업하지 못했어요");
                            return;
                        }
                        network = new HospitalNetwork(new HospitalDay(room.UsesOriginalArt));
                        outside = false;
                        SetDay(network.Active);
                        titleOpen = confirmNew = false;
                        SetSaveNotice("새 게임 · 저장할 때 직전 저장을 백업해요");
                    }
                    else confirmNew = true;
                }
                if (GUI.Button(new Rect(x + 314, y + 148, 260, 55), "현재 화면으로", quiet) && input)
                    titleOpen = confirmNew = false;
                if (Time.unscaledTime < saveNoticeUntil) GUI.Label(new Rect(x + 34, y + 330, 680, 32), saveNotice, label);
                if (confirmNew) GUI.Label(new Rect(x + 34, y + 284, 680, 42), "기존 저장을 별도 보관한 뒤 새 게임을 시작합니다.", label);
                return;
            }

            if (GUI.Button(new Rect(x + 645, y + 15, 93, 39), "닫기", quiet) && input) CloseAlphaPage();
            if (alphaPage == AlphaPage.Stories)
            {
                GUI.Label(new Rect(x + 24, y + 14, 560, 40), "민지의 이야기 · 다시 읽기", heading);
                if (GUI.Button(new Rect(x + 24, y + 67, 700, 32), "첫 환영 대화 다시 보기", patientTag) && input)
                {
                    replayGuide = GuideMoment.Welcome;
                    replayLine = 0;
                    outside = false;
                    CloseAlphaPage();
                }
                for (int i = 0; i < 6; i++)
                    if ((network.AvailableStories & (1 << i)) != 0)
                        if (GUI.Button(new Rect(x + 24, y + 110 + i * 38, 700, 32), GrowthStory(1 << i), patientTag) && input)
                        {
                            growthDialogue = 1 << i;
                            outside = false;
                            CloseAlphaPage();
                        }
                return;
            }
            if (alphaPage == AlphaPage.Help)
            {
                GUI.Label(new Rect(x + 24, y + 14, 550, 40), "설정 · 병원 운영 도움말", heading);
                GUI.Label(new Rect(x + 24, y + 78, 700, 39), "환자를 선택하고 접수한 뒤 CT를 기다리세요.", label);
                GUI.Label(new Rect(x + 24, y + 125, 700, 39), "CT가 끝나면 계획을 지시하세요. 치료가 끝나면 200만을 받아요.", label);
                GUI.Label(new Rect(x + 24, y + 172, 700, 39), "장비는 이동부터 예약되며, 대기 순서대로 사용해요.", label);
                if (GUI.Button(new Rect(x + 24, y + 246, 200, 46), "저장", primary) && input) SaveDay();
                if (GUI.Button(new Rect(x + 238, y + 246, 200, 46), "불러오기", quiet) && input) LoadDay(reportMissing: true);
                if (GUI.Button(new Rect(x + 452, y + 246, 200, 46), "시작 화면", quiet) && input)
                {
                    CloseAlphaPage();
                    titleOpen = true;
                }
                GUI.Label(new Rect(x + 24, y + 309, 700, 38), Time.unscaledTime < saveNoticeUntil ? saveNotice : "관리 화면을 열면 시간이 멈춰요.", label);
                return;
            }

            bool patients = alphaPage == AlphaPage.Patients;
            var previous = network.LastDay;
            GUI.Label(new Rect(x + 24, y + 14, 575, 40), patients ? "오늘 예약 환자" : $"{ActiveHospitalName} · 운영과 기록", heading);
            GUI.Label(new Rect(x + 24, y + 64, 705, 32),
                $"CT 대기 {day.Patients.Count(p => p.Stage == VisitStage.CtQueue)} · 계획 대기 {day.Patients.Count(p => p.Stage is VisitStage.PlanQueue or VisitStage.AwaitingPlan)} · 치료 대기 {day.Patients.Count(p => p.Stage == VisitStage.TreatmentQueue)}", label);
            for (int i = 0; i < day.Patients.Count; i++)
            {
                var patient = day.Patients[i];
                float row = y + 106 + i * 39;
                var box = new Rect(x + 25, row, 700, 35);
                if (GUI.Button(box, $"        {patient.Name}     {Status(patient.Stage)}", selectedId == patient.Id ? primary : patientTag) && input &&
                    patient.Stage != VisitStage.NotArrived)
                {
                    Select(patient.Id);
                    CloseAlphaPage();
                }
                Art(new Rect(box.x + 8, box.y + 3, 29, 29), "portrait-patient-" + patient.Id);
                Art(new Rect(box.xMax - 41, box.y + 5, 25, 25), StageIcon(patient.Stage));
            }
            GUI.Label(new Rect(x + 24, y + 348, 700, 28), $"직전 운영일 · 귀가 {previous.Departed}명 · 수입 {previous.Income:N0}만 · 지출 {previous.Expense:N0}만", label);
            if (GUI.Button(new Rect(x + 24, y + 383, 162, 39), "꾸미기", primary) && input) { outside = false; alphaPage = AlphaPage.Decor; }
            if (GUI.Button(new Rect(x + 199, y + 383, 162, 39), "이야기", quiet) && input) alphaPage = AlphaPage.Stories;
            if (GUI.Button(new Rect(x + 374, y + 383, 162, 39), "직원 · 연구", quiet) && input)
            {
                CloseAlphaPage();
                staffOpen = true;
            }
            if (GUI.Button(new Rect(x + 549, y + 383, 164, 39), "설정 · 저장", quiet) && input) alphaPage = AlphaPage.Help;
        }

        private void OnApplicationPause(bool suspended)
        {
            if (suspended && network != null && !network.Active.Paused) network.TogglePause();
        }
    }
}
