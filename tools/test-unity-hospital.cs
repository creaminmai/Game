using System;
using System.Linq;
using System.Numerics;
using SunshineHospital;

static partial class Checks
{
    static int count;

    static void Verify(bool okay, string message)
    {
        if (!okay) throw new InvalidOperationException(message);
        count++;
    }

    static void Until(HospitalDay day, Func<bool> condition, string description)
    {
        for (int i = 0; i < 12000 && !condition(); i++) day.Tick(.05f);
        Verify(condition(), description);
    }

    static void Main()
    {
        FirstDay();
        OnePatient();
        Spacing(false);
        Spacing(true);
        AdditionalChecks();
        Growth();
        Console.WriteLine($"{count} hospital checks passed.");
    }

    static partial void AdditionalChecks();

    static void FirstDay()
    {
        var day = new HospitalDay();
        Verify(day.Funds == 900 && day.Patients.Count == 4, "starting funds and four bookings");
        for (int i = 2; i <= 4; i++)
        {
            int id = i;
            Until(day, () => day.Patients[id - 1].Stage != VisitStage.NotArrived, $"arrival {id}");
            Verify(Math.Abs(day.Time - (id - 1) * 6) <= .051, $"scheduled arrival {id}");
        }
        Until(day, () => day.Patients.All(p => p.Stage == VisitStage.Reception), "four reception bays reached");
        foreach (var patient in day.Patients)
            foreach (var other in day.Patients.Where(p => p.Id > patient.Id))
                Verify(Vector2.Distance(patient.Position, other.Position) >= .70f, $"distinct bays {patient.Id}/{other.Id}");

        int[] ctOrder = { 3, 1, 4, 2 };
        foreach (int id in ctOrder)
            Verify(day.Admit(id) && !day.Admit(id), $"admission claiming once {id}");
        Verify(day.CtOwner == 3 && day.Rank(1) == 1 && day.Rank(4) == 2 && day.Rank(2) == 3, "CT FIFO on enqueue");
        day.TogglePause();
        var start = day.Patients[2].Position;
        day.Tick(1);
        Verify(day.Patients[2].Position == start && day.Patients[2].Stage == VisitStage.WalkingToCt, "paused CT travel");
        day.TogglePause();
        foreach (int id in ctOrder)
        {
            Verify(day.CtOwner == id && day.Patients[id - 1].Stage == VisitStage.WalkingToCt, $"CT reserved before walking for {id}");
            Until(day, () => day.Patients[id - 1].Stage == VisitStage.Ct, $"CT entered {id}");
            Verify(day.CtOwner == id && day.Patients[id - 1].Elapsed == 0, "CT only times inside");
            Until(day, () => day.CtOwner != id, $"CT released {id}");
        }
        Until(day, () => day.Patients.All(p => p.Stage == VisitStage.AwaitingPlan), "four planning bays reached");

        int[] planOrder = { 2, 4, 1, 3 };
        foreach (int id in planOrder)
            Verify(day.AssignPlan(id) && !day.AssignPlan(id), $"plan assigned once {id}");
        Verify(day.PlanOwner == 2 && day.Rank(4) == 1 && day.Rank(1) == 2 && day.Rank(3) == 3, "planner FIFO");
        foreach (int id in planOrder)
        {
            Verify(day.PlanOwner == id, $"planner dispatch {id}");
            Until(day, () => day.PlanOwner != id, $"plan ends {id}");
        }
        Verify(day.TreatmentOwner == 2 && day.Rank(4) == 1 && day.Rank(1) == 2 && day.Rank(3) == 3, "treatment FIFO");
        int income = 0;
        foreach (int id in planOrder)
        {
            Verify(day.TreatmentOwner == id && day.Income == income, $"exclusive reservation and no early payment {id}");
            Until(day, () => day.Patients[id - 1].Stage == VisitStage.Treatment, $"on treatment couch {id}");
            Until(day, () => day.Patients[id - 1].Stage == VisitStage.Leaving, $"treatment finished {id}");
            income += 200;
            Verify(day.Income == income && !day.Complete, $"single payout and day waits for departure {id}");
        }
        Until(day, () => day.Complete, "day terminates after last departure");
        day.Tick(1);
        Verify(day.Departed == 4 && day.Funds == 1700 && day.Income == 800 && day.TreatmentOwner == 0, "final daily result");
    }

    static void Spacing(bool admitOnArrival)
    {
        var day = new HospitalDay();
        float clearance = float.MaxValue;
        for (int i = 0; i < 7500 && !day.Complete; i++)
        {
            foreach (var patient in day.Patients)
            {
                if (patient.Stage == VisitStage.Reception && (admitOnArrival || day.Time > 24)) day.Admit(patient.Id);
                if (patient.Stage == VisitStage.AwaitingPlan) day.AssignPlan(patient.Id);
            }
            day.Tick(.05f);
            foreach (var patient in day.Patients)
            foreach (var other in day.Patients)
            {
                if (patient.Id >= other.Id || !InRoom(patient) || !InRoom(other)) continue;
                clearance = Math.Min(clearance, Vector2.Distance(patient.Position, other.Position));
            }
        }
        Verify(day.Complete && clearance >= .69f, $"route spacing and eventual departure, immediate admission: {admitOnArrival} (minimum {clearance:F3})");
    }

    static bool InRoom(PatientVisit patient) => patient.Stage is not (VisitStage.Complete or VisitStage.NotArrived);

    static void Growth()
    {
        var day = new HospitalDay();
        Verify(!day.PurchaseExpansion() && day.Funds == 900 && !day.StartNextDay(4), "growth locked until actual events");
        var first = day.Patients[0];
        Until(day, () => first.Stage == VisitStage.Reception, "growth fixture reception");
        day.Admit(1);
        Until(day, () => first.Stage == VisitStage.AwaitingPlan, "growth fixture planning");
        day.AssignPlan(1);
        Until(day, () => first.Stage == VisitStage.Leaving, "first treatment opens expansion before departure");
        Verify(day.Funds == 1100 && day.PurchaseExpansion() && !day.PurchaseExpansion() && day.Funds == 500,
            "expansion charges 600 exactly once");
        Verify(day.Patients.Count == 4 && !day.StartNextDay(6), "cannot change today's bookings");
        FinishDay(day);
        Verify(day.ChapterOne && day.Income == 800 && day.ExpansionExpense == 600 && day.Funds == 1100, "first-day ledger with purchase");
        Verify(day.StartNextDay(6) && day.DayNumber == 2 && day.Funds == 1100 &&
            day.Income == 0 && day.ExpansionExpense == 0 && day.Departed == 0 &&
            day.CtOwner == 0 && day.PlanOwner == 0 && day.TreatmentOwnerAt(1) == 0, "six-visit new day resets daily state");
        FinishDay(day);
        Verify(day.DualTreatment && day.LifetimeDeparted == 10 && day.Income == 1200 && day.Funds == 2300 &&
            !day.ChapterTwo, "simultaneous care and all six receipts, chapter still needs 12");
        Verify(day.StartNextDay(4), "four visits remain selectable after annex");
        FinishDay(day);
        Verify(day.ChapterTwo && day.LifetimeDeparted == 14 && day.Funds == 3100, "chapter two uses recorded visits and dual care");
        string folder = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "hospital-growth-" + Guid.NewGuid().ToString("N"));
        try
        {
            var store = new HospitalSave(System.IO.Path.Combine(folder, "day.bin"));
            store.Save(day);
            Verify(store.Load(true, out var restored) == HospitalLoadResult.Loaded &&
                restored.DayNumber == 3 && restored.Expanded && restored.DualTreatment && restored.ChapterTwo && restored.Funds == 3100 &&
                !restored.PurchaseExpansion(), "growth save restores date, ledger, chapters and paid expansion");
        }
        finally
        {
            if (System.IO.Directory.Exists(folder)) System.IO.Directory.Delete(folder, true);
        }
    }

    static void FinishDay(HospitalDay day)
    {
        for (int frame = 0; frame < 12000 && !day.Complete; frame++)
        {
            foreach (var patient in day.Patients)
            {
                if (patient.Stage == VisitStage.Reception) day.Admit(patient.Id);
                if (patient.Stage == VisitStage.AwaitingPlan) day.AssignPlan(patient.Id);
            }
            day.Tick(.05f);
        }
        Verify(day.Complete && day.Departed == day.Patients.Count, "everyone departed before closing");
    }

    static void OnePatient()
    {
        var day = new HospitalDay(bookingCount: 1);
        var patient = day.Patients[0];
        Until(day, () => patient.Stage == VisitStage.Reception, "single reception");
        Verify(day.Admit(1), "single admission");
        Until(day, () => patient.Stage == VisitStage.Ct, "single CT");
        for (int i = 0; i < 99; i++) day.Tick(.05f);
        Verify(patient.Stage == VisitStage.Ct && patient.Elapsed > 4.94f, "CT before five seconds");
        day.Tick(.05f);
        Verify(patient.Stage == VisitStage.WalkingToPlanning, "CT five-second boundary");
        Until(day, () => patient.Stage == VisitStage.AwaitingPlan, "single plan ready");
        Verify(day.AssignPlan(1), "single plan");
        for (int i = 0; i < 99; i++) day.Tick(.05f);
        Verify(patient.Stage == VisitStage.Planning, "plan before five seconds");
        day.Tick(.05f);
        Verify(patient.Stage == VisitStage.WalkingToTreatment, "plan five-second boundary");
        Until(day, () => patient.Stage == VisitStage.Treatment, "single treatment");
        for (int i = 0; i < 599; i++) day.Tick(.05f);
        Verify(patient.Stage == VisitStage.Treatment && day.Funds == 900, "treatment before 30 seconds");
        day.TogglePause();
        float elapsed = patient.Elapsed;
        day.Tick(1);
        Verify(patient.Elapsed == elapsed && !day.AssignPlan(1), "pause preserves treatment timer and gates actions");
        day.TogglePause();
        day.Tick(.05f);
        Verify(patient.Stage == VisitStage.Leaving && day.Funds == 1100, "treatment pays at 30 seconds");
        Until(day, () => day.Complete, "single departure");
        Verify(day.Funds == 1100 && !day.Admit(1), "single reward retained");
    }
}
