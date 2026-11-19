using System;
using System.Collections.Generic;
using System.Numerics;

namespace SunshineHospital
{
    public enum VisitStage
    {
        NotArrived, Entering, Reception, CtQueue, WalkingToCt, Ct, WalkingToPlanning,
        AwaitingPlan, PlanQueue, Planning, TreatmentQueue, WalkingToTreatment, Treatment, Leaving, Complete
    }

    public sealed class PatientVisit
    {
        public int Id { get; }
        public string Name { get; }
        public VisitStage Stage { get; internal set; }
        public Vector2 Position { get; internal set; }
        public Vector2 Heading { get; internal set; } = Vector2.UnitY;
        public float Elapsed => (float)ServiceTime;
        internal double ServiceTime { get; set; }
        internal int Waypoint { get; set; }
        internal int QueueOrder { get; set; }
        public int TreatmentRoom { get; internal set; } = -1;
        public bool Paid => Stage is VisitStage.Leaving or VisitStage.Complete;
        public float Duration => DurationOf(Stage);

        internal PatientVisit(int id, string name)
        {
            Id = id;
            Name = name;
        }

        internal static float DurationOf(VisitStage stage) => stage switch
        {
            VisitStage.Ct => 5f,
            VisitStage.Planning => 5f,
            VisitStage.Treatment => 30f,
            _ => 0f
        };
    }

    public sealed partial class HospitalDay
    {
        public const int BookingCount = 4;
        public const int AnnexBookingCount = 6;
        public const int ExpansionCost = 600;
        public const int StartingFunds = 900;
        public const int VisitFee = 200;
        public const float ArrivalInterval = 6f;
        private const float WalkSpeed = 2.1f;
        private const float StepSeconds = .05f;

        private static readonly string[] Names = { "김영수", "이정호", "박상철", "최민석", "윤태호", "오진우" };
        private PatientVisit[] patients;
        private readonly DayRoutes routes;
        private int serial;
        private double time;
        public IReadOnlyList<PatientVisit> Patients { get; private set; }
        public bool Paused { get; private set; }
        public int Departed { get; private set; }
        public int Income { get; private set; }
        public int DayNumber { get; private set; } = 1;
        public int OpeningFunds { get; private set; } = StartingFunds;
        public int ExpansionExpense { get; private set; }
        public int LifetimePaid { get; private set; }
        public bool Expanded { get; private set; }
        public bool DualTreatment { get; private set; }
        public int LifetimeDeparted => LifetimePaid - Income / VisitFee + Departed;
        public bool ChapterOne => DayNumber > 1 || Complete;
        public bool ChapterTwo => ChapterOne && Expanded && DualTreatment && LifetimeDeparted >= 12;
        public int Funds => OpeningFunds + Income - ExpansionExpense;
        public bool Complete => Departed == patients.Length;
        public int CtOwner => Owner(VisitStage.WalkingToCt, VisitStage.Ct);
        public int PlanOwner => Owner(VisitStage.Planning);
        public int TreatmentOwner => TreatmentOwnerAt(0);

        public int TreatmentOwnerAt(int room)
        {
            foreach (var patient in patients)
                if (patient.TreatmentRoom == room && patient.Stage is VisitStage.WalkingToTreatment or VisitStage.Treatment)
                    return patient.Id;
            return 0;
        }
        public double Time => time;

        public HospitalDay(bool originalArt = true, int bookingCount = BookingCount)
        {
            if (bookingCount != BookingCount && bookingCount != 1) throw new ArgumentOutOfRangeException(nameof(bookingCount));
            OriginalArt = originalArt;
            routes = new DayRoutes(originalArt, bookingCount == 1);
            ResetPatients(bookingCount);
        }

        public string ExpansionReason => Expanded ? "치료별관 운영 중"
            : LifetimePaid == 0 ? "첫 환자 치료 후 열려요"
            : Funds < ExpansionCost ? "자금이 부족해요 · 600만 필요" : "";

        public bool PurchaseExpansion()
        {
            if (ExpansionReason.Length != 0 || patients.Length == 1) return false;
            ExpansionExpense = ExpansionCost;
            Expanded = true;
            Dispatch();
            return true;
        }

        public bool StartNextDay(int bookings)
        {
            if (!Complete || patients.Length == 1 || (bookings != BookingCount && (bookings != AnnexBookingCount || !Expanded)))
                return false;
            OpeningFunds = Funds;
            Income = 0;
            ExpansionExpense = 0;
            Departed = 0;
            time = 0;
            serial = 0;
            DayNumber++;
            ResetPatients(bookings);
            return true;
        }

        private void ResetPatients(int bookings)
        {
            patients = new PatientVisit[bookings];
            for (int i = 0; i < patients.Length; i++)
                patients[i] = new PatientVisit(i + 1, Names[(i + (i < 4 ? DayNumber - 1 : 0)) % (i < 4 ? 4 : 6)]);
            Patients = Array.AsReadOnly(patients);
            Spawn(patients[0]);
        }

        public void TogglePause() => Paused = !Paused;

        public bool Admit(int id) => Request(id, VisitStage.Reception, VisitStage.CtQueue);

        public bool AssignPlan(int id) => Request(id, VisitStage.AwaitingPlan, VisitStage.PlanQueue);

        public int Rank(int id)
        {
            var patient = Find(id);
            if (patient == null || !IsQueue(patient.Stage)) return 0;
            int rank = 1;
            foreach (var other in patients)
                if (other.Stage == patient.Stage && other.QueueOrder < patient.QueueOrder) rank++;
            return rank;
        }

        public void Tick(float seconds)
        {
            if (Paused || Complete || float.IsNaN(seconds) || float.IsInfinity(seconds)) return;
            // A suspended application must not advance multiple minutes on its first frame back.
            seconds = Math.Min(seconds, 1f);
            while (seconds > 0.000001f && !Complete)
            {
                float step = Math.Min(seconds, StepSeconds);
                Step(step);
                seconds -= step;
            }
        }

        private bool Request(int id, VisitStage expected, VisitStage queued)
        {
            var patient = Find(id);
            if (Paused || patient == null || patient.Stage != expected) return false;
            Enqueue(patient, queued);
            Dispatch();
            return true;
        }

        private PatientVisit Find(int id) => id >= 1 && id <= patients.Length ? patients[id - 1] : null;

        private void Step(float seconds)
        {
            time += seconds;
            foreach (var patient in patients)
            {
                if (patient.Stage == VisitStage.NotArrived && time + .000001 >= (patient.Id - 1) * ArrivalInterval)
                    Spawn(patient);

                var path = routes.For(patient.Id, patient.Stage, patient.TreatmentRoom);
                if (path != null)
                    Walk(patient, path, seconds);
                else if (patient.Duration > 0f)
                    AdvanceService(patient, seconds);
            }
            Dispatch();
            if (Expanded && TreatmentOwnerAt(0) is int main && main != 0 &&
                TreatmentOwnerAt(1) is int annex && annex != 0 &&
                patients[main - 1].Stage == VisitStage.Treatment && patients[annex - 1].Stage == VisitStage.Treatment)
                DualTreatment = true;
        }

        private void AdvanceService(PatientVisit patient, float seconds)
        {
            patient.ServiceTime += seconds;
            if (patient.ServiceTime + .00001 < patient.Duration) return;
            switch (patient.Stage)
            {
                case VisitStage.Ct:
                    SetStage(patient, VisitStage.WalkingToPlanning);
                    break;
                case VisitStage.Planning:
                    Enqueue(patient, VisitStage.TreatmentQueue);
                    break;
                case VisitStage.Treatment:
                    SetStage(patient, VisitStage.Leaving);
                    Income += VisitFee;
                    LifetimePaid++;
                    break;
            }
        }

        private void Walk(PatientVisit patient, Vector2[] path, float seconds)
        {
            // A new reservation remains held while the previous patient clears the approach.
            if (patient.Stage == VisitStage.WalkingToTreatment && patient.Waypoint >= path.Length - 2 &&
                Array.Exists(patients, other => other.Stage == VisitStage.Leaving && other.TreatmentRoom == patient.TreatmentRoom && other.Waypoint < 2)) return;
            if (patient.Stage == VisitStage.WalkingToCt && patient.Waypoint >= path.Length - 1 &&
                Array.Exists(patients, other => other.Stage == VisitStage.WalkingToPlanning && other.Waypoint < 2)) return;

            // Keep opposite traffic from closing on the planning doorway at the same time.
            if (patient.Stage == VisitStage.WalkingToTreatment && patient.Waypoint == 2 && patient.Position.X > 1.65f &&
                Array.Exists(patients, other => other.Stage == VisitStage.WalkingToPlanning &&
                    other.Waypoint is 2 or 3 && other.Position.Y > -2.1f)) return;

            float remaining = WalkSpeed * seconds;
            while (patient.Waypoint < path.Length && remaining > 0f)
            {
                Vector2 offset = path[patient.Waypoint] - patient.Position;
                float length = offset.Length();
                if (length > .0001f) patient.Heading = offset / length;
                if (length > remaining)
                {
                    patient.Position += patient.Heading * remaining;
                    return;
                }
                patient.Position = path[patient.Waypoint++];
                remaining -= length;
            }

            if (patient.Waypoint != path.Length) return;
            switch (patient.Stage)
            {
                case VisitStage.Entering:
                    SetStage(patient, VisitStage.Reception);
                    patient.Heading = new Vector2(.485f, .875f);
                    break;
                case VisitStage.WalkingToCt: SetStage(patient, VisitStage.Ct); break;
                case VisitStage.WalkingToPlanning: SetStage(patient, VisitStage.AwaitingPlan); break;
                case VisitStage.WalkingToTreatment: SetStage(patient, VisitStage.Treatment); break;
                case VisitStage.Leaving:
                    SetStage(patient, VisitStage.Complete);
                    Departed++;
                    break;
            }
        }

        private void Dispatch()
        {
            if (CtOwner == 0) AssignFirst(VisitStage.CtQueue, VisitStage.WalkingToCt);
            if (PlanOwner == 0) AssignFirst(VisitStage.PlanQueue, VisitStage.Planning);
            if (TreatmentOwnerAt(0) == 0) AssignFirst(VisitStage.TreatmentQueue, VisitStage.WalkingToTreatment, 0);
            if (Expanded && TreatmentOwnerAt(1) == 0) AssignFirst(VisitStage.TreatmentQueue, VisitStage.WalkingToTreatment, 1);
        }

        private void AssignFirst(VisitStage queued, VisitStage assigned, int room = -1)
        {
            PatientVisit first = null;
            foreach (var patient in patients)
                if (patient.Stage == queued && (first == null || patient.QueueOrder < first.QueueOrder))
                    first = patient;
            if (first == null) return;
            first.TreatmentRoom = room;
            SetStage(first, assigned);
        }

        private int Owner(VisitStage active, VisitStage walking = VisitStage.NotArrived)
        {
            foreach (var patient in patients)
                if (patient.Stage == active || (walking != VisitStage.NotArrived && patient.Stage == walking))
                    return patient.Id;
            return 0;
        }

        private void Enqueue(PatientVisit patient, VisitStage stage)
        {
            SetStage(patient, stage);
            patient.QueueOrder = ++serial;
        }

        private void Spawn(PatientVisit patient)
        {
            patient.Position = routes.Spawn;
            SetStage(patient, VisitStage.Entering);
        }

        private static void SetStage(PatientVisit patient, VisitStage stage)
        {
            patient.Stage = stage;
            patient.ServiceTime = 0;
            patient.Waypoint = 0;
            patient.QueueOrder = 0;
        }

        internal static bool IsQueue(VisitStage stage) =>
            stage is VisitStage.CtQueue or VisitStage.PlanQueue or VisitStage.TreatmentQueue;
    }
}
