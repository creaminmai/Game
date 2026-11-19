using System;
using System.IO;

namespace SunshineHospital
{
    public sealed class HospitalNetwork
    {
        public const int BranchCost = 9000;
        public const int RequiredReputation = 40;
        private const int InitialReputation = 10;

        public HospitalDay Main { get; }
        public HospitalDay Branch { get; private set; }
        public bool ViewingBranch { get; private set; }
        public HospitalDay Active => ViewingBranch ? Branch : Main;
        public bool Complete => Main.Complete && (Branch?.Complete ?? true);
        public double Time => Math.Max(Main.Time, Branch?.Time ?? 0);
        public int BranchOpeningDay { get; private set; }
        public int Funds => Main.Funds + (Branch == null ? 0 : Branch.Funds - HospitalDay.StartingFunds - BranchCost);
        public int Reputation => Math.Min(100, InitialReputation + Main.DayNumber - 1 + (Main.Complete ? 1 : 0)
            + (Main.ChapterOne ? 3 : 0) + (Main.ChapterTwo ? 3 : 0) + (Main.ChapterThree ? 3 : 0) + (Main.ChapterFour ? 3 : 0));
        public bool BranchChapterComplete => Branch != null && Branch.LifetimeDeparted >= 8;
        public bool DelegationReady => Main.TrainingDay != 0 && Main.AutoAdmission && Main.AutoPlanning;
        public bool CanOpenBranch => Branch == null && Main.ChapterFour && DelegationReady &&
            Reputation >= RequiredReputation && Funds >= BranchCost && Main.Complete;
        private int storySeen;

        public HospitalNetwork(HospitalDay main)
        {
            Main = main;
            Main.SpendingLimit = () => Funds;
        }

        public bool OpenBranch()
        {
            if (!CanOpenBranch) return false;
            BranchOpeningDay = Main.DayNumber + 1;
            AttachBranch(new HospitalDay(Main.OriginalArt, regional: true));
            return true;
        }

        private void AttachBranch(HospitalDay branch)
        {
            Branch = branch;
            Branch.SkipGuide();
            Branch.SpendingLimit = () => Funds;
            if (Branch.Paused != Main.Paused) Branch.TogglePause();
            Branch.ResearchSource = Main;
        }

        public bool Switch(bool branch)
        {
            if (branch && (Branch == null || Main.DayNumber < BranchOpeningDay)) return false;
            ViewingBranch = branch;
            return true;
        }

        public void Tick(float seconds)
        {
            if (Active.Paused) return;
            Main.Tick(seconds);
            if (Branch != null && Main.DayNumber >= BranchOpeningDay) Branch.Tick(seconds);
        }

        public void TogglePause()
        {
            Main.TogglePause();
            Branch?.TogglePause();
        }

        public bool StartNextDay(int mainBookings)
        {
            bool opening = Branch != null && Main.DayNumber < BranchOpeningDay;
            if (!Main.Complete || (!opening && !Complete) || !Main.StartNextDay(mainBookings)) return false;
            if (Branch != null && !opening) Branch.StartNextDay(HospitalDay.BookingCount);
            return true;
        }

        public int NextStory => FirstUnseenStory();
        public void DismissStory(bool skipAll)
        {
            int next = FirstUnseenStory();
            if (skipAll) storySeen = 31;
            else if (next != 0) storySeen |= next;
        }

        private int FirstUnseenStory()
        {
            int available = (Main.ChapterOne ? 1 : 0) | (Main.Expanded ? 2 : 0) |
                (Main.TrainingDay != 0 ? 4 : 0) | (Main.LabDay != 0 ? 8 : 0) | (Branch != null ? 16 : 0);
            int pending = available & ~storySeen;
            return pending & -pending;
        }

        internal void WriteSave(BinaryWriter writer)
        {
            Main.WriteSave(writer);
            writer.Write(BranchOpeningDay);
            writer.Write(ViewingBranch);
            writer.Write(storySeen);
            Branch?.WriteSave(writer);
        }

        internal static HospitalNetwork ReadSave(BinaryReader reader, bool originalArt)
        {
            var main = HospitalDay.ReadSave(reader, originalArt, 4);
            var network = new HospitalNetwork(main)
            {
                BranchOpeningDay = reader.ReadInt32(),
                ViewingBranch = reader.ReadBoolean(),
                storySeen = reader.ReadInt32()
            };
            int opening = network.BranchOpeningDay;
            if (opening < 0 || opening > main.DayNumber + 1 || network.storySeen < 0 || network.storySeen > 31 ||
                (network.ViewingBranch && (opening == 0 || opening > main.DayNumber)))
                throw new InvalidDataException("Invalid network state.");
            if (opening > 0)
            {
                var branch = HospitalDay.ReadSave(reader, originalArt, 4, main);
                network.AttachBranch(branch);
                if (opening < 2 || !main.ChapterFour || main.TrainingDay == 0 || network.Funds < 0 ||
                    branch.DayNumber != Math.Max(1, main.DayNumber - opening + 1) ||
                    (opening > main.DayNumber && (!main.Complete || branch.Time != 0 || branch.Expanded)))
                    throw new InvalidDataException("Invalid branch state.");
            }
            return network;
        }
    }
}
