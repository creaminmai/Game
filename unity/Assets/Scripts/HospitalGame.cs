using UnityEngine;

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

        private readonly PatientVisit visit = new();
        private HospitalRoom room;
        private int waypoint;
        private bool selected;
        private GUIStyle heading;
        private GUIStyle label;
        private GUIStyle button;
        private float Scale => Mathf.Min(Screen.width / 960f, Screen.height / 540f);
        private bool Portrait => Screen.height > Screen.width;

        private void Awake()
        {
            room = new HospitalRoom(transform);
            var selectionCollider = room.Patient.gameObject.AddComponent<CapsuleCollider>();
            selectionCollider.center = new Vector3(0, .8f, 0);
            selectionCollider.height = 1.65f;
            selectionCollider.radius = .42f;
        }

        private void Update()
        {
            if (Portrait) return;
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
                    VisitStage.Entering => Entrance,
                    VisitStage.WalkingToCt => ToCt,
                    VisitStage.WalkingToPlanning => ToPlanning,
                    VisitStage.WalkingToTreatment => ToTreatment,
                    VisitStage.Leaving => Exit,
                    _ => null
                };
                if (route != null) Walk(route);
                else visit.Tick(Time.deltaTime);
            }

            bool inService = visit.Stage == VisitStage.Ct || visit.Stage == VisitStage.Treatment;
            room.PatientBody.localPosition = inService
                ? room.Patient.InverseTransformVector(new Vector3(0, .8f, -.36f))
                : Vector3.zero;
            room.PatientBody.localRotation = inService
                ? Quaternion.Inverse(room.Patient.rotation) * Quaternion.Euler(-90, 0, 0)
                : Quaternion.identity;
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
        }

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
