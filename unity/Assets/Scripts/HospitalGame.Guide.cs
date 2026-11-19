using UnityEngine;

namespace SunshineHospital
{
    public sealed partial class HospitalGame
    {
        private void DrawGuide(float width, float footer, bool acceptInput)
        {
            string message = day.ActiveGuide switch
            {
                GuideMoment.Welcome => "어서 오세요! 햇살병원에 첫 환자분이 오고 있어요.",
                GuideMoment.SelectPatient => "김영수 님이나 이름을 누른 뒤 접수해 주세요.",
                GuideMoment.ReviewPlan => "CT를 마쳤어요. 김영수 님의 치료 계획 검토를 맡겨 주세요.",
                GuideMoment.FirstTreatment => "김영수 님의 오늘 일정이 끝났어요. 다른 분도 차근차근 돌봐요.",
                GuideMoment.Expansion => "병원 밖에서 별관 예정지를 둘러볼까요? 증축은 선택이에요.",
                GuideMoment.CloseDay => "첫날이 끝났어요. 오늘 기록을 보고 다음 날을 준비해요.",
                _ => ""
            };
            GUI.Label(new Rect(34, footer + 7, width - 298, 35), "민지", heading);
            string detail = Time.unscaledTime < saveNoticeUntil ? saveNotice : message;
            GUI.Label(new Rect(34, footer + 43, width - 298, 35), detail, label);
            if (GUI.Button(new Rect(width - 245, footer + 21, 102, 46), "안내 끄기", patientTag) && acceptInput)
                day.SkipGuide();
            if (GUI.Button(new Rect(width - 134, footer + 21, 114, 46), "계속", primary) && acceptInput)
                day.DismissGuide();
        }
    }
}
