using UnityEngine;
#if UNITY_EDITOR
using System.Collections;
using System.IO;
#endif

namespace SunshineHospital
{
    public sealed class HospitalGame : MonoBehaviour
    {
        // Routes follow the central corridor. Service starts only after arrival.
        private static readonly Vector3[] Entrance = { Point(0, 3), Point(-1.6f, 3), Point(-3.8f, 2.65f) };
        private static readonly Vector3[] ToCt = { Point(-1.6f, 3), Point(0, 3), Point(0, -1.45f), Point(-4.25f, -1.45f) };
        private static readonly Vector3[] ToPlanning = { Point(0, -1.45f), Point(2.95f, -1.45f), Point(3.6f, -2.1f) };
        private static readonly Vector3[] ToTreatment = { Point(0, -1.45f), Point(0, 3.95f), Point(4.08f, 3.95f) };
        private static readonly Vector3[] Exit = { Point(0, 3.95f), Point(0, 7f) };

        private static readonly Vector3 CtBed = Point(-4f, -2.8f);
        private static readonly Vector3 TreatmentBed = Point(4f, 3f);
        private static readonly Quaternion TreatmentYaw = Quaternion.Euler(0, -35, 0);
        private static readonly Vector3 Bedside = Point(1.05f, 1.55f);
        private static readonly Vector3 CtApproach = CtBed + Bedside;
        private static readonly Vector3 TreatmentApproach = TreatmentBed + TreatmentYaw * Bedside;
        private static readonly Vector3[] ArtEntrance = { Point(0, 3), Point(-1.5f, 3), Point(-2.05f, 2.6f), Point(-4.5f, 2.6f) };
        private static readonly Vector3[] ArtToCt = { Point(-2.05f, 2.6f), Point(-1.5f, 3), Point(0, 3), Point(0, -2.8f), Point(-1.5f, -2.8f), CtApproach };
        private static readonly Vector3[] ArtToPlanning = { Point(-1.5f, -2.8f), Point(0, -2.8f), Point(0, -1f), Point(1.5f, -1f), Point(2.4f, -1.8f) };
        private static readonly Vector3[] ArtToTreatment = { Point(1.5f, -1f), Point(0, -1f), Point(0, 3), Point(1.5f, 3), Point(1.85f, 4.5f), TreatmentApproach };
        private static readonly Vector3[] ArtExit = { Point(1.85f, 4.5f), Point(1.5f, 3), Point(0, 3), Point(0, 7f) };

        private readonly PatientVisit visit = new();
        private HospitalRoom room;
        private Transform roomRoot;
#if UNITY_EDITOR
        private bool capturing;
#endif
        private int waypoint;
        private bool selected;
        private GUIStyle heading;
        private GUIStyle label;
        private GUIStyle button;
        private float Scale => Mathf.Min(Screen.width / 960f, Screen.height / 540f);
        private bool Portrait => Screen.height > Screen.width;

        private void Awake()
        {
            roomRoot = new GameObject("병원 장면").transform;
            roomRoot.SetParent(transform, false);
            room = new HospitalRoom(roomRoot);
            var selectionCollider = room.Patient.gameObject.AddComponent<CapsuleCollider>();
            selectionCollider.center = new Vector3(0, .8f, 0);
            selectionCollider.height = room.UsesOriginalArt ? 2f : 1.65f;
            if (room.UsesOriginalArt) selectionCollider.center = Vector3.up;
            selectionCollider.radius = .42f;
        }

        private void Update()
        {
            if (Portrait) return;
#if UNITY_EDITOR
            if (capturing) return;
            if (visit.Stage == VisitStage.Reception && room.UsesOriginalArt && Input.GetKeyDown(KeyCode.F8))
            {
                StartCoroutine(CaptureComparison());
                return;
            }
#endif
            if (Input.GetMouseButtonDown(0))
            {
                Vector3 mouse = Input.mousePosition;
                if (mouse.y < Screen.height - 66 * Scale && mouse.y > 120 * Scale &&
                    Physics.Raycast(room.Camera.ScreenPointToRay(mouse), out RaycastHit hit) &&
                    hit.transform == room.Patient)
                    selected = true;
            }

            if (!visit.Paused)
            {
                Vector3[] route = visit.Stage switch
                {
                    VisitStage.Entering => room.UsesOriginalArt ? ArtEntrance : Entrance,
                    VisitStage.WalkingToCt => room.UsesOriginalArt ? ArtToCt : ToCt,
                    VisitStage.WalkingToPlanning => room.UsesOriginalArt ? ArtToPlanning : ToPlanning,
                    VisitStage.WalkingToTreatment => room.UsesOriginalArt ? ArtToTreatment : ToTreatment,
                    VisitStage.Leaving => room.UsesOriginalArt ? ArtExit : Exit,
                    _ => null
                };
                if (route != null) Walk(route);
                else
                {
#if UNITY_EDITOR
                    VisitStage previousStage = visit.Stage;
                    float serviceSeconds = visit.Elapsed + Time.deltaTime;
#endif
                    visit.Tick(Time.deltaTime);
#if UNITY_EDITOR
                    if (previousStage != visit.Stage)
                        Debug.Log($"[Hospital QA] {previousStage} → {visit.Stage}, active seconds {serviceSeconds:F3}, funds {visit.Funds}");
#endif
                }
            }

            bool inService = visit.Stage == VisitStage.Ct || visit.Stage == VisitStage.Treatment;
            if (inService && room.UsesOriginalArt)
            {
                bool treatment = visit.Stage == VisitStage.Treatment;
                var yaw = treatment ? TreatmentYaw : Quaternion.identity;
                var bed = treatment ? TreatmentBed : CtBed;
                float edgeTime = Mathf.Min(visit.Elapsed, visit.Duration - visit.Elapsed);
                float recline = Mathf.SmoothStep(0, 1, Mathf.InverseLerp(.15f, .75f, edgeTime));
                float shift = Mathf.SmoothStep(0, 1, Mathf.InverseLerp(.75f, 1.35f, edgeTime));
                var elevated = Vector3.Lerp(Bedside, new Vector3(1.05f, 1.22f, 2.05f), recline);
                var at = Vector3.Lerp(elevated, new Vector3(0, 1.22f, .65f), shift);
                room.PatientBody.SetPositionAndRotation(bed + yaw * at, yaw * Quaternion.Euler(-90 * recline, 0, 0));
                room.SetTreatmentHeadLift(treatment ? 1 - Mathf.SmoothStep(0, 1, Mathf.InverseLerp(1.35f, 1.75f, edgeTime)) : 0);
            }
            else
            {
                room.PatientBody.localPosition = inService
                    ? room.Patient.InverseTransformVector(new Vector3(0, .8f, -.36f))
                    : Vector3.zero;
                room.PatientBody.localRotation = inService
                    ? Quaternion.Inverse(room.Patient.rotation) * Quaternion.Euler(-90, 0, 0)
                    : Quaternion.identity;
                room.SetTreatmentHeadLift(visit.Stage == VisitStage.WalkingToTreatment || visit.Stage == VisitStage.Leaving
                    ? Mathf.InverseLerp(2.5f, .5f, Vector3.Distance(room.Patient.position, TreatmentApproach))
                    : 0);
            }
            room.Patient.gameObject.SetActive(visit.Stage != VisitStage.Complete);
            room.Selection.gameObject.SetActive(selected && !inService);
            room.SetLamp(room.CtLamp, visit.Stage == VisitStage.Ct);
            room.SetLamp(room.TreatmentLamp, visit.Stage == VisitStage.Treatment);
        }

        private void Walk(Vector3[] route)
        {
            float distance = Time.deltaTime * PatientVisit.WalkSpeed;
            while (waypoint < route.Length)
            {
                Vector3 target = route[waypoint];
                Vector3 offset = target - room.Patient.position;
                float length = offset.magnitude;
                if (length > .001f)
                    room.Patient.rotation = Quaternion.LookRotation(offset);
                room.Patient.position = Vector3.MoveTowards(room.Patient.position, target, distance);
                if (length > distance) return;

                distance -= length;
                waypoint++;
            }
            waypoint = 0;
            visit.Arrive();
        }

        private void OnGUI()
        {
            InitializeStyles();
#if UNITY_EDITOR
            bool wasGuiEnabled = GUI.enabled;
            if (capturing) GUI.enabled = false;
#endif
            float scale = Portrait ? Screen.width / 520f : Scale;
            Matrix4x4 previous = GUI.matrix;
            GUI.matrix = Matrix4x4.Scale(new Vector3(scale, scale, 1));
            float width = Screen.width / scale;
            float height = Screen.height / scale;
            if (Portrait)
            {
                Panel(new Rect(0, 0, width, height));
                GUI.Label(new Rect(24, height / 2 - 28, width - 48, 56), "가로로 돌려서 병원을 운영하세요", heading);
            }
            else
            {
                Panel(new Rect(0, 0, width, 62));
                GUI.Label(new Rect(18, 7, 240, 48), "햇살병원", heading);
                GUI.Label(new Rect(width - 265, 10, 155, 42), $"운영 자금  {visit.Funds:N0}만", label);
                if (GUI.Button(new Rect(width - 104, 9, 92, 44), visit.Paused ? "재생" : "일시정지", button))
                    visit.TogglePause();

                Panel(new Rect(0, height - 114, width, 114));
                GUI.Label(new Rect(18, height - 107, width - 36, 36), Status(), heading);
                string detail = selected ? "김영수 · 오늘 일정" : "환자를 선택해 오늘 일정을 확인하세요";
                if (visit.Duration > 0f) detail += $"   {Mathf.CeilToInt(visit.Duration - visit.Elapsed)}초 남음";
                if (visit.Stage == VisitStage.Leaving || visit.Stage == VisitStage.Complete) detail = "오늘 일정 완료  +200만";
                GUI.Label(new Rect(18, height - 67, width - 254, 44), detail, label);

                var action = new Rect(width - 218, height - 64, 200, 48);
                bool wasEnabled = GUI.enabled;
                GUI.enabled = wasEnabled && !visit.Paused;
                if (!selected && visit.Stage != VisitStage.Complete)
                {
                    if (GUI.Button(action, "김영수 선택", button)) selected = true;
                }
                else if (visit.Stage == VisitStage.Reception)
                {
                    if (GUI.Button(action, "접수하기", button)) visit.Admit();
                }
                else if (visit.Stage == VisitStage.AwaitingPlan)
                {
                    if (GUI.Button(action, "계획 지시", button)) visit.AssignPlan();
                }
                GUI.enabled = wasEnabled;
            }
            GUI.matrix = previous;
#if UNITY_EDITOR
            GUI.enabled = wasGuiEnabled;
#endif
        }

#if UNITY_EDITOR
        private IEnumerator CaptureComparison()
        {
            capturing = true;
            string folder = Path.GetFullPath(Path.Combine(Application.dataPath, "../../artifacts/unity-hospital"));
            GameObject prototype = null;
            Color ambient = RenderSettings.ambientLight;
            try
            {
                Directory.CreateDirectory(folder);
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "after.png"));

                roomRoot.gameObject.SetActive(false);
                prototype = new GameObject("비교용 임시 병원");
                var before = new HospitalRoom(prototype.transform, preferOriginalArt: false);
                before.Patient.SetPositionAndRotation(room.Patient.position, room.Patient.rotation);
                before.Selection.gameObject.SetActive(selected);
                yield return new WaitForEndOfFrame();
                WriteGameView(Path.Combine(folder, "before.png"));
                Debug.Log($"[Hospital QA] Same-camera Game view images saved in {folder}");
            }
            finally
            {
                if (prototype != null)
                {
                    prototype.SetActive(false);
                    Destroy(prototype);
                }

                RenderSettings.ambientLight = ambient;
                roomRoot.gameObject.SetActive(true);
                capturing = false;
            }
        }

        private static void WriteGameView(string path)
        {
            Texture2D image = ScreenCapture.CaptureScreenshotAsTexture();
            try
            {
                File.WriteAllBytes(path, image.EncodeToPNG());
            }
            finally
            {
                Destroy(image);
            }
        }
#endif

        private void InitializeStyles()
        {
            if (heading != null) return;
            Font font = Resources.Load<Font>("SunshineHangul");
            heading = new GUIStyle(GUI.skin.label) { font = font, fontSize = 24, alignment = TextAnchor.MiddleLeft };
            label = new GUIStyle(heading) { fontSize = 17 };
            button = new GUIStyle(GUI.skin.button) { font = font, fontSize = 18 };
            heading.normal.textColor = label.normal.textColor = new Color(.22f, .19f, .15f);
        }

        private static void Panel(Rect position)
        {
            Color previous = GUI.color;
            GUI.color = new Color(1f, .96f, .87f);
            GUI.DrawTexture(position, Texture2D.whiteTexture);
            GUI.color = previous;
        }

        private string Status() => visit.Stage switch
        {
            VisitStage.Entering => "병원에 도착했어요",
            VisitStage.Reception => "접수를 기다리고 있어요",
            VisitStage.WalkingToCt => "CT실로 이동 중 · CT 예약됨",
            VisitStage.Ct => "CT 촬영 중",
            VisitStage.WalkingToPlanning => "계획실로 이동 중",
            VisitStage.AwaitingPlan => "치료 계획 지시 대기",
            VisitStage.Planning => "치료 계획 검토 중",
            VisitStage.WalkingToTreatment => "치료실로 이동 중 · 치료실 예약됨",
            VisitStage.Treatment => "방사선치료 중",
            VisitStage.Leaving => "치료를 마치고 귀가 중",
            _ => "환자가 귀가했어요"
        };

        private static Vector3 Point(float x, float z) => new(x, 0, z);
    }
}
