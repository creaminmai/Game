using System;
using System.Collections.Generic;
using System.Numerics;

namespace SunshineHospital
{
    internal sealed class DayRoutes
    {
        internal static readonly Vector2 CtBed = new(-4f, -2.8f);
        internal static readonly Vector2 TreatmentBed = new(4f, 3f);
        internal static readonly Vector2 Bedside = new(1.05f, 1.55f);
        internal static readonly Vector2 CtApproach = CtBed + Bedside;
        internal static readonly Vector2 TreatmentApproach =
            TreatmentBed + Vector2.Transform(Bedside, Matrix3x2.CreateRotation(35f * (float)Math.PI / 180f));

        private static readonly Vector2 AnnexOffset = new(6, 0);
        internal static Vector2 BedAt(int room) => room == 1 ? TreatmentBed + AnnexOffset : TreatmentBed;
        internal static Vector2 ApproachAt(int room) => room == 1 ? TreatmentApproach + AnnexOffset : TreatmentApproach;

        private readonly Vector2[][] annexOutbound = new Vector2[HospitalDay.AnnexBookingCount][];
        private readonly Vector2[][] annexReturn = new Vector2[HospitalDay.AnnexBookingCount][];
        internal Vector2 Spawn { get; }
        private readonly Dictionary<VisitStage, Vector2[]>[] paths = new Dictionary<VisitStage, Vector2[]>[HospitalDay.AnnexBookingCount];

        internal DayRoutes(bool art, bool single)
        {
            Spawn = new Vector2(-.38f, 6.6f);
            for (int i = 0; i < paths.Length; i++)
            {
                // Separate standing bays in each room. Approach the bays from the open door.
                var wait = i switch
                {
                    0 => new Vector2(-2.5f, 3.12f),
                    1 => new Vector2(-2.46f, 2.22f),
                    2 => new Vector2(-2.45f, 3.98f),
                    3 => new Vector2(-2.86f, 4.68f),
                    4 => new Vector2(-1.85f, 1.15f),
                    _ => new Vector2(-1.85f, 5.55f)
                };
                var plan = new Vector2(3.25f, -3.88f + i * .8f);
                if (i >= 4) plan = new Vector2(5.30f, -2.75f + (i - 4) * .95f);
                if (!art)
                {
                    wait = new Vector2(-2.5f - i % 2 * 1.3f, 2.5f - i / 2 * 1.2f);
                    plan = new Vector2(3.35f, -3.9f + i * .86f);
                }
                float north = single ? 0f : -.38f;
                float south = single ? 0f : .38f;
                Vector2 ct = art ? CtApproach : new Vector2(-4.25f, -1.45f);
                Vector2 treatment = art ? TreatmentApproach : new Vector2(4.08f, 3.95f);
                float ctDoor = art ? -2.8f : -1.45f;
                paths[i] = new Dictionary<VisitStage, Vector2[]>
                {
                    [VisitStage.Entering] = new[] { new Vector2(north, 3.4f), new Vector2(-1.62f, 3.4f), new Vector2(-1.62f, wait.Y), wait },
                    [VisitStage.WalkingToCt] = new[] { new Vector2(-1.62f, wait.Y), new Vector2(-1.62f, 2.65f), new Vector2(north, 2.65f),
                        new Vector2(north, ctDoor), new Vector2(-1.5f, ctDoor), ct },
                    [VisitStage.WalkingToPlanning] = new[] { new Vector2(-1.5f, ctDoor + .38f), new Vector2(south, ctDoor + .38f),
                        new Vector2(south, -.63f), new Vector2(2.05f, -.63f), new Vector2(2.05f, plan.Y), plan },
                    [VisitStage.WalkingToTreatment] = new[] { new Vector2(2.05f, plan.Y), new Vector2(2.05f, -1.72f), new Vector2(south, -1.72f),
                        new Vector2(south, 2.65f), new Vector2(1.55f, 2.65f), new Vector2(1.85f, 4.5f), treatment },
                    [VisitStage.Leaving] = new[] { new Vector2(1.85f, 4.8f), new Vector2(1.55f, 3.42f),
                        new Vector2(south, 3.42f), new Vector2(south, 7f) }
                };
                if (i >= 4)
                {
                    paths[i][VisitStage.WalkingToPlanning] = new[] { new Vector2(-1.5f, ctDoor + .38f),
                        new Vector2(south, ctDoor + .38f), new Vector2(south, -.63f), new Vector2(2.05f, -.63f),
                        new Vector2(4.42f, -.63f), new Vector2(4.42f, plan.Y), plan };
                    paths[i][VisitStage.WalkingToTreatment] = new[] { new Vector2(4.42f, plan.Y),
                        new Vector2(4.42f, -1.72f), new Vector2(south, -1.72f), new Vector2(south, 2.65f),
                        new Vector2(1.55f, 2.65f), new Vector2(1.85f, 4.5f), treatment };
                }
                var mainOutbound = paths[i][VisitStage.WalkingToTreatment];
                var tunnel = new Vector2(10, 5.15f);
                annexOutbound[i] = new Vector2[mainOutbound.Length + 2];
                Array.Copy(mainOutbound, annexOutbound[i], mainOutbound.Length - 1);
                annexOutbound[i][mainOutbound.Length - 1] = new Vector2(4.2f, 5.15f);
                annexOutbound[i][mainOutbound.Length] = tunnel;
                annexOutbound[i][mainOutbound.Length + 1] = ApproachAt(1);
                annexReturn[i] = new[] { new Vector2(10, 5.75f), new Vector2(4.2f, 5.75f),
                    new Vector2(1.55f, 3.42f), new Vector2(south, 3.42f), new Vector2(south, 7f) };
            }
        }

        internal Vector2[] For(int id, VisitStage stage, int room = -1)
        {
            if (room == 1 && stage == VisitStage.WalkingToTreatment) return annexOutbound[id - 1];
            if (room == 1 && stage == VisitStage.Leaving) return annexReturn[id - 1];
            return paths[id - 1].TryGetValue(stage, out var path) ? path : null;
        }
    }
}
