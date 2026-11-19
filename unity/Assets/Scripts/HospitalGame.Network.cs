using System.Linq;
using UnityEngine;

namespace SunshineHospital
{
    public sealed partial class HospitalGame
    {
        private HospitalNetwork network;
        private bool mapOpen;
        private HospitalSite mapSelection;
        private HospitalSite? confirmSite;
        private bool LiveNetwork => network != null && ReferenceEquals(day, network.Active);
        private int CurrentDate => LiveNetwork ? network.Main.DayNumber : day.DayNumber;
        private string ActiveHospitalName => LiveNetwork ? SiteName(network.Site) : "햇살병원";

        private static string SiteName(HospitalSite site) => site switch
        {
            HospitalSite.Riverside => "물빛 분원",
            HospitalSite.Coast => "바다빛 협력병원",
            _ => "햇살병원"
        };

        private void DrawNetwork(float width, float height, bool acceptInput)
        {
            const float cardWidth = 278;
            float left = (width - 890) / 2;
            float top = (height - 452) / 2;
            Panel(new Rect(0, 0, width, height), new Color(.13f, .23f, .20f, .74f));
            AlphaFrame(new Rect(left, top, 890, 452));
            GUI.Label(new Rect(left + 25, top + 12, 405, 36), $"지역 지도 · {CurrentDate}일차", heading);
            GUI.Label(new Rect(left + 25, top + 46, 550, 28),
                $"공동 자금 {network.Funds:N0}만 · 평판 {network.Reputation} · {network.Time:0}초 · 일시정지", label);
            if (GUI.Button(new Rect(left + 770, top + 17, 96, 37), "닫기", quiet) && acceptInput)
            {
                mapOpen = false;
                confirmSite = null;
            }

            var map = new Rect(left + 18, top + 80, 555, 320);
            if (room.MapTexture != null) GUI.DrawTexture(map, room.MapTexture, ScaleMode.StretchToFill, false);
            else Art(map, "region-map");
            for (int i = 0; i < 3; i++)
            {
                var site = (HospitalSite)i;
                var anchor = room.MapAnchor(site);
                DrawMapNode(map.x + anchor.x * map.width - 64, map.y + anchor.y * map.height + 21, site, acceptInput);
            }

            DrawLocation(left + 594, top + 80, cardWidth, mapSelection, acceptInput);
            string message = GrowthStory(network.NextStory);
            if (message != null)
            {
                GUI.Label(new Rect(left + 599, top + 313, 272, 45), "민지에게 새 이야기가 있어요", smallText);
                if (GUI.Button(new Rect(left + 599, top + 366, 105, 39), "대화 보기", primary) && acceptInput)
                {
                    network.StartStory(network.NextStory);
                    outside = false;
                    mapOpen = false;
                }
                if (GUI.Button(new Rect(left + 711, top + 366, 143, 39), "안내 건너뛰기", quiet) && acceptInput)
                    network.DismissStory(true);
            }
            GUI.Label(new Rect(left + 25, top + 412, 650, 26),
                Time.unscaledTime < saveNoticeUntil ? saveNotice : $"09:00–18:00 · 6장 공동 운영 {network.JointClosingDays}/3일 · 영업시간 내 귀가 90% 목표", label);
        }

        private void DrawMapNode(float x, float y, HospitalSite site, bool input)
        {
            string state = network.Site == site ? "현재 병원" : network.Available(site) ? "운영 중" : "설립 조건";
            var box = new Rect(x, y, 128, 45);
            if (GUI.Button(box, SiteName(site), mapSelection == site ? primary : patientTag) && input)
            {
                mapSelection = site;
                confirmSite = null;
            }
            AlphaFrame(new Rect(x + 22, y + 38, 85, 21));
            GUI.Label(new Rect(x + 28, y + 38, 79, 21), state, smallText);
        }

        private void DrawLocation(float left, float top, float width, HospitalSite site, bool acceptInput)
        {
            HospitalDay hospital = network.HospitalAt(site);
            bool coast = site == HospitalSite.Coast;
            bool current = site == network.Site;
            Color surface = coast ? new Color(.99f, .87f, .77f) : site == HospitalSite.Riverside
                ? new Color(.78f, .91f, .91f) : new Color(.87f, .93f, .82f);
            Panel(new Rect(left, top, width, 228), surface);
            GUI.Label(new Rect(left + 14, top + 8, width - 28, 32), SiteName(site), heading);
            if (hospital != null)
            {
                int queues = hospital.Patients.Count(p => HospitalDay.IsQueue(p.Stage));
                GUI.Label(new Rect(left + 14, top + 52, width - 28, 27), $"예약 {hospital.Patients.Count} · 귀가 {hospital.Departed} · 수입 {hospital.Income:N0}만", label);
                GUI.Label(new Rect(left + 14, top + 86, width - 28, 27), $"장비 대기 {queues}명 · 치료실 {(hospital.Expanded ? 2 : 1)}곳", label);
                bool open = network.Available(site);
                bool enabled = GUI.enabled;
                GUI.enabled = enabled && !current && open && acceptInput;
                if (GUI.Button(new Rect(left + 14, top + 170, width - 28, 43),
                    current ? "현재 병원" : open ? "이 병원으로" : $"{network.OpensOn(site)}일차 개원", primary))
                {
                    var previous = network.Site;
                    if (network.Switch(site) && SaveDay())
                    {
                        SetDay(network.Active);
                        outside = false;
                        confirmExpansion = false;
                        mapOpen = false;
                    }
                    else network.Switch(previous);
                }
                GUI.enabled = enabled;
                return;
            }

            string Mark(bool met) => met ? "✓" : "필요";
            int required = coast ? AlphaCatalog.CoastReputation : HospitalNetwork.RequiredReputation;
            int cost = coast ? AlphaCatalog.CoastCost : HospitalNetwork.BranchCost;
            GUI.Label(new Rect(left + 14, top + 43, width - 28, 27), coast
                ? $"분원 귀가 8회 {Mark(network.BranchChapterComplete)} · 교육 III {Mark(network.Main.ResearchActive(HospitalResearch.EducationIII))}"
                : $"연구소 {Mark(network.Main.ChapterFour)} · 운영 위임 {Mark(network.DelegationReady)}", label);
            GUI.Label(new Rect(left + 14, top + 71, width - 28, 27), $"평판 {network.Reputation}/{required} · {cost:N0}만", label);
            GUI.Label(new Rect(left + 14, top + 101, width - 28, 25), network.Complete
                ? coast ? "해안 도시 · 분산 도착 · 별관 후 6명" : "강변 · 오전 집중 예약 4명"
                : "공통 운영 마감 후 설립", label);
            GUI.Label(new Rect(left + 14, top + 129, width - 28, 27), $"공동 자금 {Mark(network.Funds >= cost)} · 위임 {Mark(network.DelegationReady)}", label);
            bool wasEnabled = GUI.enabled;
            GUI.enabled = wasEnabled && (coast ? network.CanOpenCoast : network.CanOpenBranch) && acceptInput;
            if (GUI.Button(new Rect(left + 14, top + 170, width - 28, 43),
                confirmSite == site ? $"{cost:N0}만 지불 · 다음 날" : "병원 설립", primary))
            {
                if (confirmSite == site)
                {
                    if (coast ? network.OpenCoast() : network.OpenBranch()) SaveDay();
                    confirmSite = null;
                }
                else confirmSite = site;
            }
            GUI.enabled = wasEnabled;
        }
    }
}
