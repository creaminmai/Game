namespace SunshineHospital
{
    public enum VisitStage
    {
        Entering, Reception, WalkingToCt, Ct, WalkingToPlanning,
        AwaitingPlan, Planning, WalkingToTreatment, Treatment, Leaving, Complete
    }

    public sealed class PatientVisit
    {
        public const int StartingFunds = 900;
        public const int VisitFee = 200;
        public const float WalkSpeed = 2.1f;
        public VisitStage Stage { get; private set; }
        public bool Paused { get; private set; }
        public bool Paid { get; private set; }
        public float Elapsed { get; private set; }
        public int Funds => StartingFunds + (Paid ? VisitFee : 0);
        public bool CtReserved => Stage == VisitStage.WalkingToCt || Stage == VisitStage.Ct;
        public bool TreatmentReserved => Stage == VisitStage.WalkingToTreatment || Stage == VisitStage.Treatment;
        public float Duration => Stage switch
        {
            VisitStage.Ct => 5f,
            VisitStage.Planning => 5f,
            VisitStage.Treatment => 30f,
            _ => 0f
        };

        public void TogglePause() => Paused = !Paused;

        public bool Admit()
        {
            if (Paused || Stage != VisitStage.Reception) return false;
            Stage = VisitStage.WalkingToCt;
            return true;
        }

        public bool AssignPlan()
        {
            if (Paused || Stage != VisitStage.AwaitingPlan) return false;
            Stage = VisitStage.Planning;
            return true;
        }

        public void Arrive()
        {
            if (Paused) return;
            Stage = Stage switch
            {
                VisitStage.Entering => VisitStage.Reception,
                VisitStage.WalkingToCt => VisitStage.Ct,
                VisitStage.WalkingToPlanning => VisitStage.AwaitingPlan,
                VisitStage.WalkingToTreatment => VisitStage.Treatment,
                VisitStage.Leaving => VisitStage.Complete,
                _ => Stage
            };
        }

        public void Tick(float seconds)
        {
            if (Paused || seconds <= 0f || Duration == 0f) return;
            Elapsed += seconds;
            if (Elapsed < Duration) return;
            Elapsed = 0f;

            switch (Stage)
            {
                case VisitStage.Ct:
                    Stage = VisitStage.WalkingToPlanning;
                    break;
                case VisitStage.Planning:
                    Stage = VisitStage.WalkingToTreatment;
                    break;
                case VisitStage.Treatment:
                    Paid = true;
                    Stage = VisitStage.Leaving;
                    break;
            }
        }
    }
}
