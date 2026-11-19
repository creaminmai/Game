namespace SunshineHospital
{
    public enum HospitalSite { Main, Riverside, Coast }

    public static class AlphaCatalog
    {
        public const int CoastCost = 20000;
        public const int CoastReputation = 65;
        public const int CoastFirstDayInterval = 9;
        public const int RiversideArrivalInterval = 3;

        public readonly struct Study
        {
            public readonly string Name, Effect;
            public readonly int Cost, Points, Days, Prerequisite;
            public Study(string name, string effect, int cost, int points, int days, int prerequisite = -1)
            {
                Name = name;
                Effect = effect;
                Cost = cost;
                Points = points;
                Days = days;
                Prerequisite = prerequisite;
            }
        }

        public static readonly System.Collections.Generic.IReadOnlyList<Study> Studies = System.Array.AsReadOnly(new[]
        {
            new Study("CT 촬영 흐름 I", "촬영 5초 → 4초", 500, 6, 1),
            new Study("계획 협업 I", "계획 5초 → 4초", 500, 6, 1),
            new Study("CT 촬영 흐름 II", "촬영 4초 → 3초", 1200, 12, 2, 0),
            new Study("계획 협업 II", "계획 4초 → 3초", 1200, 12, 2, 1),
            new Study("교육 체계 I", "자동 접수 준비 3초 → 2초", 500, 6, 1),
            new Study("교육 체계 II", "자동 계획 준비 3초 → 2초", 1200, 12, 2, 4),
            new Study("교육 협력체계 III", "자동 업무 준비 각 1초 · 해안 협력 교육 조건", 2200, 20, 3, 5)
        });

        public readonly struct Decoration
        {
            public readonly string Name;
            public readonly int Slot, Cost;
            public Decoration(string name, int slot, int cost) { Name = name; Slot = slot; Cost = cost; }
        }

        public static readonly System.Collections.Generic.IReadOnlyList<Decoration> Decorations = System.Array.AsReadOnly(new[]
        {
            new Decoration("민트 화분", 0, 80), new Decoration("코랄 화분", 0, 80),
            new Decoration("햇살 액자", 1, 100), new Decoration("강변 액자", 1, 100),
            new Decoration("민트 대기석", 2, 120), new Decoration("꿀빛 대기석", 2, 120),
            new Decoration("크림 입구 러그", 3, 90), new Decoration("코랄 입구 러그", 3, 90)
        });
    }
}
