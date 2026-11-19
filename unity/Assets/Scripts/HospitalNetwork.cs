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
        public HospitalDay Coast { get; private set; }
        public HospitalSite Site { get; private set; }
        public int CoastOpeningDay { get; private set; }
        public bool ViewingBranch => Site == HospitalSite.Riverside;
        public HospitalDay HospitalAt(HospitalSite site) => site switch
        {
            HospitalSite.Main => Main,
            HospitalSite.Riverside => Branch,
            HospitalSite.Coast => Coast,
            _ => null
        };
        public int OpensOn(HospitalSite site) => site == HospitalSite.Main ? 0 : site == HospitalSite.Coast ? CoastOpeningDay : BranchOpeningDay;
        public bool Available(HospitalSite site) => HospitalAt(site) != null && Main.DayNumber >= OpensOn(site);
        public HospitalDay Active => HospitalAt(Site);
        public bool Complete => Main.Complete && (!Available(HospitalSite.Riverside) || Branch.Complete) && (!Available(HospitalSite.Coast) || Coast.Complete);
        public double Time => Math.Max(Main.Time, Math.Max(Branch?.Time ?? 0, Coast?.Time ?? 0));
        public int BranchOpeningDay { get; private set; }
        public int Funds => Main.Funds + (Branch == null ? 0 : Branch.Funds - HospitalDay.StartingFunds) + (Coast == null ? 0 : Coast.Funds - HospitalDay.StartingFunds) - PurchasesOn(0, null) + SeasonBonus;
        public int Reputation => Math.Min(100, InitialReputation + Main.DayNumber - 1 + (Main.Complete ? 1 : 0)
            + (Main.ChapterOne ? 3 : 0) + (Main.ChapterTwo ? 3 : 0) + (Main.ChapterThree ? 3 : 0) + (Main.ChapterFour ? 3 : 0));
        public bool BranchChapterComplete => Branch != null && Branch.LifetimeDeparted >= 8;
        public bool DelegationReady => Main.TrainingDay != 0 && Main.AutoAdmission && Main.AutoPlanning;
        public bool CanOpenBranch => Branch == null && Main.ChapterFour && DelegationReady &&
            Reputation >= RequiredReputation && Funds >= BranchCost && Main.Complete;
        public bool CanOpenCoast => Coast == null && BranchChapterComplete && CoordinationComplete && DelegationReady && Complete &&
            Reputation >= AlphaCatalog.CoastReputation && Funds >= AlphaCatalog.CoastCost && Main.ResearchActive(HospitalResearch.EducationIII);

        public int JointClosingDays { get; private set; }
        public bool CoordinationComplete => JointClosingDays == 3;
        public bool CoastalChapterComplete { get; private set; }
        public bool SeasonComplete { get; private set; }
        public int LastSeasonCredit { get; private set; }
        public double NetworkSatisfaction
        {
            get
            {
                int total = 0, count = 0;
                foreach (HospitalDay site in new[] { Main, Branch, Coast })
                    if (site != null)
                        foreach (var patient in site.Patients)
                            if (patient.Stage == VisitStage.Complete)
                            {
                                count++;
                                total += patient.Satisfaction;
                            }
                return count == 0 ? 0 : (double)total / count;
            }
        }
        private int SeasonBonus => (CoordinationComplete ? 2500 : 0) + (CoastalChapterComplete ? 3000 : 0);

        private int storySeen;
        public int StoryMoment { get; private set; }
        public int StoryLine { get; private set; }
        public bool StartStory(int moment)
        {
            if (moment <= 0 || (moment & (moment - 1)) != 0 || (AvailableStories & moment) == 0) return false;
            StoryMoment = moment;
            StoryLine = 0;
            return true;
        }
        public void AdvanceStory(bool skip = false)
        {
            if (StoryMoment == 0) return;
            if (!skip && StoryLine == 0) { StoryLine = 1; return; }
            storySeen |= StoryMoment;
            StoryMoment = StoryLine = 0;
        }
        private readonly int[] owned = new int[3];
        private readonly int[] displayed = new int[3];
        private readonly int[] lastIncome = new int[3];
        private readonly int[] lastExpense = new int[3];
        private readonly int[] lastDeparted = new int[3];
        // A fixed slot is a purchase identity. Date zero is an undated legacy purchase.
        private readonly (int Amount, int Date)[] purchases = new (int, int)[26];
        private const int RiversidePurchase = 24;
        private const int CoastPurchase = 25;
        private static readonly int[] LegacyDecorationPrices = { 80, 80, 100, 100, 120, 120, 90, 90 };

        private int PurchasesOn(int date, HospitalSite? site)
        {
            int total = 0;
            for (int i = 0; i < purchases.Length; i++)
            {
                var owner = i < RiversidePurchase ? (HospitalSite)(i / 8) : HospitalSite.Main;
                if ((date == 0 || purchases[i].Date == date) && (site == null || site == owner))
                    total += purchases[i].Amount;
            }
            return total;
        }

        public int ExpenseToday(HospitalSite site) => (HospitalAt(site)?.TotalExpense ?? 0) + PurchasesOn(Main.DayNumber, site);
        public int SharedExpenseToday => ExpenseToday(HospitalSite.Main) + ExpenseToday(HospitalSite.Riverside) + ExpenseToday(HospitalSite.Coast);
        public int SharedIncomeToday => Main.Income + (Branch?.Income ?? 0) + (Coast?.Income ?? 0);
        public int LastSharedExpense => lastExpense[0] + lastExpense[1] + lastExpense[2];

        public bool Owns(int item) => ValidItem(item) && (owned[(int)Site] & (1 << item)) != 0;
        public int Decorations => displayed[(int)Site];
        private static bool ValidItem(int item) => item >= 0 && item < AlphaCatalog.Decorations.Count;
        public bool ApplyDecoration(int item)
        {
            if (!ValidItem(item) || (!Owns(item) && Funds < AlphaCatalog.Decorations[item].Cost)) return false;
            if (!Owns(item)) purchases[(int)Site * 8 + item] = (AlphaCatalog.Decorations[item].Cost, Main.DayNumber);
            owned[(int)Site] |= 1 << item;
            int pair = 3 << (AlphaCatalog.Decorations[item].Slot * 2);
            displayed[(int)Site] = (displayed[(int)Site] & ~pair) | (1 << item);
            return true;
        }
        public (int Income, int Expense, int Departed) LastDay => (lastIncome[(int)Site], lastExpense[(int)Site], lastDeparted[(int)Site]);

        public HospitalNetwork(HospitalDay main)
        {
            Main = main;
            Main.SpendingLimit = () => Funds;
        }

        public bool OpenBranch()
        {
            if (!CanOpenBranch) return false;
            purchases[RiversidePurchase] = (BranchCost, Main.DayNumber);
            BranchOpeningDay = Main.DayNumber + 1;
            AttachBranch(new HospitalDay(Main.OriginalArt, regional: true));
            return true;
        }

        public bool OpenCoast()
        {
            if (!CanOpenCoast) return false;
            purchases[CoastPurchase] = (AlphaCatalog.CoastCost, Main.DayNumber);
            CoastOpeningDay = Main.DayNumber + 1;
            Coast = new HospitalDay(Main.OriginalArt, site: HospitalSite.Coast);
            ConfigureSatellite(Coast);
            return true;
        }

        private void AttachBranch(HospitalDay branch)
        {
            Branch = branch;
            ConfigureSatellite(branch);
        }

        private void ConfigureSatellite(HospitalDay branch)
        {
            branch.SkipGuide();
            branch.SpendingLimit = () => Funds;
            if (branch.Paused != Main.Paused) branch.TogglePause();
            branch.ResearchSource = Main;
        }

        public bool Switch(bool branch) => Switch(branch ? HospitalSite.Riverside : HospitalSite.Main);

        public bool Switch(HospitalSite site)
        {
            if (!Available(site)) return false;
            Site = site;
            return true;
        }

        public void Tick(float seconds)
        {
            if (Active.Paused) return;
            Main.Tick(seconds);
            if (Available(HospitalSite.Riverside)) Branch.Tick(seconds);
            if (Available(HospitalSite.Coast)) Coast.Tick(seconds);
        }

        public void TogglePause()
        {
            Main.TogglePause();
            Branch?.TogglePause();
            Coast?.TogglePause();
        }

        public bool StartNextDay(int mainBookings)
        {
            if (!Complete || (mainBookings != HospitalDay.BookingCount &&
                (mainBookings != HospitalDay.AnnexBookingCount || !Main.Expanded))) return false;
            if (CoordinationComplete) Main.EnableCourses();
            int previousBonus = SeasonBonus;
            int date = Main.DayNumber;
            bool qualifyingDay = BranchChapterComplete && Available(HospitalSite.Riverside) &&
                Main.MetClosingTarget && Branch.MetClosingTarget;
            bool qualifyingCoast = Available(HospitalSite.Coast) && Coast.Departed > 0;
            bool seasonReady = (CoastalChapterComplete || qualifyingCoast) && Main.CompletedResearchCount >= 6 &&
                Main.CompletedCourses > 0 && Branch?.CompletedCourses > 0 && Coast?.CompletedCourses > 0 && NetworkSatisfaction >= 85;
            var mainResult = (Main.Income, ExpenseToday(HospitalSite.Main), Main.Departed);
            if (!Main.StartNextDay(mainBookings)) return false;
            if (qualifyingDay && !CoordinationComplete)
            {
                JointClosingDays++;
                if (CoordinationComplete) Main.AddResearchPoints(10);
            }
            if (qualifyingCoast) CoastalChapterComplete = true;
            if (seasonReady) SeasonComplete = true;
            LastSeasonCredit = SeasonBonus - previousBonus;
            (lastIncome[0], lastExpense[0], lastDeparted[0]) = mainResult;
            CloseSatellite(Branch, BranchOpeningDay, date);
            CloseSatellite(Coast, CoastOpeningDay, date);
            return true;
        }

        private void CloseSatellite(HospitalDay satellite, int opening, int date)
        {
            if (satellite == null || date < opening) return;
            int i = (int)satellite.Site;
            (lastIncome[i], lastExpense[i], lastDeparted[i]) = (satellite.Income, satellite.TotalExpense + PurchasesOn(date, satellite.Site), satellite.Departed);
            if (CoordinationComplete) satellite.EnableCourses();
            satellite.StartNextDay(satellite.Site == HospitalSite.Coast && satellite.Expanded
                ? HospitalDay.AnnexBookingCount : HospitalDay.BookingCount);
        }

        public int NextStory => FirstUnseenStory();
        public void DismissStory(bool skipAll)
        {
            int next = FirstUnseenStory();
            if (skipAll) storySeen = 127;
            else if (next != 0) storySeen |= next;
        }

        public int AvailableStories => (Main.ChapterOne ? 1 : 0) | (Main.Expanded ? 2 : 0) |
                (Main.TrainingDay != 0 ? 4 : 0) | (Main.LabDay != 0 ? 8 : 0) | (Branch != null ? 16 : 0) | (Coast != null ? 32 : 0) | (SeasonComplete ? 64 : 0);

        private int FirstUnseenStory()
        {
            int pending = AvailableStories & ~storySeen;
            return pending & -pending;
        }

        internal void WriteSave(BinaryWriter writer)
        {
            Main.WriteSave(writer, 8);
            writer.Write(BranchOpeningDay);
            writer.Write(ViewingBranch);
            writer.Write(storySeen);
            Branch?.WriteSave(writer, 8);
            writer.Write((int)Site);
            writer.Write(CoastOpeningDay);
            Coast?.WriteSave(writer, 8);
            for (int i = 0; i < owned.Length; i++)
            {
                writer.Write(owned[i]);
                writer.Write(displayed[i]);
                writer.Write(lastIncome[i]);
                writer.Write(lastExpense[i]);
                writer.Write(lastDeparted[i]);
            }
            foreach (var purchase in purchases)
            {
                writer.Write(purchase.Amount);
                writer.Write(purchase.Date);
            }
            writer.Write(StoryMoment);
            writer.Write(StoryLine);
            writer.Write(JointClosingDays);
            writer.Write(CoastalChapterComplete);
            writer.Write(SeasonComplete);
            writer.Write(LastSeasonCredit);
        }

        internal static HospitalNetwork ReadSave(BinaryReader reader, bool originalArt, int version)
        {
            int dayVersion = version >= 8 ? 8 : version >= 6 ? 6 : 4;
            var main = HospitalDay.ReadSave(reader, originalArt, dayVersion);
            var network = new HospitalNetwork(main)
            {
                BranchOpeningDay = reader.ReadInt32(),
                Site = reader.ReadBoolean() ? HospitalSite.Riverside : HospitalSite.Main,
                storySeen = reader.ReadInt32()
            };
            int opening = network.BranchOpeningDay;
            if (opening < 0 || opening > main.DayNumber + 1 || network.storySeen < 0 || network.storySeen > (version >= 8 ? 127 : version >= 6 ? 63 : 31) ||
                (network.ViewingBranch && (opening == 0 || opening > main.DayNumber)))
                throw new InvalidDataException("Invalid network state.");
            if (opening > 0)
            {
                var branch = HospitalDay.ReadSave(reader, originalArt, dayVersion, main);
                network.AttachBranch(branch);
                if (opening < 2 || !main.ChapterFour || main.TrainingDay == 0 || network.Funds < 0 ||
                    branch.DayNumber != Math.Max(1, main.DayNumber - opening + 1) ||
                    (opening > main.DayNumber && (!main.Complete || branch.Time != 0 || branch.Expanded)))
                    throw new InvalidDataException("Invalid branch state.");
            }
            if (version >= 6)
            {
                var site = (HospitalSite)reader.ReadInt32();
                network.CoastOpeningDay = reader.ReadInt32();
                int coastOpening = network.CoastOpeningDay;
                if (coastOpening < 0 || coastOpening > main.DayNumber + 1) throw new InvalidDataException("Invalid coast date.");
                if (coastOpening > 0)
                {
                    network.Coast = HospitalDay.ReadSave(reader, originalArt, dayVersion, main, HospitalSite.Coast);
                    network.ConfigureSatellite(network.Coast);
                    if (!network.BranchChapterComplete || !main.ResearchActive(HospitalResearch.EducationIII) ||
                        network.Coast.DayNumber != Math.Max(1, main.DayNumber - coastOpening + 1) ||
                        (coastOpening > main.DayNumber && (!main.Complete || network.Coast.Time != 0 || network.Coast.Expanded)))
                        throw new InvalidDataException("Invalid coastal hospital.");
                }
                if (!network.Switch(site)) throw new InvalidDataException("Unavailable hospital view.");
                for (int i = 0; i < network.owned.Length; i++)
                {
                    int owned = network.owned[i] = reader.ReadInt32();
                    int shown = network.displayed[i] = reader.ReadInt32();
                    int income = network.lastIncome[i] = reader.ReadInt32();
                    int expense = network.lastExpense[i] = reader.ReadInt32();
                    int departed = network.lastDeparted[i] = reader.ReadInt32();
                    if ((owned & ~255) != 0 || (shown & ~owned) != 0 || (shown & (shown >> 1) & 85) != 0 ||
                        departed < 0 || departed > HospitalDay.AnnexBookingCount || income != departed * HospitalDay.VisitFee ||
                        expense < 0 || (network.HospitalAt((HospitalSite)i) == null && (owned != 0 || departed != 0 || expense != 0)))
                        throw new InvalidDataException("Invalid hospital records or decor.");
                }

            }
            if (version >= 7)
            {
                for (int i = 0; i < network.purchases.Length; i++)
                {
                    int amount = reader.ReadInt32(), date = reader.ReadInt32();
                    bool exists = i == CoastPurchase ? network.Coast != null : i == RiversidePurchase ? network.Branch != null :
                        (network.owned[i / 8] & (1 << (i % 8))) != 0;
                    int openingDate = i == CoastPurchase ? network.CoastOpeningDay : network.BranchOpeningDay;
                    if ((amount > 0) != exists || amount < 0 || amount > 1000000 || date < 0 || date > main.DayNumber ||
                        (amount == 0 && date != 0) || (exists && i >= RiversidePurchase && date != openingDate - 1))
                        throw new InvalidDataException("Invalid purchase ledger.");
                    network.purchases[i] = (amount, date);
                }
                int moment = reader.ReadInt32(), line = reader.ReadInt32();
                if (line < 0 || line > 1 || (moment == 0 ? line != 0 : (moment != 64 && !network.StartStory(moment)) || (moment == 64 && version < 8)))
                    throw new InvalidDataException("Invalid growth dialogue.");
                network.StoryMoment = moment;
                network.StoryLine = line;
            }
            else
            {
                for (int i = 0; i < RiversidePurchase; i++)
                    if ((network.owned[i / 8] & (1 << (i % 8))) != 0)
                        network.purchases[i] = (LegacyDecorationPrices[i % 8], 0);
                if (network.Branch != null) network.purchases[RiversidePurchase] = (9000, opening - 1);
                if (network.Coast != null) network.purchases[CoastPurchase] = (20000, network.CoastOpeningDay - 1);
                if (main.DayNumber > 1) network.lastExpense[0] += network.PurchasesOn(main.DayNumber - 1, HospitalSite.Main);
            }
            if (version >= 8)
            {
                network.JointClosingDays = reader.ReadInt32();
                network.CoastalChapterComplete = reader.ReadBoolean();
                network.SeasonComplete = reader.ReadBoolean();
                network.LastSeasonCredit = reader.ReadInt32();
                if ((network.StoryMoment == 64 && !network.SeasonComplete) ||
                    (network.SeasonComplete && (!network.CoastalChapterComplete || main.CompletedResearchCount < 6 ||
                    main.CompletedCourses == 0 || network.Branch?.CompletedCourses == 0 || network.Coast?.CompletedCourses == 0)) ||
                    (network.LastSeasonCredit != 0 && network.LastSeasonCredit != 2500 && network.LastSeasonCredit != 3000 && network.LastSeasonCredit != 5500))
                    throw new InvalidDataException("Invalid finale or award.");
                if (network.JointClosingDays < 0 || network.JointClosingDays > 3 ||
                    (network.JointClosingDays != 0 && !network.BranchChapterComplete) ||
                    (network.CoastalChapterComplete && (network.Coast == null || network.Coast.DayNumber < 2)))
                    throw new InvalidDataException("Invalid season progress.");
            }
            if (network.Funds < 0) throw new InvalidDataException("Invalid shared funds.");
            return network;
        }
    }
}
