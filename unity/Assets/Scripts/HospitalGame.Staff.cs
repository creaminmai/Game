using UnityEngine;

namespace SunshineHospital
{
    public sealed partial class HospitalGame
    {
        private void DrawStaffAndResearch(float width, float height, bool acceptInput)
        {
            float left = (width - 650) * .5f;
            float top = (height - 432) * .5f;
            Panel(new Rect(0, 0, width, height), new Color(.13f, .23f, .20f, .55f));
            Panel(new Rect(left, top, 650, 432), Paper);
            GUI.Label(new Rect(left + 23, top + 12, 400, 36), "직원 · 연구", heading);
            if (GUI.Button(new Rect(left + 538, top + 12, 90, 38), "닫기", quiet) && acceptInput)
                staffOpen = false;

            if (LiveNetwork && network.ViewingBranch)
            {
                GUI.Label(new Rect(left + 23, top + 66, 590, 35), "물빛 분원 · 접수와 계획 자동 운영", heading);
                GUI.Label(new Rect(left + 23, top + 114, 590, 36), "본원의 연구가 적용되는 날 두 병원의 새 일정에 반영됩니다.", label);
                GUI.Label(new Rect(left + 23, top + 158, 590, 36), $"CT · {network.Main.ResearchStatus(HospitalResearch.Ct)}", label);
                GUI.Label(new Rect(left + 23, top + 199, 590, 36), $"계획 · {network.Main.ResearchStatus(HospitalResearch.Planning)}", label);
                return;
            }
            ManagementRow(left, top + 55, "민지 · 자동 접수", day.DayNumber < 2 ? "2일차부터 무료로 설정" : "대기 환자를 3초 후 접수",
                day.AutoAdmission ? "사용 중" : "꺼짐", day.DayNumber >= 2 && acceptInput, () => day.SetAutoAdmission(!day.AutoAdmission));
            if (day.TrainingDay == 0)
            {
                ManagementRow(left, top + 119, "운영 교육", day.ChapterTwo ? "계획 업무를 맡길 수 있어요" : "2장 완료 후 이용",
                    "교육 · 500만", day.ChapterTwo && day.CanSpend(HospitalDay.TrainingCost) && acceptInput, () => day.PurchaseTraining());
            }
            else
            {
                ManagementRow(left, top + 119, "계획 지시 자동화", $"접수와 계획을 위임한 귀가 {day.DelegatedDepartures}/4",
                    day.AutoPlanning ? "사용 중" : "꺼짐", acceptInput, () => day.SetAutoPlanning(!day.AutoPlanning));
            }

            if (day.LabDay == 0)
            {
                string reason = !day.ChapterThree ? "3장 완료 후 설립" : outside ? "첫 연구점수 6점 지급" : "병원 밖에서 설립";
                ManagementRow(left, top + 195, "연구소 1단계", reason, "설립 · 1,800만",
                    outside && day.ChapterThree && day.CanSpend(HospitalDay.LabCost) && acceptInput, () => day.PurchaseLab());
                return;
            }

            GUI.Label(new Rect(left + 23, top + 188, 565, 30), $"연구점수 {day.ResearchPoints} · 자금 {day.Funds:N0}만", label);
            ResearchRow(left, top + 222, HospitalResearch.Ct, "CT 촬영 흐름 개선 I", acceptInput);
            ResearchRow(left, top + 290, HospitalResearch.Planning, "계획 협업 개선 I", acceptInput);
            GUI.Label(new Rect(left + 23, top + 363, 570, 45), "500만과 6점 · 완료 다음 날 본원과 분원에 적용", label);
        }

        private void ResearchRow(float left, float top, HospitalResearch project, string title, bool acceptInput)
        {
            string status = day.ResearchStatus(project);
            ManagementRow(left, top, title, status, "연구 시작",
                !day.ResearchSlotBusy && status == "미시작" &&
                day.CanSpend(HospitalDay.ResearchCost) && day.ResearchPoints >= HospitalDay.ResearchPointCost && acceptInput,
                () => day.StartResearch(project));
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
