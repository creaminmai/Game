using System;
using System.Collections.Generic;
using System.IO;
using System.Numerics;
using System.Security.Cryptography;

namespace SunshineHospital
{
    public enum HospitalLoadResult { Missing, Loaded, RecoveredBackup, Unreadable }

    public sealed class HospitalSave
    {
        private const int Magic = 0x484F5350;
        private const int Version = 4;
        private const int NetworkVersion = 8;
        private const int DigestSize = 32;
        private const int MaxSaveSize = 4096;
        private readonly string path;

        public HospitalSave(string path) => this.path = Path.GetFullPath(path);

        public void Archive()
        {
            if (!File.Exists(path) && !File.Exists(path + ".bak")) return;
            string archive = path + ".previous-" + Guid.NewGuid().ToString("N");
            if (File.Exists(path)) File.Copy(path, archive);
            if (File.Exists(path + ".bak")) File.Copy(path + ".bak", archive + ".bak");
        }

        public void Save(HospitalDay day) => Write(Version, day.OriginalArt, writer => day.WriteSave(writer));

        public void SaveNetwork(HospitalNetwork network) => Write(NetworkVersion, network.Main.OriginalArt, network.WriteSave);

        private void Write(int version, bool originalArt, Action<BinaryWriter> write)
        {
            byte[] payload;
            using (var memory = new MemoryStream())
            {
                using (var writer = new BinaryWriter(memory, System.Text.Encoding.UTF8, leaveOpen: true))
                {
                    writer.Write(Magic);
                    writer.Write(version);
                    write(writer);
                }
                payload = memory.ToArray();
            }

            Directory.CreateDirectory(Path.GetDirectoryName(path));
            string temp = path + ".pending-" + Guid.NewGuid().ToString("N");
            try
            {
                using (var file = new FileStream(temp, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                {
                    file.Write(payload, 0, payload.Length);
                    byte[] digest = Digest(payload, payload.Length);
                    file.Write(digest, 0, digest.Length);
                    file.Flush(true);
                }

                if (!File.Exists(path))
                {
                    File.Move(temp, path);
                }
                else if (TryRead(path, originalArt, out _))
                {
                    File.Replace(temp, path, path + ".bak");
                }
                else
                {
                    // Preserve the damaged or unknown-version primary and the last valid backup.
                    string preserved = path + ".unreadable-" + Guid.NewGuid().ToString("N");
                    File.Copy(path, preserved);
                    File.Replace(temp, path, null);
                }
            }
            finally
            {
                if (File.Exists(temp)) File.Delete(temp);
            }
        }

        public HospitalLoadResult Load(bool originalArt, out HospitalDay day)
        {
            var result = LoadNetwork(originalArt, out var network);
            day = network?.Main;
            if (day != null) day.SpendingLimit = null;
            return result;
        }

        public HospitalLoadResult LoadNetwork(bool originalArt, out HospitalNetwork day)
        {
            string backup = path + ".bak";
            if (TryRead(path, originalArt, out day)) return HospitalLoadResult.Loaded;
            if (TryRead(backup, originalArt, out day)) return HospitalLoadResult.RecoveredBackup;
            return File.Exists(path) || File.Exists(backup) ? HospitalLoadResult.Unreadable : HospitalLoadResult.Missing;
        }

        private static bool TryRead(string file, bool originalArt, out HospitalNetwork day)
        {
            day = null;
            if (!File.Exists(file)) return false;
            try
            {
                using var stream = new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.Read);
                if (stream.Length <= DigestSize || stream.Length > MaxSaveSize) return false;
                using var reader = new BinaryReader(stream);
                byte[] bytes = reader.ReadBytes((int)stream.Length);
                int length = bytes.Length - DigestSize;
                if (length < 8) return false;
                byte[] digest = Digest(bytes, length);
                for (int i = 0; i < digest.Length; i++)
                    if (bytes[length + i] != digest[i]) return false;

                using var payload = new MemoryStream(bytes, 0, length, writable: false);
                using var data = new BinaryReader(payload);
                if (data.ReadInt32() != Magic) return false;
                int version = data.ReadInt32();
                if (version < 1 || version > NetworkVersion) return false;
                var restored = version >= 5 ? HospitalNetwork.ReadSave(data, originalArt, version)
                    : new HospitalNetwork(HospitalDay.ReadSave(data, originalArt, version));
                if (payload.Position != payload.Length) return false;
                day = restored;
                return true;
            }
            catch (Exception error) when (error is IOException or UnauthorizedAccessException or InvalidDataException)
            {
                return false;
            }
        }

        private static byte[] Digest(byte[] bytes, int count)
        {
            using var hash = SHA256.Create();
            return hash.ComputeHash(bytes, 0, count);
        }
    }

    public sealed partial class HospitalDay
    {
        internal bool OriginalArt { get; }

        internal void WriteSave(BinaryWriter writer, int version = 4)
        {
            if (patients.Length == 1) throw new InvalidOperationException("A one-patient QA run cannot be saved.");
            writer.Write(OriginalArt);
            writer.Write(DayNumber);
            writer.Write(patients.Length);
            writer.Write(OpeningFunds);
            writer.Write(ExpansionExpense);
            writer.Write(LifetimePaid);
            writer.Write(Expanded);
            writer.Write(DualTreatment);
            WriteStaffResearch(writer, version);
            WriteGuide(writer, version);
            writer.Write(time);
            writer.Write(serial);
            writer.Write(Income);
            writer.Write(Departed);
            if (version >= 8)
            {
                writer.Write(DepartedByClosing);
                writer.Write(CoursesEnabled);
                writer.Write(CourseProgress);
                writer.Write(CompletedCourses);
            }
            foreach (var patient in patients)
            {
                writer.Write((int)patient.Stage);
                writer.Write(patient.Position.X);
                writer.Write(patient.Position.Y);
                writer.Write(patient.Heading.X);
                writer.Write(patient.Heading.Y);
                writer.Write(patient.ServiceTime);
                writer.Write(patient.Waypoint);
                writer.Write(patient.QueueOrder);
                writer.Write(patient.TreatmentRoom);
                writer.Write(patient.PlanPriority);
                writer.Write(patient.DelegatedAdmission);
                writer.Write(patient.DelegatedPlan);
                if (version >= 8)
                {
                    writer.Write(patient.CourseVisit);
                    writer.Write(patient.WaitSeconds);
                }
            }
        }

        internal static HospitalDay ReadSave(BinaryReader reader, bool originalArt, int version, HospitalDay researchSource = null, HospitalSite site = HospitalSite.Main)
        {
            if (reader.ReadBoolean() != originalArt) throw new InvalidDataException("Different route layout.");
            var day = new HospitalDay(originalArt, site: researchSource != null && site == HospitalSite.Main ? HospitalSite.Riverside : site) { ResearchSource = researchSource };
            if (version >= 2)
            {
                day.DayNumber = reader.ReadInt32();
                int count = reader.ReadInt32();
                day.OpeningFunds = reader.ReadInt32();
                day.ExpansionExpense = reader.ReadInt32();
                day.LifetimePaid = reader.ReadInt32();
                day.Expanded = reader.ReadBoolean();
                day.DualTreatment = reader.ReadBoolean();
                if (day.DayNumber < 1 || day.DayNumber > 1000000 ||
                    (count != BookingCount && (count != AnnexBookingCount || !day.Expanded || day.DayNumber == 1)) ||
                    (day.ExpansionExpense != 0 && (day.ExpansionExpense != ExpansionCost || !day.Expanded)) ||
                    (day.DualTreatment && !day.Expanded))
                    throw new InvalidDataException("Inconsistent hospital growth state.");
                day.ResetPatients(count);
            }
            if (version >= 3) day.ReadStaffResearch(reader, version);
            if (version >= 4) day.ReadGuide(reader, version);
            else day.SkipGuide();
            day.time = reader.ReadDouble();
            day.serial = reader.ReadInt32();
            day.Income = reader.ReadInt32();
            day.Departed = reader.ReadInt32();
            day.DepartedByClosing = version >= 8 ? reader.ReadInt32() : day.time <= ClosingSecond ? day.Departed : 0;
            if (version >= 8)
            {
                day.CoursesEnabled = reader.ReadBoolean();
                day.CourseProgress = reader.ReadInt32();
                day.CompletedCourses = reader.ReadInt32();
                if (day.CourseProgress < 0 || day.CourseProgress > 2 || day.CompletedCourses < 0 ||
                    day.CompletedCourses > day.DayNumber / 3 || (!day.CoursesEnabled && (day.CourseProgress != 0 || day.CompletedCourses != 0)))
                    throw new InvalidDataException("Invalid course ledger.");
            }
            if (day.DepartedByClosing < 0 || day.DepartedByClosing > day.Departed ||
                (day.time <= ClosingSecond && day.DepartedByClosing != day.Departed))
                throw new InvalidDataException("Invalid closing-time totals.");
            day.Paused = true;
            if (version < 3) day.lastResearchClose = day.Complete ? day.DayNumber : day.DayNumber - 1;
            if (version == 1) day.LifetimePaid = day.Income / VisitFee;
            if (!(day.time >= 0 && day.time < double.MaxValue) || day.serial < 0 || day.serial > day.patients.Length * 3)
                throw new InvalidDataException("Invalid day clock or queue sequence.");

            var queueOrders = new HashSet<int>();
            int paid = 0, departed = 0, ct = 0, planner = 0;
            var treatment = new int[day.Expanded ? 2 : 1];
            foreach (var patient in day.patients)
            {
                int value = reader.ReadInt32();
                if (value < (int)VisitStage.NotArrived || value > (int)VisitStage.Complete)
                    throw new InvalidDataException("Unknown patient state.");

                patient.Stage = (VisitStage)value;
                patient.Duration = day.ActiveServiceDuration(patient.Stage);
                patient.Position = new Vector2(reader.ReadSingle(), reader.ReadSingle());
                patient.Heading = new Vector2(reader.ReadSingle(), reader.ReadSingle());
                patient.ServiceTime = reader.ReadDouble();
                patient.Waypoint = reader.ReadInt32();
                patient.QueueOrder = reader.ReadInt32();
                bool usedRoom = patient.Stage >= VisitStage.WalkingToTreatment;
                patient.TreatmentRoom = version >= 2 ? reader.ReadInt32() : usedRoom ? 0 : -1;
                if (usedRoom ? patient.TreatmentRoom < 0 || patient.TreatmentRoom >= treatment.Length : patient.TreatmentRoom != -1)
                    throw new InvalidDataException("Invalid treatment room.");

                if (version >= 3)
                {
                    patient.PlanPriority = reader.ReadInt32();
                    patient.DelegatedAdmission = reader.ReadBoolean();
                    patient.DelegatedPlan = reader.ReadBoolean();
                    if (patient.PlanPriority < 0 || patient.PlanPriority > day.patients.Length * 3 ||
                        (patient.DelegatedAdmission && ((day.DayNumber < 2 && !day.regional) || patient.Stage < VisitStage.CtQueue)) ||
                        (patient.DelegatedPlan && ((day.TrainingDay == 0 && !day.regional) || patient.Stage < VisitStage.PlanQueue)))
                        throw new InvalidDataException("Invalid delegated visit.");
                }
                else if (patient.Stage >= VisitStage.CtQueue) patient.PlanPriority = patient.Id;

                if (version >= 8)
                {
                    patient.CourseVisit = reader.ReadInt32();
                    patient.WaitSeconds = reader.ReadDouble();
                    if (patient.CourseVisit < 0 || patient.CourseVisit > 3 ||
                        (patient.CourseVisit > 0 && (!day.CoursesEnabled || patient.Id != 1)) ||
                        !(patient.WaitSeconds >= 0 && patient.WaitSeconds <= day.time + .01) ||
                        (patient.CourseVisit >= 2 && patient.Stage > VisitStage.Reception && patient.Stage < VisitStage.TreatmentQueue))
                        throw new InvalidDataException("Invalid return booking.");
                    if (day.CoursesEnabled && patient.Id <= 4)
                    {
                        var first = day.patients[0];
                        int cohort = day.CompletedCourses - (first.CourseVisit == 3 && first.Stage == VisitStage.Complete ? 1 : 0);
                        patient.Name = Names[(patient.Id - 1 + Math.Max(0, cohort)) % 4];
                    }
                }

                float headingLength = patient.Heading.LengthSquared();
                if (!(Math.Abs(patient.Position.X) <= 20 && Math.Abs(patient.Position.Y) <= 20 && headingLength > .98f && headingLength < 1.02f))
                    throw new InvalidDataException("Invalid patient pose.");

                bool arrived = day.time + .000001 >= day.ArrivalAt(patient.Id);
                if (arrived == (patient.Stage == VisitStage.NotArrived))
                    throw new InvalidDataException("Patient arrival contradicts the clock.");

                if (!(patient.ServiceTime >= 0 && (patient.Duration == 0 ? patient.ServiceTime == 0 : patient.ServiceTime < patient.Duration)))
                    throw new InvalidDataException("Invalid service timer.");

                int routeLength = day.routes.For(patient.Id, patient.Stage, patient.TreatmentRoom, patient.CourseVisit >= 2)?.Length ?? 1;
                if (patient.Waypoint < 0 || patient.Waypoint >= routeLength)
                    throw new InvalidDataException("Invalid route checkpoint.");

                if (IsQueue(patient.Stage))
                {
                    if (patient.QueueOrder <= 0 || patient.QueueOrder > day.serial || !queueOrders.Add(patient.QueueOrder))
                        throw new InvalidDataException("Invalid FIFO sequence.");
                }
                else if (patient.QueueOrder != 0)
                {
                    throw new InvalidDataException("Queue sequence on a patient outside the queue.");
                }

                if (patient.Paid) paid++;
                if (patient.Stage == VisitStage.Complete) departed++;
                if (patient.Stage is VisitStage.Ct or VisitStage.WalkingToCt) ct++;
                if (patient.Stage == VisitStage.Planning) planner++;
                if (patient.Stage is VisitStage.Treatment or VisitStage.WalkingToTreatment) treatment[patient.TreatmentRoom]++;
            }

            int pastPaid = day.LifetimePaid - paid;
            if (day.Income != paid * VisitFee || day.Departed != departed ||
                pastPaid < (day.DayNumber - 1) * BookingCount || pastPaid > (day.DayNumber - 1) * AnnexBookingCount ||
                day.OpeningFunds != StartingFunds + pastPaid * VisitFee - (day.Expanded ? ExpansionCost - day.ExpansionExpense : 0) - day.PastStaffResearchExpense ||
                day.Funds < 0 || (day.Expanded && day.LifetimePaid == 0) ||
                ct > 1 || planner > 1 || Array.Exists(treatment, count => count > 1) ||
                !day.QueueHasOwner(VisitStage.CtQueue, ct == 1) || !day.QueueHasOwner(VisitStage.PlanQueue, planner == 1) ||
                !day.QueueHasOwner(VisitStage.TreatmentQueue, Array.TrueForAll(treatment, count => count == 1)))
                throw new InvalidDataException("Facility or income state is inconsistent.");
            day.ValidateStaffResearch();
            return day;
        }

        private bool QueueHasOwner(VisitStage stage, bool allOwnersBusy) =>
            allOwnersBusy || !Array.Exists(patients, patient => patient.Stage == stage);
    }
}
