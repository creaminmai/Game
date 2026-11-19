using System.IO;

namespace SunshineHospital
{
    public enum GuideMoment { None, Welcome, SelectPatient, ReviewPlan, FirstTreatment, Expansion, CloseDay }

    public sealed partial class HospitalDay
    {
        private const int AllGuideMoments = 126;
        private int seenGuide;
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

        public void DismissGuide()
        {
            if (ActiveGuide != GuideMoment.None) MarkGuide(ActiveGuide);
            ActiveGuide = GuideMoment.None;
        }

        public void SkipGuide()
        {
            seenGuide = AllGuideMoments;
            ActiveGuide = GuideMoment.None;
        }

        private void MarkGuide(GuideMoment moment)
        {
            seenGuide |= 1 << (int)moment;
            if (ActiveGuide == moment) ActiveGuide = GuideMoment.None;
        }

        private bool TryShowGuide(GuideMoment moment)
        {
            if ((seenGuide & (1 << (int)moment)) != 0) return false;
            ActiveGuide = moment;
            return true;
        }

        private void WriteGuide(BinaryWriter writer)
        {
            writer.Write(seenGuide);
            writer.Write((int)ActiveGuide);
        }

        private void ReadGuide(BinaryReader reader)
        {
            seenGuide = reader.ReadInt32();
            int active = reader.ReadInt32();
            if ((seenGuide & ~AllGuideMoments) != 0 || active < 0 || active > (int)GuideMoment.CloseDay ||
                (active != 0 && (DayNumber != 1 || (seenGuide & (1 << active)) != 0)))
                throw new InvalidDataException("Invalid first-day guide progress.");
            ActiveGuide = (GuideMoment)active;
        }
    }
}
