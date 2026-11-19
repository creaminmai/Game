using System.IO;

namespace SunshineHospital
{
    public enum GuideMoment { None, Welcome, SelectPatient, ReviewPlan, FirstTreatment, Expansion, CloseDay }

    public sealed partial class HospitalDay
    {
        private const int AllGuideMoments = 126;
        private int seenGuide;
        public const int WelcomeLineCount = 2;
        public int GuideLine { get; private set; }
        public GuideMoment ActiveGuide { get; private set; }

        public void UpdateGuide(bool firstPatientSelected)
        {
            if (DayNumber != 1 || patients.Length == 1) return;
            var first = patients[0];
            if (firstPatientSelected || first.Stage > VisitStage.Reception) MarkGuide(GuideMoment.SelectPatient);
            if (first.Stage > VisitStage.AwaitingPlan) MarkGuide(GuideMoment.ReviewPlan);
            if (Expanded) MarkGuide(GuideMoment.Expansion);
            if (ActiveGuide != GuideMoment.None) return;
            if (Complete)
            {
                TryShowGuide(GuideMoment.CloseDay);
                return;
            }
            if (first.Paid)
            {
                if (!TryShowGuide(GuideMoment.FirstTreatment) && !Expanded) TryShowGuide(GuideMoment.Expansion);
                return;
            }
            if (first.Stage <= VisitStage.Reception && TryShowGuide(GuideMoment.Welcome)) return;
            if (first.Stage == VisitStage.Reception) TryShowGuide(GuideMoment.SelectPatient);
            if (first.Stage == VisitStage.AwaitingPlan) TryShowGuide(GuideMoment.ReviewPlan);
        }

        public static (string Text, string Expression) Dialogue(GuideMoment moment, int line) => moment switch
        {
            GuideMoment.Welcome when line == 0 => ("안녕하세요! 햇살병원에 오신 걸 환영해요.", "greeting"),
            GuideMoment.Welcome => ("우리 함께 첫 환자를 맞이해 볼까요?", "explaining"),
            GuideMoment.SelectPatient => ("김영수 님이나 환자 목록을 눌러 접수해 주세요.", "explaining"),
            GuideMoment.ReviewPlan => ("CT를 마쳤어요. 이제 치료 계획 검토를 맡겨 주세요.", "explaining"),
            GuideMoment.FirstTreatment => ("김영수 님의 오늘 일정이 끝났어요. 남은 환자도 차근차근 돌봐요.", "greeting"),
            GuideMoment.Expansion => ("병원 밖에서 별관 예정지를 둘러볼까요?", "explaining"),
            GuideMoment.CloseDay => ("첫날이 끝났어요. 오늘 기록을 보고 다음 날을 준비해요.", "greeting"),
            _ => ("", "explaining")
        };

        public void AdvanceGuide()
        {
            if (ActiveGuide == GuideMoment.Welcome && GuideLine + 1 < WelcomeLineCount) GuideLine++;
            else DismissGuide();
        }

        public void DismissGuide()
        {
            if (ActiveGuide != GuideMoment.None) MarkGuide(ActiveGuide);
            ActiveGuide = GuideMoment.None;
            GuideLine = 0;
        }

        public void SkipGuide()
        {
            seenGuide = AllGuideMoments;
            ActiveGuide = GuideMoment.None;
            GuideLine = 0;
        }

        private void MarkGuide(GuideMoment moment)
        {
            seenGuide |= 1 << (int)moment;
            if (ActiveGuide == moment) { ActiveGuide = GuideMoment.None; GuideLine = 0; }
        }

        private bool TryShowGuide(GuideMoment moment)
        {
            if ((seenGuide & (1 << (int)moment)) != 0) return false;
            ActiveGuide = moment;
            return true;
        }

        private void WriteGuide(BinaryWriter writer, int version)
        {
            writer.Write(seenGuide);
            writer.Write((int)ActiveGuide);
            if (version >= 6) writer.Write(GuideLine);
        }

        private void ReadGuide(BinaryReader reader, int version)
        {
            seenGuide = reader.ReadInt32();
            int active = reader.ReadInt32();
            if ((seenGuide & ~AllGuideMoments) != 0 || active < 0 || active > (int)GuideMoment.CloseDay ||
                (active != 0 && (DayNumber != 1 || (seenGuide & (1 << active)) != 0)))
                throw new InvalidDataException("Invalid first-day guide progress.");
            ActiveGuide = (GuideMoment)active;
            GuideLine = version >= 6 ? reader.ReadInt32() : 0;
            if (GuideLine < 0 || GuideLine >= WelcomeLineCount || (GuideLine != 0 && ActiveGuide != GuideMoment.Welcome))
                throw new InvalidDataException("Invalid guide line.");
        }
    }
}
