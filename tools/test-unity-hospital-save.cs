using System;
using System.IO;
using System.Linq;
using SunshineHospital;

static partial class Checks
{
    static partial void AdditionalChecks()
    {
        string directory = Path.Combine(Path.GetTempPath(), "sunshine-save-qa-" + Guid.NewGuid().ToString("N"));
        string path = Path.Combine(directory, "first-day.bin");
        var store = new HospitalSave(path);
        try
        {
            Verify(store.Load(true, out _) == HospitalLoadResult.Missing, "missing save");
            var day = new HospitalDay();
            store.Save(day);
            Verify(store.Load(true, out var initial) == HospitalLoadResult.Loaded &&
                initial.Paused && initial.Patients[0].Stage == VisitStage.Entering &&
                initial.Patients[3].Stage == VisitStage.NotArrived, "initial clock and pending appointments restore");
            Verify(store.Load(false, out _) == HospitalLoadResult.Unreadable, "mismatched route layout rejected");

            Until(day, () => day.Patients.All(p => p.Stage == VisitStage.Reception), "all booked patients arrived");
            foreach (int id in new[] { 2, 4, 1, 3 }) day.Admit(id);
            day.Tick(.65f);
            store.Save(day);
            Verify(store.Load(true, out var moving) == HospitalLoadResult.Loaded, "mid-travel snapshot loads");
            Verify(moving.Time == day.Time && moving.CtOwner == 2 && moving.Rank(4) == 1 && moving.Rank(3) == 3 &&
                moving.Patients[1].Position == day.Patients[1].Position, "clock, route, reservation and FIFO restored");
            moving.Tick(1);
            Verify(moving.Paused && moving.Time == day.Time && !moving.Admit(3), "restore starts paused");
            moving.TogglePause();
            Until(moving, () => moving.Patients[1].Stage == VisitStage.AwaitingPlan, "restored trip and CT finish");
            Verify(moving.AssignPlan(2), "restored game can assign planning");
            Until(moving, () => moving.Patients[1].Stage == VisitStage.Treatment, "restored game starts treatment");
            while (moving.Patients[1].Elapsed < 29.90f) moving.Tick(.05f);
            Verify(moving.Income == 0 && moving.Funds == 900, "no money just before treatment boundary");

            store.Save(moving);
            Verify(store.Load(true, out var before) == HospitalLoadResult.Loaded && before.TreatmentOwner == 2 &&
                before.Patients[1].Elapsed == moving.Patients[1].Elapsed, "treatment owner and exact elapsed restore");
            before.TogglePause();
            Until(before, () => before.Patients[1].Stage == VisitStage.Leaving, "restored completion before payment");
            Verify(before.Funds == 1100 && before.Income == 200 && before.Departed == 0, "pays once just before departure");
            store.Save(before);
            Verify(store.Load(true, out var after) == HospitalLoadResult.Loaded && after.Funds == 1100 &&
                after.Patients[1].Paid && after.TreatmentOwner == 0, "completion restores after payment");
            after.TogglePause();
            Until(after, () => after.Patients[1].Stage == VisitStage.Complete, "restored paid patient departs");
            Verify(after.Funds == 1100 && after.Departed == 1, "post-payment reload cannot pay twice");

            var fullQueue = new HospitalDay();
            Until(fullQueue, () => fullQueue.Patients.All(p => p.Stage == VisitStage.Reception), "queue test admissions opened");
            foreach (var patient in fullQueue.Patients) fullQueue.Admit(patient.Id);
            Until(fullQueue, () => fullQueue.Patients.All(p => p.Stage == VisitStage.AwaitingPlan), "queue test planning bays reached");
            foreach (int id in new[] { 4, 2, 3, 1 }) fullQueue.AssignPlan(id);
            store.Save(fullQueue);
            Verify(store.Load(true, out var planner) == HospitalLoadResult.Loaded && planner.PlanOwner == 4 &&
                planner.Rank(2) == 1 && planner.Rank(1) == 3, "planner owner and queue restored");
            Until(fullQueue, () => fullQueue.Patients.Count(p => p.Stage == VisitStage.TreatmentQueue) == 3,
                "three visits wait behind reserved treatment");
            store.Save(fullQueue);
            Verify(store.Load(true, out var treatment) == HospitalLoadResult.Loaded && treatment.TreatmentOwner == 4 &&
                treatment.Rank(2) == 1 && treatment.Rank(1) == 3, "treatment owner and FIFO restored");
            treatment.TogglePause();
            Until(treatment, () => treatment.Complete, "restored treatment queue finishes the day");
            Verify(treatment.Funds == 1700 && treatment.Income == 800 && treatment.Departed == 4, "restored final daily result");
            store.Save(treatment);
            Verify(store.Load(true, out var completed) == HospitalLoadResult.Loaded && completed.Complete && completed.Funds == 1700,
                "completed day persists without reopening the queues");

            File.WriteAllBytes(path + ".pending-interrupted", new byte[] { 8, 9 });
            Verify(store.Load(true, out var interrupted) == HospitalLoadResult.Loaded && interrupted.Complete,
                "uncommitted temporary write ignored");
            byte[] damaged = File.ReadAllBytes(path);
            damaged[17] ^= 0x5a;
            File.WriteAllBytes(path, damaged);
            Verify(store.Load(true, out var backup) == HospitalLoadResult.RecoveredBackup && backup.TreatmentOwner == 4,
                "checksum failure restores last valid backup");
            Verify(File.ReadAllBytes(path).SequenceEqual(damaged), "loading leaves damaged primary untouched");
            store.Save(completed);
            Verify(Directory.GetFiles(directory, "first-day.bin.unreadable-*").Any(file => File.ReadAllBytes(file).SequenceEqual(damaged)),
                "explicit save preserves damaged primary as separate copy");
            Verify(store.Load(true, out var recovered) == HospitalLoadResult.Loaded && recovered.Complete,
                "explicit save installs a valid primary over preserved damage");
        }
        finally
        {
            if (Directory.Exists(directory)) Directory.Delete(directory, recursive: true);
        }
    }
}
