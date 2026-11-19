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
        private const int Version = 1;
        private const int DigestSize = 32;
        private const int MaxSaveSize = 4096;
        private readonly string path;

        public HospitalSave(string path) => this.path = Path.GetFullPath(path);

        public void Save(HospitalDay day)
        {
            byte[] payload;
            using (var memory = new MemoryStream())
            {
                using (var writer = new BinaryWriter(memory, System.Text.Encoding.UTF8, leaveOpen: true))
                {
                    writer.Write(Magic);
                    writer.Write(Version);
                    day.WriteSave(writer);
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
                else if (TryRead(path, day.OriginalArt, out _))
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
            string backup = path + ".bak";
            if (TryRead(path, originalArt, out day)) return HospitalLoadResult.Loaded;
            if (TryRead(backup, originalArt, out day)) return HospitalLoadResult.RecoveredBackup;
            return File.Exists(path) || File.Exists(backup) ? HospitalLoadResult.Unreadable : HospitalLoadResult.Missing;
        }

        private static bool TryRead(string file, bool originalArt, out HospitalDay day)
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
                if (data.ReadInt32() != Magic || data.ReadInt32() != Version) return false;
                var restored = HospitalDay.ReadSave(data, originalArt);
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

        internal void WriteSave(BinaryWriter writer)
        {
            if (patients.Length != BookingCount) throw new InvalidOperationException("Only the first-day game can be saved.");
            writer.Write(OriginalArt);
            writer.Write(time);
            writer.Write(serial);
            writer.Write(Income);
            writer.Write(Departed);
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
            }
        }

        internal static HospitalDay ReadSave(BinaryReader reader, bool originalArt)
        {
            if (reader.ReadBoolean() != originalArt) throw new InvalidDataException("Different route layout.");
            var day = new HospitalDay(originalArt)
            {
                time = reader.ReadDouble(),
                serial = reader.ReadInt32(),
                Income = reader.ReadInt32(),
                Departed = reader.ReadInt32(),
                Paused = true
            };
            if (!(day.time >= 0 && day.time < double.MaxValue) || day.serial < 0 || day.serial > BookingCount * 3)
                throw new InvalidDataException("Invalid day clock or queue sequence.");

            var queueOrders = new HashSet<int>();
            int paid = 0, departed = 0, ct = 0, planner = 0, treatment = 0;
            foreach (var patient in day.patients)
            {
                int value = reader.ReadInt32();
                if (value < (int)VisitStage.NotArrived || value > (int)VisitStage.Complete)
                    throw new InvalidDataException("Unknown patient state.");

                patient.Stage = (VisitStage)value;
                patient.Position = new Vector2(reader.ReadSingle(), reader.ReadSingle());
                patient.Heading = new Vector2(reader.ReadSingle(), reader.ReadSingle());
                patient.ServiceTime = reader.ReadDouble();
                patient.Waypoint = reader.ReadInt32();
                patient.QueueOrder = reader.ReadInt32();

                float headingLength = patient.Heading.LengthSquared();
                if (!(Math.Abs(patient.Position.X) <= 20 && Math.Abs(patient.Position.Y) <= 20 && headingLength > .98f && headingLength < 1.02f))
                    throw new InvalidDataException("Invalid patient pose.");

                bool arrived = day.time + .000001 >= (patient.Id - 1) * ArrivalInterval;
                if (arrived == (patient.Stage == VisitStage.NotArrived))
                    throw new InvalidDataException("Patient arrival contradicts the clock.");

                if (!(patient.ServiceTime >= 0 && (patient.Duration == 0 ? patient.ServiceTime == 0 : patient.ServiceTime < patient.Duration)))
                    throw new InvalidDataException("Invalid service timer.");

                int routeLength = day.routes.For(patient.Id, patient.Stage)?.Length ?? 1;
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
                if (patient.Stage is VisitStage.Treatment or VisitStage.WalkingToTreatment) treatment++;
            }

            if (day.Income != paid * VisitFee || day.Departed != departed || ct > 1 || planner > 1 || treatment > 1 ||
                !day.QueueHasOwner(VisitStage.CtQueue, ct) || !day.QueueHasOwner(VisitStage.PlanQueue, planner) ||
                !day.QueueHasOwner(VisitStage.TreatmentQueue, treatment))
                throw new InvalidDataException("Facility or income state is inconsistent.");
            return day;
        }

        private bool QueueHasOwner(VisitStage stage, int owners) =>
            owners == 1 || !Array.Exists(patients, patient => patient.Stage == stage);
    }
}
