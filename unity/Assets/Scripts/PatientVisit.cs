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
        public const int StartingFunds = 900;
        public const int VisitFee = 200;
        public const float ArrivalInterval = 6f;
        private const float WalkSpeed = 2.1f;
        private const float StepSeconds = .05f;

        private static readonly string[] Names = { "김영수", "이정호", "박상철", "최민석" };
        private readonly PatientVisit[] patients;
        private readonly DayRoutes routes;
        private int serial;
        private double time;
        public IReadOnlyList<PatientVisit> Patients { get; }
        public bool Paused { get; private set; }
        public int Departed { get; private set; }
        public int Income { get; private set; }
        public int Funds => StartingFunds + Income;
        public bool Complete => Departed == patients.Length;
        public int CtOwner => Owner(VisitStage.WalkingToCt, VisitStage.Ct);
        public int PlanOwner => Owner(VisitStage.Planning);
        public int TreatmentOwner => Owner(VisitStage.WalkingToTreatment, VisitStage.Treatment);
        public double Time => time;

        public HospitalDay(bool originalArt = true, int bookingCount = BookingCount)
        {
            if (bookingCount != BookingCount && bookingCount != 1) throw new ArgumentOutOfRangeException(nameof(bookingCount));
            routes = new DayRoutes(originalArt, bookingCount == 1);
            patients = new PatientVisit[bookingCount];
            for (int i = 0; i < patients.Length; i++) patients[i] = new PatientVisit(i + 1, Names[i]);
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

                var path = routes.For(patient.Id, patient.Stage);
                if (path != null)
                    Walk(patient, path, seconds);
                else if (patient.Duration > 0f)
                    AdvanceService(patient, seconds);
            }
            Dispatch();
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
                    break;
            }
        }

        private void Walk(PatientVisit patient, Vector2[] path, float seconds)
        {
            // A new reservation remains held while the previous patient clears the approach.
            if (patient.Stage == VisitStage.WalkingToTreatment && patient.Waypoint >= path.Length - 2 &&
                Array.Exists(patients, other => other.Stage == VisitStage.Leaving && other.Waypoint < 2)) return;
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
            if (TreatmentOwner == 0) AssignFirst(VisitStage.TreatmentQueue, VisitStage.WalkingToTreatment);
        }

        private void AssignFirst(VisitStage queued, VisitStage assigned)
        {
            PatientVisit first = null;
            foreach (var patient in patients)
                if (patient.Stage == queued && (first == null || patient.QueueOrder < first.QueueOrder))
                    first = patient;
            if (first != null) SetStage(first, assigned);
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
