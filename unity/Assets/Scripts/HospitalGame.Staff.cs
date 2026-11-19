using UnityEngine;

namespace SunshineHospital
{
    public sealed partial class HospitalGame
    {
        private bool researchTab;

        private void DrawStaffAndResearch(float width, float height, bool acceptInput)
        {
            float left = (width - 650) * .5f;
            float top = (height - 432) * .5f;
            Panel(new Rect(0, 0, width, height), new Color(.13f, .23f, .20f, .55f));
            AlphaFrame(new Rect(left, top, 650, 432));
            GUI.Label(new Rect(left + 23, top + 12, 400, 36), "직원 · 연구", heading);
            if (GUI.Button(new Rect(left + 538, top + 12, 90, 38), "닫기", quiet) && acceptInput)
                staffOpen = false;

            if (GUI.Button(new Rect(left + 289, top + 12, 111, 38), "직원", researchTab ? quiet : primary) && acceptInput) researchTab = false;
            if (GUI.Button(new Rect(left + 411, top + 12, 111, 38), "연구", researchTab ? primary : quiet) && acceptInput) researchTab = true;

            var headquarters = LiveNetwork ? network.Main : day;
            if (researchTab && headquarters.LabDay != 0)
            {
                GUI.Label(new Rect(left + 23, top + 52, 610, 29), $"연구점수 {headquarters.ResearchPoints} · 완료 다음 날 모든 병원에 적용", label);
                for (int i = 0; i < AlphaCatalog.Studies.Count; i++)
                {
                    var project = (HospitalResearch)i;
                    var study = AlphaCatalog.Studies[i];
                    float row = top + 84 + i * 47;
                    GUI.Label(new Rect(left + 24, row, 440, 24), $"{study.Name} · {headquarters.ResearchStatus(project)}", label);
                    string prereq = study.Prerequisite >= 0 && !headquarters.ResearchActive((HospitalResearch)study.Prerequisite)
                        ? $" · 선행 {AlphaCatalog.Studies[study.Prerequisite].Name}" : "";
                    GUI.Label(new Rect(left + 24, row + 20, 441, 23), study.Effect + prereq, label);
                    bool enabled = GUI.enabled;
                    GUI.enabled = enabled && acceptInput && day == headquarters && headquarters.CanStartResearch(project);
                    if (GUI.Button(new Rect(left + 460, row + 4, 165, 36), $"{study.Cost:N0}만 · {study.Points}점", primary))
                        headquarters.StartResearch(project);
                    GUI.enabled = enabled;
                }
                return;
            }

            if (day.Site != HospitalSite.Main)
            {
                GUI.Label(new Rect(left + 23, top + 65, 590, 36), "지역 운영팀 · 접수와 계획 위임", heading);
                GUI.Label(new Rect(left + 23, top + 113, 591, 34), $"접수 준비 {day.IntakeDelay:0}초 · 계획 준비 {day.PlanningDelay:0}초", label);
                GUI.Label(new Rect(left + 23, top + 159, 591, 34), "새 연구는 본원에서 시작할 수 있어요.", label);
                return;
            }
            ManagementRow(left, top + 55, "민지 · 자동 접수", day.DayNumber < 2 ? "2일차부터 무료로 설정" : $"대기 환자를 {day.IntakeDelay:0}초 후 접수",
                day.AutoAdmission ? "사용 중" : "꺼짐", day.DayNumber >= 2 && acceptInput, () => day.SetAutoAdmission(!day.AutoAdmission));
            if (day.TrainingDay == 0)
            {
                ManagementRow(left, top + 119, "운영 교육", day.ChapterTwo ? "계획 업무를 맡길 수 있어요" : "2장 완료 후 이용",
                    "교육 · 500만", day.ChapterTwo && day.CanSpend(HospitalDay.TrainingCost) && acceptInput, () => day.PurchaseTraining());
            }
            else
            {
                ManagementRow(left, top + 119, "계획 지시 자동화", $"담당 민지 · 준비 {day.PlanningDelay:0}초 · 위임 귀가 {day.DelegatedDepartures}명",
                    day.AutoPlanning ? "사용 중" : "꺼짐", acceptInput, () => day.SetAutoPlanning(!day.AutoPlanning));
            }

            if (day.LabDay == 0)
            {
                string reason = !day.ChapterThree ? "3장 완료 후 설립" : outside ? "첫 연구점수 6점 지급" : "병원 밖에서 설립";
                ManagementRow(left, top + 195, "연구소 1단계", reason, "설립 · 1,800만",
                    outside && day.ChapterThree && day.CanSpend(HospitalDay.LabCost) && acceptInput, () => day.PurchaseLab());
                return;
            }

            GUI.Label(new Rect(left + 23, top + 203, 585, 36), "연구 탭에서 병목에 맞는 연구를 선택할 수 있어요.", label);
        }

        private void ManagementRow(float left, float top, string title, string detail, string action, bool enabled, System.Action change)
        {
            GUI.Label(new Rect(left + 23, top, 405, 31), title, heading);
            GUI.Label(new Rect(left + 24, top + 28, 418, 28), detail, label);
            bool before = GUI.enabled;
            GUI.enabled = before && enabled;
            if (GUI.Button(new Rect(left + 466, top + 9, 161, 42), action, primary)) change();
            GUI.enabled = before;
        }
    }
}
