using System.Linq;
using UnityEngine;

namespace SunshineHospital
{
    public sealed partial class HospitalGame
    {
        private HospitalNetwork network;
        private bool mapOpen;
        private bool confirmBranch;
        private bool LiveNetwork => network != null && ReferenceEquals(day, network.Active);
        private int CurrentDate => LiveNetwork ? network.Main.DayNumber : day.DayNumber;
        private string ActiveHospitalName => LiveNetwork && network.ViewingBranch ? "물빛 분원" : "햇살병원";

        private void DrawNetwork(float width, float height, bool acceptInput)
        {
            const float cardWidth = 320;
            float left = (width - 710) / 2;
            float top = (height - 452) / 2;
            Panel(new Rect(0, 0, width, height), new Color(.13f, .23f, .20f, .74f));
            Panel(new Rect(left, top, 710, 452), Paper);
            GUI.Label(new Rect(left + 25, top + 12, 405, 36), $"지역 지도 · {CurrentDate}일차", heading);
            GUI.Label(new Rect(left + 25, top + 46, 550, 28),
                $"공동 자금 {network.Funds:N0}만 · 평판 {network.Reputation} · {network.Time:0}초 · 일시정지", label);
            if (GUI.Button(new Rect(left + 591, top + 17, 96, 37), "닫기", quiet) && acceptInput)
            {
                mapOpen = false;
                confirmBranch = false;
            }

            DrawLocation(left + 25, top + 84, cardWidth, false, acceptInput);
            DrawLocation(left + 365, top + 84, cardWidth, true, acceptInput);

            string message = network.NextStory switch
            {
                1 => "첫 환자들이 귀가했어요. 병원 밖에서 치료별관 자리를 볼까요?",
                2 => "치료실이 두 곳이 됐어요. 두 환자의 치료를 함께 진행해 봐요.",
                4 => "접수와 계획 지시를 맡길 수 있어요. 직원 화면에서 켜 주세요.",
                8 => "연구를 시작해 볼까요? 완료한 연구는 다음 날부터 적용돼요.",
                16 => "물빛 분원은 다음 운영일부터 환자를 맞아요. 지역 지도에서 오갈 수 있어요.",
                _ => null
            };
            if (message != null)
            {
                GUI.Label(new Rect(left + 25, top + 330, 650, 33), $"민지 · {message}", label);
                if (GUI.Button(new Rect(left + 25, top + 369, 105, 39), "확인", primary) && acceptInput)
                    network.DismissStory(false);
                if (GUI.Button(new Rect(left + 140, top + 369, 143, 39), "안내 건너뛰기", quiet) && acceptInput)
                    network.DismissStory(true);
            }
            GUI.Label(new Rect(left + 25, top + 412, 650, 26),
                Time.unscaledTime < saveNoticeUntil ? saveNotice : "해외 협력병원 · 추후 개방", label);
        }

        private void DrawLocation(float left, float top, float width, bool branch, bool acceptInput)
        {
            HospitalDay hospital = branch ? network.Branch : network.Main;
            bool current = branch == network.ViewingBranch;
            Panel(new Rect(left, top, width, 228), branch ? new Color(.78f, .91f, .91f) : new Color(.87f, .93f, .82f));
            if (branch)
            {
                Panel(new Rect(left + 233, top, 58, 52), new Color(.49f, .77f, .81f));
                Panel(new Rect(left + 225, top + 32, 85, 8), new Color(.91f, .72f, .48f));
            }
            GUI.Label(new Rect(left + 15, top + 8, 223, 32), branch ? "물빛 분원 · 강변" : "햇살병원 · 본원", heading);
            if (hospital != null)
            {
                int queues = hospital.Patients.Count(p => HospitalDay.IsQueue(p.Stage));
                int actions = hospital.Patients.Count(p => p.Stage is VisitStage.Reception or VisitStage.AwaitingPlan);
                GUI.Label(new Rect(left + 15, top + 51, width - 30, 31),
                    $"예약 {hospital.Patients.Count}명 · 귀가 {hospital.Departed}명 · 수입 {hospital.Income:N0}만", label);
                GUI.Label(new Rect(left + 15, top + 85, width - 30, 31),
                    $"장비 대기 {queues}명 · 접수·계획 대기 {actions}명", label);
                bool open = !branch || CurrentDate >= network.BranchOpeningDay;
                bool enabled = GUI.enabled;
                GUI.enabled = enabled && !current && open && acceptInput;
                if (GUI.Button(new Rect(left + 15, top + 170, width - 30, 43),
                    current ? "현재 병원" : open ? "이 병원으로" : $"{network.BranchOpeningDay}일차 개원", primary) &&
                    network.Switch(branch))
                {
                    if (SaveDay())
                    {
                        SetDay(network.Active);
                        outside = false;
                        confirmExpansion = false;
                        mapOpen = false;
                    }
                    else network.Switch(!branch);
                }
                GUI.enabled = enabled;
                return;
            }

            string Mark(bool met) => met ? "충족" : "필요";
            GUI.Label(new Rect(left + 15, top + 46, width - 30, 27), $"연구소 챕터 {Mark(network.Main.ChapterFour)} · 운영 위임 {Mark(network.DelegationReady)}", label);
            GUI.Label(new Rect(left + 15, top + 74, width - 30, 27), $"평판 {network.Reputation}/{HospitalNetwork.RequiredReputation} · 9,000만 {Mark(network.Funds >= HospitalNetwork.BranchCost)}", label);
            GUI.Label(new Rect(left + 15, top + 106, width - 30, 47), network.Main.Complete
                ? "치료실 1곳 · 오전 예약 4명 · 자동 접수·계획" : "본원 정산 후 설립할 수 있어요", label);
            bool wasEnabled = GUI.enabled;
            GUI.enabled = wasEnabled && network.CanOpenBranch && acceptInput;
            if (GUI.Button(new Rect(left + 15, top + 170, width - 30, 43),
                confirmBranch ? "9,000만 지불 · 다음 날 개원" : "분원 설립", primary))
            {
                if (confirmBranch && network.OpenBranch()) SaveDay();
                confirmBranch = !confirmBranch;
            }
            GUI.enabled = wasEnabled;
        }
    }
}
