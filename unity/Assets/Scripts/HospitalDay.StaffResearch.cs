using System;
using System.Linq;
using System.IO;

namespace SunshineHospital
{
    public enum HospitalResearch { Ct, Planning }

    public sealed partial class HospitalDay
    {
        public const int TrainingCost = 500;
        public const int LabCost = 1800;
        public const int ResearchCost = 500;
        public const int ResearchPointCost = 6;
        private const float DutyDelay = 3f;
        private const int ResearchPointCap = 200;

        private readonly int[] researchStarted = new int[2];
        private readonly int[] researchCompleted = new int[2];
        private readonly int[] researchApplied = new int[2];
        private int lastResearchClose;
        private int admissionCandidate;
        private int planCandidate;
        private double admissionElapsed;
        private double planElapsed;

        public bool AutoAdmission { get; private set; }
        public bool AutoPlanning { get; private set; }
        public int TrainingDay { get; private set; }
        public int DelegatedDepartures { get; private set; }
        public int LabDay { get; private set; }
        public int ResearchPoints { get; private set; }
        public int TrainingExpense { get; private set; }
        public int LabExpense { get; private set; }
        public int ResearchExpense { get; private set; }
        public int TotalExpense => ExpansionExpense + TrainingExpense + LabExpense + ResearchExpense;
        public bool ChapterThree => DelegatedDepartures >= BookingCount;
        public bool ChapterFour => researchApplied.Any(value => value != 0);
        public bool ResearchSlotBusy => Enumerable.Range(0, 2).Any(i => researchStarted[i] != 0 && researchApplied[i] == 0);

        public bool SetAutoAdmission(bool enabled)
        {
            if (enabled && DayNumber < 2) return false;
            if (AutoAdmission != enabled) ResetDuty(ref admissionCandidate, ref admissionElapsed);
            AutoAdmission = enabled;
            return true;
        }

        public bool SetAutoPlanning(bool enabled)
        {
            if (enabled && TrainingDay == 0) return false;
            if (AutoPlanning != enabled) ResetDuty(ref planCandidate, ref planElapsed);
            AutoPlanning = enabled;
            return true;
        }

        public bool PurchaseTraining()
        {
            if (!ChapterTwo || TrainingDay != 0 || Funds < TrainingCost) return false;
            TrainingDay = DayNumber;
            TrainingExpense = TrainingCost;
            return true;
        }

        public bool PurchaseLab()
        {
            if (!ChapterThree || LabDay != 0 || Funds < LabCost) return false;
            LabDay = DayNumber;
            LabExpense = LabCost;
            ResearchPoints = ResearchPointCost;
            if (Complete) lastResearchClose = DayNumber;
            return true;
        }

        public bool StartResearch(HospitalResearch project)
        {
            int slot = (int)project;
            if (slot < 0 || slot >= researchStarted.Length || LabDay == 0 || researchStarted[slot] != 0 ||
                ResearchSlotBusy || Funds < ResearchCost || ResearchPoints < ResearchPointCost) return false;
            ResearchExpense += ResearchCost;
            ResearchPoints -= ResearchPointCost;
            researchStarted[slot] = DayNumber;
            return true;
        }

        public string ResearchStatus(HospitalResearch project)
        {
            int slot = (int)project;
            if (researchApplied[slot] > 0) return $"{researchApplied[slot]}일차부터 적용";
            if (researchCompleted[slot] > 0) return "연구 완료 · 다음 날 적용";
            return researchStarted[slot] > 0 ? $"{researchStarted[slot] + 1}일차 마감 예정" : "미시작";
        }

        private void UpdateDuties(float seconds)
        {
            if (AutoAdmission) RunDuty(VisitStage.Reception, VisitStage.CtQueue, ref admissionCandidate, ref admissionElapsed, seconds);
            if (AutoPlanning) RunDuty(VisitStage.AwaitingPlan, VisitStage.PlanQueue, ref planCandidate, ref planElapsed, seconds);
        }

        private void RunDuty(VisitStage ready, VisitStage queue, ref int candidate, ref double elapsed, float seconds)
        {
            PatientVisit first = null;
            foreach (var patient in patients)
            {
                if (patient.Stage != ready) continue;
                if (first == null || (ready == VisitStage.AwaitingPlan && patient.PlanPriority < first.PlanPriority))
                    first = patient;
            }
            int id = first?.Id ?? 0;
            if (id != candidate)
            {
                candidate = id;
                elapsed = 0;
            }
            if (id == 0) return;
            elapsed += seconds;
            if (elapsed + .00001 < DutyDelay) return;
            Request(id, ready, queue, delegated: true);
            ResetDuty(ref candidate, ref elapsed);
        }

        private static void ResetDuty(ref int candidate, ref double elapsed)
        {
            candidate = 0;
            elapsed = 0;
        }

        private void CloseResearchDay()
        {
            if (!Complete || Income <= 0 || lastResearchClose >= DayNumber) return;
            lastResearchClose = DayNumber;
            if (LabDay == 0) return;
            ResearchPoints = Math.Min(ResearchPointCap, ResearchPoints + 4);
            for (int i = 0; i < researchStarted.Length; i++)
                if (researchStarted[i] > 0 && researchStarted[i] < DayNumber && researchCompleted[i] == 0)
                    researchCompleted[i] = DayNumber;
        }

        private void AdvanceStaffAndResearchDay()
        {
            TrainingExpense = LabExpense = ResearchExpense = 0;
            ResetDuty(ref admissionCandidate, ref admissionElapsed);
            ResetDuty(ref planCandidate, ref planElapsed);
            for (int i = 0; i < researchCompleted.Length; i++)
                if (researchCompleted[i] > 0 && researchApplied[i] == 0) researchApplied[i] = DayNumber;
        }

        private void WriteStaffResearch(BinaryWriter writer)
        {
            writer.Write(AutoAdmission);
            writer.Write(AutoPlanning);
            writer.Write(TrainingDay);
            writer.Write(DelegatedDepartures);
            writer.Write(LabDay);
            writer.Write(ResearchPoints);
            writer.Write(TrainingExpense);
            writer.Write(LabExpense);
            writer.Write(ResearchExpense);
            writer.Write(lastResearchClose);
            writer.Write(admissionCandidate);
            writer.Write(admissionElapsed);
            writer.Write(planCandidate);
            writer.Write(planElapsed);
            for (int i = 0; i < researchStarted.Length; i++)
            {
                writer.Write(researchStarted[i]);
                writer.Write(researchCompleted[i]);
                writer.Write(researchApplied[i]);
            }
        }

        private void ReadStaffResearch(BinaryReader reader)
        {
            AutoAdmission = reader.ReadBoolean();
            AutoPlanning = reader.ReadBoolean();
            TrainingDay = reader.ReadInt32();
            DelegatedDepartures = reader.ReadInt32();
            LabDay = reader.ReadInt32();
            ResearchPoints = reader.ReadInt32();
            TrainingExpense = reader.ReadInt32();
            LabExpense = reader.ReadInt32();
            ResearchExpense = reader.ReadInt32();
            lastResearchClose = reader.ReadInt32();
            admissionCandidate = reader.ReadInt32();
            admissionElapsed = reader.ReadDouble();
            planCandidate = reader.ReadInt32();
            planElapsed = reader.ReadDouble();

            for (int i = 0; i < researchStarted.Length; i++)
            {
                int started = researchStarted[i] = reader.ReadInt32();
                int completed = researchCompleted[i] = reader.ReadInt32();
                int applied = researchApplied[i] = reader.ReadInt32();
                if (started < 0 || started > DayNumber || (started > 0 && (LabDay == 0 || started < LabDay)) ||
                    completed < 0 || completed > DayNumber || (completed > 0 && (started == 0 || completed <= started)) ||
                    applied < 0 || applied > DayNumber || (applied > 0 && (completed == 0 || applied != completed + 1)))
                    throw new InvalidDataException("Invalid research dates.");
            }
        }

        private void ValidateStaffResearch()
        {
            if ((AutoAdmission && DayNumber < 2) || (AutoPlanning && TrainingDay == 0) ||
                TrainingDay < 0 || TrainingDay > DayNumber || (TrainingDay > 0 && !ChapterTwo) ||
                DelegatedDepartures < 0 || DelegatedDepartures > LifetimeDeparted || (DelegatedDepartures > 0 && TrainingDay == 0) ||
                LabDay < 0 || LabDay > DayNumber || (LabDay > 0 && !ChapterThree) ||
                ResearchPoints < 0 || ResearchPoints > ResearchPointCap || (LabDay == 0 && ResearchPoints != 0) ||
                TrainingExpense != (TrainingDay == DayNumber ? TrainingCost : 0) ||
                LabExpense != (LabDay == DayNumber ? LabCost : 0) ||
                ResearchExpense != researchStarted.Count(date => date == DayNumber) * ResearchCost ||
                Enumerable.Range(0, 2).Count(i => researchStarted[i] != 0 && researchApplied[i] == 0) > 1 ||
                lastResearchClose < DayNumber - 1 || lastResearchClose > DayNumber ||
                (lastResearchClose == DayNumber) != Complete ||
                !ValidDuty(AutoAdmission, admissionCandidate, admissionElapsed) ||
                !ValidDuty(AutoPlanning, planCandidate, planElapsed))
                throw new InvalidDataException("Staff or research state inconsistent.");
        }

        private bool ValidDuty(bool enabled, int candidate, double seconds) =>
            candidate >= 0 && candidate <= patients.Length &&
            (candidate != 0 ? enabled && seconds >= 0 && seconds < DutyDelay : seconds == 0);

        private int PastStaffResearchExpense =>
            (TrainingDay > 0 && TrainingDay < DayNumber ? TrainingCost : 0) +
            (LabDay > 0 && LabDay < DayNumber ? LabCost : 0) +
            researchStarted.Count(date => date > 0 && date < DayNumber) * ResearchCost;

        private float ActiveServiceDuration(VisitStage stage)
        {
            if (stage == VisitStage.Ct && researchApplied[(int)HospitalResearch.Ct] > 0) return 4f;
            if (stage == VisitStage.Planning && researchApplied[(int)HospitalResearch.Planning] > 0) return 4f;
            return PatientVisit.DurationOf(stage);
        }
    }
}
