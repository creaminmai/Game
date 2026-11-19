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
        StaffAndResearch();
        Guide();
        Region();
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

    static void StaffAndResearch()
    {
        var day = new HospitalDay();
        Verify(!day.SetAutoAdmission(true) && !day.SetAutoPlanning(true) && !day.PurchaseTraining() && !day.PurchaseLab(),
            "staff and research start locked");
        FinishDay(day);
        Verify(day.PurchaseExpansion() && day.StartNextDay(6) && day.SetAutoAdmission(true),
            "free automation after day one");
        var first = day.Patients[0];
        Until(day, () => first.Stage == VisitStage.Reception, "automatic admission candidate arrives");
        day.Tick(1);
        Verify(day.Admit(first.Id), "manual intake can beat the scheduled action");
        day.Tick(1);
        Verify(!day.Admit(first.Id) && !first.DelegatedAdmission, "manual intake cannot be paid or admitted twice");

        FinishWithDuties(day, manualPlanning: true);
        Verify(day.StartNextDay(4), "third day");
        FinishWithDuties(day, manualPlanning: true);
        Verify(day.ChapterTwo && day.PurchaseTraining() && !day.PurchaseTraining() && day.TrainingExpense == 500 &&
            !day.AutoPlanning && day.SetAutoPlanning(true), "one training charge and opt-in planning");
        Verify(day.StartNextDay(4), "delegated operating day");
        FinishWithDuties(day, manualPlanning: false);
        Verify(day.ChapterThree && day.DelegatedDepartures == 4 && day.PurchaseLab() && !day.PurchaseLab() &&
            day.ResearchPoints == 6 && day.LabExpense == 1800, "chapter three and laboratory charge");
        Verify(day.StartResearch(HospitalResearch.Ct) && day.ResearchPoints == 0 && day.ResearchExpense == 500 &&
            !day.StartResearch(HospitalResearch.Planning) && !day.StartResearch(HospitalResearch.Ct), "single research slot and immutable price");
        Verify(day.StartNextDay(6) && !day.ChapterFour && day.ResearchPoints == 0, "building after close earns no retroactive points");
        var patient = day.Patients[0];
        Until(day, () => patient.Stage == VisitStage.Ct, "admission automatically reaches CT");
        Verify(patient.Duration == 5, "pending research does not affect current visit");
        FinishWithDuties(day, manualPlanning: false);
        Verify(day.ResearchPoints == 4 && day.ResearchStatus(HospitalResearch.Ct).Contains("다음 날") && !day.ChapterFour,
            "one subsequent operating day completes research without applying early");
        Verify(day.StartNextDay(6) && day.ChapterFour, "completed CT research applies before arrivals");
        patient = day.Patients[0];
        Until(day, () => patient.Stage == VisitStage.Ct, "first visit after research");
        Verify(patient.Duration == 4 && patient.DelegatedAdmission, "CT research shortens the next service to four seconds");
        string folder = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "hospital-staff-" + Guid.NewGuid().ToString("N"));
        try
        {
            var store = new HospitalSave(System.IO.Path.Combine(folder, "day.bin"));
            day.Tick(1);
            store.Save(day);
            Verify(store.Load(true, out var loaded) == HospitalLoadResult.Loaded && loaded.AutoAdmission && loaded.AutoPlanning &&
                loaded.ChapterFour && loaded.ResearchPoints == 4 && loaded.TrainingDay == 3 && loaded.LabDay == 4 &&
                loaded.Patients[0].Duration == 4 && loaded.Patients[0].Elapsed == patient.Elapsed &&
                loaded.Funds == day.Funds, "staff, research, clock and active service survive save");
            loaded.TogglePause();
            FinishWithDuties(loaded, manualPlanning: false);
            Verify(loaded.ResearchPoints == 8 && loaded.StartResearch(HospitalResearch.Planning), "second project after first applied");
            Verify(loaded.StartNextDay(4), "planning research progress day");
            FinishWithDuties(loaded, manualPlanning: false);
            Verify(loaded.StartNextDay(4), "planning research application day");
            Until(loaded, () => loaded.Patients[0].Stage == VisitStage.Planning, "automatic planning after research");
            Verify(loaded.Patients[0].Duration == 4 && loaded.Patients[0].DelegatedPlan, "planning research shortens the next service");
        }
        finally
        {
            if (System.IO.Directory.Exists(folder)) System.IO.Directory.Delete(folder, true);
        }
    }

    static void FinishWithDuties(HospitalDay day, bool manualPlanning)
    {
        for (int i = 0; i < 15000 && !day.Complete; i++)
        {
            if (manualPlanning)
                foreach (var patient in day.Patients)
                    if (patient.Stage == VisitStage.AwaitingPlan) day.AssignPlan(patient.Id);
            day.Tick(.05f);
        }
        Verify(day.Complete, $"duties completed day {day.DayNumber}");
    }

    static void Region()
    {
        var late = new HospitalDay();
        for (int i = 0; i < HospitalDay.ClosingSecond + 1; i++) late.Tick(1);
        FinishDay(late);
        Verify(late.DepartedByClosing == 0 && !late.MetClosingTarget && late.Patients[0].Satisfaction < 85,
            "post-closing departures do not count and actual reception wait affects satisfaction");
        var ledger = new HospitalNetwork(new HospitalDay());
        var site = HospitalSite.Main;
        Verify(ledger.ApplyDecoration(0) && ledger.ApplyDecoration(7) && ledger.ApplyDecoration(0) &&
            ledger.ExpenseToday(site) == 170 && ledger.SharedExpenseToday == 170 && ledger.Funds == 730,
            "both decorations are dated, attributed and charged once");
        FinishDay(ledger.Main);
        Verify(ledger.SharedIncomeToday == 800 && ledger.Funds == 1530, "first-day reconciliation");
        Verify(ledger.StartStory(1), "first-day story unlocks from the actual completed day");
        ledger.AdvanceStory();
        using (var data = new System.IO.MemoryStream())
        {
            using (var writer = new System.IO.BinaryWriter(data, System.Text.Encoding.UTF8, true))
                ledger.WriteSave(writer);
            data.Position = 0;
            using var read = new System.IO.BinaryReader(data);
            var resumed = HospitalNetwork.ReadSave(read, true, 8);
            Verify(resumed.StoryMoment == 1 && resumed.StoryLine == 1 && resumed.Funds == 1530 &&
                resumed.ExpenseToday(site) == 170, "story and paid amounts round-trip");
            var bytes = data.ToArray();
            int ledgerOffset = bytes.Length - (26 * sizeof(int) * 2 + sizeof(int) * 4 + sizeof(byte) * 2);
            using (var legacyBytes = new System.IO.MemoryStream())
            {
                using (var legacyWriter = new System.IO.BinaryWriter(legacyBytes, System.Text.Encoding.UTF8, true))
                {
                    ledger.Main.WriteSave(legacyWriter, 6);
                    legacyWriter.Write(0); legacyWriter.Write(false); legacyWriter.Write(0);
                    legacyWriter.Write(0); legacyWriter.Write(0);
                    legacyWriter.Write(129); legacyWriter.Write(129);
                    for (int i = 0; i < 13; i++) legacyWriter.Write(0);
                }
                legacyBytes.Position = 0;
                using var oldReader = new System.IO.BinaryReader(legacyBytes);
                var legacyDecorations = HospitalNetwork.ReadSave(oldReader, true, 6);
                Verify(legacyDecorations.Funds == 1530 && legacyDecorations.ExpenseToday(site) == 0,
                    "legacy decor keeps its funds without inventing an operating date");
            }
            data.Position = ledgerOffset;
            using (var writer = new System.IO.BinaryWriter(data, System.Text.Encoding.UTF8, true))
                writer.Write(73);
            data.Position = 0;
            var priceChanged = HospitalNetwork.ReadSave(read, true, 8);
            Verify(priceChanged.Funds == 1537 && priceChanged.ExpenseToday(site) == 163 &&
                priceChanged.ApplyDecoration(0) && priceChanged.Funds == 1537,
                "a recorded purchase price different from the catalog survives load and reapplying the item");
        }
        ledger.AdvanceStory();
        Verify(ledger.NextStory == 0 && ledger.StartNextDay(4) && ledger.LastDay.Expense == 170 &&
            ledger.LastSharedExpense == 170 && ledger.ExpenseToday(site) == 0 && ledger.Funds == 1530,
            "dated expense rolls to last-day journal without charging again");
        var hq = new HospitalDay();
        var network = new HospitalNetwork(hq);
        Verify(!network.CanOpenBranch && !network.OpenBranch() && !network.Switch(true), "locked branch");
        FinishDay(hq);
        Verify(hq.PurchaseExpansion() && network.StartNextDay(6) && hq.SetAutoAdmission(true), "regional path: unlock expanded HQ");
        FinishWithDuties(hq, manualPlanning: true);
        Verify(network.StartNextDay(6), "regional path: grow visit count");
        FinishWithDuties(hq, manualPlanning: true);
        Verify(hq.PurchaseTraining() && hq.SetAutoPlanning(true) && network.StartNextDay(6), "regional path: delegate");
        FinishWithDuties(hq, manualPlanning: false);
        Verify(hq.PurchaseLab() && hq.StartResearch(HospitalResearch.Ct) && network.StartNextDay(6), "regional path: start research");
        FinishWithDuties(hq, manualPlanning: false);
        Verify(network.StartNextDay(6) && hq.ChapterFour && !network.OpenBranch(), "research alone does not unlock region");
        while (!network.CanOpenBranch && hq.DayNumber < 30)
        {
            FinishWithDuties(hq, manualPlanning: false);
            if (!network.CanOpenBranch) Verify(network.StartNextDay(6), "advance toward regional requirements");
        }
        int before = network.Funds;
        Verify(network.CanOpenBranch && network.OpenBranch() && !network.OpenBranch() && !network.Switch(true) &&
            network.Funds == before - HospitalNetwork.BranchCost && network.ExpenseToday(HospitalSite.Main) >= HospitalNetwork.BranchCost, "branch establishment charge once, opens at next rollover");

        string folder = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "hospital-region-" + Guid.NewGuid().ToString("N"));
        try
        {
            System.IO.Directory.CreateDirectory(folder);
            string legacyPath = System.IO.Path.Combine(folder, "legacy-v5.bin");
            using (var payload = new System.IO.MemoryStream())
            {
                using (var writer = new System.IO.BinaryWriter(payload, System.Text.Encoding.UTF8, true))
                {
                    writer.Write(0x484F5350);
                    writer.Write(5);
                    network.Main.WriteSave(writer);
                    writer.Write(network.BranchOpeningDay);
                    writer.Write(false);
                    writer.Write(0);
                    network.Branch.WriteSave(writer);
                }
                byte[] bytes = payload.ToArray();
                using var digest = System.Security.Cryptography.SHA256.Create();
                System.IO.File.WriteAllBytes(legacyPath, bytes.Concat(digest.ComputeHash(bytes)).ToArray());
            }
            var legacy = new HospitalSave(legacyPath);
            Verify(legacy.LoadNetwork(true, out var migrated) == HospitalLoadResult.Loaded && migrated.Branch != null &&
                migrated.Coast == null && migrated.Funds == network.Funds && migrated.BranchOpeningDay == network.BranchOpeningDay,
                "v5 two-hospital file migrates without changing finances or opening date");
            var store = new HospitalSave(System.IO.Path.Combine(folder, "region.bin"));
            network.DismissStory(true);
            store.SaveNetwork(network);
            Verify(store.LoadNetwork(true, out network) == HospitalLoadResult.Loaded && network.NextStory == 0 &&
                network.BranchOpeningDay == network.Main.DayNumber + 1 && !network.Switch(true), "pending opening and skipped story persist");
            Verify(network.StartNextDay(6) && network.Switch(true) && network.Active == network.Branch, "branch opens after rollover");
            network.Tick(1);
            Verify(network.Time == 0 && network.Main.Paused && network.Branch.Paused, "both hospitals load paused");
            network.TogglePause();
            for (int i = 0; i < 500 && network.Branch.Patients[0].Stage != VisitStage.Ct; i++) network.Tick(.05f);
            Verify(network.Branch.Patients[0].Stage == VisitStage.Ct && network.Branch.Patients[0].Duration == 4 &&
                network.Main.CtOwner == 1 && network.Branch.CtOwner == 1 && network.Main.Time == network.Branch.Time,
                "branch and HQ simulate independently with shared CT protocol and same clock");
            Verify(network.Branch.Patients[3].Stage != VisitStage.NotArrived &&
                network.Main.Patients[3].Stage == VisitStage.NotArrived, "branch books patients earlier");
            Verify(!network.StartNextDay(4), "cannot roll over while either hospital is operating");
            double time = network.Time;
            network.TogglePause();
            network.Switch(false);
            network.Tick(1);
            Verify(network.Time == time && network.Main.Paused && network.Branch.Paused, "view switching preserves pause");
            network.Switch(true);
            store.SaveNetwork(network);
            Verify(store.LoadNetwork(true, out var loaded) == HospitalLoadResult.Loaded && loaded.ViewingBranch &&
                loaded.Main.CtOwner == 1 && loaded.Branch.CtOwner == 1 && loaded.Branch.Patients[0].Duration == 4 &&
                loaded.Time == time && loaded.Funds == network.Funds, "v5 restores active hospital, independent owners and shared protocol");
            loaded.TogglePause();
            int openingFunds = loaded.Funds;
            var firstBranchPatient = loaded.Branch.Patients[0];
            for (int i = 0; i < 12000 && !(firstBranchPatient.Stage == VisitStage.Treatment && firstBranchPatient.Elapsed > 29.5f); i++)
                loaded.Tick(.05f);
            Verify(firstBranchPatient.Stage == VisitStage.Treatment && loaded.Branch.TreatmentOwner == 1 &&
                loaded.Branch.Rank(2) == 1 && loaded.Branch.Income == 0, "branch's first treatment holds its FIFO reservation before payment");
            store.SaveNetwork(loaded);
            Verify(store.LoadNetwork(true, out var boundary) == HospitalLoadResult.Loaded &&
                boundary.Branch.TreatmentOwner == 1 && boundary.Branch.Income == 0, "branch restores before payment");
            boundary.TogglePause();
            boundary.Tick(1);
            Verify(boundary.Branch.Income == 200 && boundary.Branch.TreatmentOwner == 2, "branch payment occurs once and dispatches FIFO successor");
            store.SaveNetwork(boundary);
            Verify(store.LoadNetwork(true, out loaded) == HospitalLoadResult.Loaded && loaded.Branch.Income == 200,
                "branch restores after payment");
            loaded.TogglePause();
            for (int i = 0; i < 12000 && !loaded.Complete; i++) loaded.Tick(.05f);
            Verify(loaded.Complete && loaded.Main.Departed == 6 && loaded.Branch.Departed == 4 &&
                loaded.Funds == openingFunds + 2000, "both independent schedules and all visit fees settle exactly once");
            store.SaveNetwork(loaded);
            Verify(store.LoadNetwork(true, out var settled) == HospitalLoadResult.Loaded &&
                settled.Complete && settled.Funds == loaded.Funds && !settled.OpenBranch(), "settled visits do not pay again after restore");
            Verify(settled.Branch.PurchaseExpansion() && !settled.Branch.PurchaseExpansion() && !settled.Main.PurchaseExpansion() &&
                settled.Funds == loaded.Funds - HospitalDay.ExpansionCost, "branch annex is a local capacity purchase with one shared charge");
            Verify(settled.StartNextDay(6) && settled.Main.Time == 0 && settled.Branch.Time == 0, "second shared day resets both clocks and bookings");
            settled.TogglePause();
            for (int i = 0; i < 12000 && !settled.Complete; i++) settled.Tick(.05f);
            Verify(settled.Complete && settled.BranchChapterComplete && settled.Branch.DualTreatment, "branch reaches eight departures and uses both rooms");
            Verify(!settled.CanOpenCoast && !settled.OpenCoast() && !settled.Main.StartResearch(HospitalResearch.EducationIII),
                "coast and education prerequisites enforced");
            int headquartersBefore = settled.Funds;
            Verify(settled.ApplyDecoration(0) && settled.ApplyDecoration(0) && settled.Funds == headquartersBefore - 80,
                "repeat decoration selection only bills once");
            Verify(settled.Switch(HospitalSite.Main) && !settled.Owns(0) && settled.Decorations == 0,
                "branch decorations never leak into headquarters");
            for (int i = 0; i < 65 && !settled.CanOpenCoast; i++)
            {
                foreach (var study in new[] { HospitalResearch.EducationI, HospitalResearch.EducationII, HospitalResearch.EducationIII })
                    if (settled.Main.CanStartResearch(study))
                    {
                        settled.Main.StartResearch(study);
                        break;
                    }
                if (settled.CanOpenCoast) break;
                if (!settled.StartNextDay(6)) throw new InvalidOperationException("Expected synchronized rollover");
                for (int step = 0; step < 12000 && !settled.Complete; step++) settled.Tick(.05f);
            }
            int coastBefore = settled.Funds;
            Verify(settled.Main.ResearchActive(HospitalResearch.EducationIII) && settled.Branch.IntakeDelay == 1 &&
                settled.CanOpenCoast && settled.OpenCoast() && !settled.OpenCoast() && settled.Funds == coastBefore - AlphaCatalog.CoastCost,
                "full education chain applies network-wide and coastal purchase charges once");
            Verify(!settled.Switch(HospitalSite.Coast) && settled.StartNextDay(6) && settled.Switch(HospitalSite.Coast),
                "coastal hospital is available from next operating day");
            for (int step = 0; step < 220; step++) settled.Tick(.05f);
            Verify(settled.Branch.Patients[3].Stage != VisitStage.NotArrived && settled.Coast.Patients[3].Stage == VisitStage.NotArrived &&
                settled.Coast.Time == settled.Branch.Time && settled.Coast.Site == HospitalSite.Coast,
                "third hospital ticks once and has a different booking pattern");
            store.SaveNetwork(settled);
            Verify(store.LoadNetwork(true, out var alpha) == HospitalLoadResult.Loaded && alpha.Site == HospitalSite.Coast &&
                alpha.Funds == settled.Funds && alpha.Coast.Time == settled.Coast.Time &&
                alpha.Switch(HospitalSite.Riverside) && alpha.Owns(0) && alpha.Decorations == 1 && alpha.LastDay.Departed == 4,
                "third hospital, site-specific decor and previous results restore");
            Verify(settled.CoordinationComplete && settled.JointClosingDays == 3, "three measured days precede coastal opening");
            bool sawReturn = false, coastAwarded = false;
            for (int date = 0; date < 20 && !settled.SeasonComplete; date++)
            {
                foreach (var project in new[] { HospitalResearch.Planning, HospitalResearch.CtII, HospitalResearch.PlanningII })
                    if (settled.Main.StartResearch(project)) break;
                var course = settled.Coast.Patients[0];
                if (course.CourseVisit >= 2)
                {
                    for (int tick = 0; tick < 800 && course.Stage < VisitStage.WalkingToTreatment; tick++)
                    {
                        settled.Tick(.05f);
                        VerifyReturnRoute(course);
                    }
                    sawReturn |= course.Stage == VisitStage.WalkingToTreatment;
                }
                for (int step = 0; step < 14000 && !settled.Complete; step++) settled.Tick(.05f);
                Verify(settled.Complete, "all sites close during season test");
                if (!settled.Coast.Expanded) settled.Coast.PurchaseExpansion();
                int beforeClose = settled.Funds;
                Verify(settled.StartNextDay(6), "season rolls into next day");
                if (!coastAwarded)
                {
                    Verify(settled.CoastalChapterComplete && settled.LastSeasonCredit == 3000 &&
                        settled.Funds == beforeClose + 3000, "first coastal close credits the milestone once");
                    coastAwarded = true;
                }
                else Verify(settled.LastSeasonCredit == 0 && settled.Funds == beforeClose, "coastal credit cannot repeat");
            }
            Verify(sawReturn && settled.SeasonComplete && settled.Main.CompletedResearchCount >= 6 &&
                settled.Main.CompletedCourses > 0 && settled.Branch.CompletedCourses > 0 && settled.Coast.CompletedCourses > 0,
                "season ending is earned from courses, applied research and actual satisfaction");
            var seasonalStore = new HospitalSave(System.IO.Path.Combine(folder, "season.bin"));
            Verify(settled.StartStory(64), "finale replay is available");
            settled.AdvanceStory();
            seasonalStore.SaveNetwork(settled);
            Verify(seasonalStore.LoadNetwork(true, out var ending) == HospitalLoadResult.Loaded && ending.SeasonComplete &&
                ending.StoryMoment == 64 && ending.StoryLine == 1 && ending.Funds == settled.Funds, "season and finale restore");
            store.Archive();
            Verify(System.IO.Directory.GetFiles(folder, "region.bin.previous-*").Length == 2, "new game archives primary and backup");
            var file = System.IO.Path.Combine(folder, "region.bin");
            byte[] corrupt = { 1, 2, 3 };
            System.IO.File.WriteAllBytes(file, corrupt);
            Verify(store.LoadNetwork(true, out _) == HospitalLoadResult.RecoveredBackup &&
                System.IO.File.ReadAllBytes(file).SequenceEqual(corrupt), "damaged network save preserves the primary and restores the backup");
        }
        finally
        {
            if (System.IO.Directory.Exists(folder)) System.IO.Directory.Delete(folder, true);
        }
    }

    static void VerifyReturnRoute(PatientVisit patient)
    {
        if (patient.Stage > VisitStage.Reception && patient.Stage < VisitStage.TreatmentQueue)
            throw new InvalidOperationException("Returning course repeated CT or planning.");
    }

    static void Guide()
    {
        var day = new HospitalDay();
        day.UpdateGuide(false);
        Verify(day.ActiveGuide == GuideMoment.Welcome, "first-day welcome");
        string folder = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "hospital-guide-" + Guid.NewGuid().ToString("N"));
        try
        {
            var store = new HospitalSave(System.IO.Path.Combine(folder, "day.bin"));
            store.Save(day);
            Verify(store.Load(true, out var restored) == HospitalLoadResult.Loaded && restored.ActiveGuide == GuideMoment.Welcome,
                "restore the currently open guide");
            restored.DismissGuide();
            restored.UpdateGuide(false);
            Verify(restored.ActiveGuide == GuideMoment.None, "completed welcome does not repeat");
            restored.TogglePause();
            Until(restored, () => restored.Patients[0].Stage == VisitStage.Reception, "guide selection arrival");
            restored.UpdateGuide(false);
            Verify(restored.ActiveGuide == GuideMoment.SelectPatient, "first selection prompts separately from admission");
            restored.DismissGuide();
            restored.UpdateGuide(true);
            Verify(restored.ActiveGuide == GuideMoment.None && restored.Admit(1), "guide selection does not admit the patient");
            Until(restored, () => restored.Patients[0].Stage == VisitStage.AwaitingPlan, "guide planning arrival");
            restored.UpdateGuide(true);
            Verify(restored.ActiveGuide == GuideMoment.ReviewPlan, "planning cue at correct state");
            restored.DismissGuide();
            restored.AssignPlan(1);
            Until(restored, () => restored.Patients[0].Paid, "guide first treatment");
            restored.UpdateGuide(true);
            Verify(restored.ActiveGuide == GuideMoment.FirstTreatment, "first treatment message once payment occurred");
            restored.DismissGuide();
            restored.UpdateGuide(true);
            Verify(restored.ActiveGuide == GuideMoment.Expansion, "growth prompt follows first treatment");
            Verify(restored.PurchaseExpansion(), "purchase while the expansion guide is open");
            restored.UpdateGuide(false);
            Verify(restored.ActiveGuide == GuideMoment.None, "completed purchase retires the open expansion guide");
            restored.SkipGuide();
            store.Save(restored);
            Verify(store.Load(true, out var skipped) == HospitalLoadResult.Loaded, "guide opt-out saved");
            skipped.UpdateGuide(false);
            Verify(skipped.ActiveGuide == GuideMoment.None, "guide opt-out survives restart");
        }
        finally
        {
            if (System.IO.Directory.Exists(folder)) System.IO.Directory.Delete(folder, true);
        }
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
