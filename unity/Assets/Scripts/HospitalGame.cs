using UnityEngine;
#if UNITY_EDITOR
using System.Collections;
using System.IO;
#endif

namespace SunshineHospital
{
    public sealed partial class HospitalGame : MonoBehaviour
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
        private static readonly Vector3[] ArtEntrance = { Point(0, 3), Point(-1.5f, 3), Point(-2.5f, 3.12f) };
        private static readonly Vector3[] ArtToCt = { Point(-1.5f, 3), Point(0, 3), Point(0, -2.8f), Point(-1.5f, -2.8f), CtApproach };
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
        private const float Header = 58f;
        private const float Footer = 88f;
        private static readonly Color Paper = new(1f, .965f, .898f);
        private static readonly Color Ink = new(.15f, .22f, .19f);
        private static readonly Color Mint = new(.10f, .40f, .32f);
        private static readonly Color Coral = new(.98f, .75f, .67f);
        private GUIStyle heading;
        private GUIStyle label;
        private GUIStyle primary;
        private GUIStyle quiet;
        private GUIStyle patientTag;
        private readonly System.Collections.Generic.List<Texture2D> hudTextures = new();
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
            UpdateCameraViewport(room.Camera);
            if (Portrait) return;
#if UNITY_EDITOR
            if (capturing) return;
            if (!qaRunning && visit.Stage <= VisitStage.Reception && room.UsesOriginalArt && Input.GetKeyDown(KeyCode.F9))
                StartCoroutine(VerifyVisit());

            if (visit.Stage == VisitStage.Reception && room.UsesOriginalArt && Input.GetKeyDown(KeyCode.F8))
            {
                StartCoroutine(CaptureComparison());
                return;
            }
#endif
            if (Input.GetMouseButtonDown(0))
            {
                Vector3 mouse = Input.mousePosition;
                if (mouse.y < Screen.height - Header * Scale && mouse.y > Footer * Scale &&
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
                    : new Vector3(0, room.UsesOriginalArt ? .055f : 0f, 0);
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
            if (room.UsesOriginalArt && visit.Stage == VisitStage.Reception)
                room.Patient.rotation = Quaternion.Euler(0, 29, 0);
        }

        private void UpdateCameraViewport(Camera camera)
        {
            float bottom = Footer * Scale / Screen.height;
            float top = Header * Scale / Screen.height;
            camera.rect = new Rect(0, bottom, 1, 1 - bottom - top);
            camera.aspect = Screen.width / (Screen.height * camera.rect.height);
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
                Panel(new Rect(0, 0, width, height), Paper);
                GUI.Label(new Rect(24, height / 2 - 28, width - 48, 56), "가로로 돌려서 병원을 운영하세요", heading);
            }
            else
            {
                DrawHud(width, height, scale);
            }
            GUI.matrix = previous;
        }

        private void DrawHud(float width, float height, float scale)
        {
            bool acceptInput = true;
#if UNITY_EDITOR
            acceptInput = !capturing && !qaRunning;
#endif
            Panel(new Rect(0, 0, width, Header), Paper);
            Panel(new Rect(0, Header - 1, width, 1), new Color(.84f, .80f, .70f));
            GUI.Label(new Rect(20, 0, 220, Header), "햇살병원", heading);
            GUI.Label(new Rect(width - 277, 0, 155, Header), $"운영 자금  {visit.Funds:N0}만", label);
            if (GUI.Button(new Rect(width - 116, 8, 96, 42), visit.Paused ? "재생" : "일시정지",
                    visit.Paused ? primary : quiet) && acceptInput)
                visit.TogglePause();

            float footer = height - Footer;
            Panel(new Rect(0, footer, width, Footer), Paper);
            Panel(new Rect(0, footer, width, 1), new Color(.84f, .80f, .70f));
            Panel(new Rect(20, footer + 15, 4, 23), visit.Paused ? Coral : Mint);
            GUI.Label(new Rect(34, footer + 7, width - 255, 36), Status(), heading);
            GUI.Label(new Rect(34, footer + 42, width - 255, 34), Guidance(), label);

            string action = visit.Stage switch
            {
                VisitStage.Complete or VisitStage.Leaving => null,
                _ when !selected => "김영수 선택",
                VisitStage.Reception => "접수하기",
                VisitStage.AwaitingPlan => "계획 지시",
                _ => null
            };
            if (action != null)
            {
                bool enabled = GUI.enabled;
                GUI.enabled = enabled && !visit.Paused;
                if (GUI.Button(new Rect(width - 195, footer + 19, 175, 50), action, primary) && acceptInput)
                {
                    if (!selected) selected = true;
                    else if (visit.Stage == VisitStage.Reception) visit.Admit();
                    else if (visit.Stage == VisitStage.AwaitingPlan) visit.AssignPlan();
                }
                GUI.enabled = enabled;
            }

            if (visit.Stage == VisitStage.Reception || visit.Stage == VisitStage.AwaitingPlan)
            {
                var marker = room.Camera.WorldToScreenPoint(room.Patient.position + Vector3.up * 2.13f);
                var rect = new Rect(marker.x / scale - 43, (Screen.height - marker.y) / scale - 30, 86, 28);
                if (GUI.Button(rect, "김영수", selected ? primary : patientTag) && acceptInput)
                    selected = true;
            }
        }

        private string Guidance()
        {
            if (visit.Paused) return "일시정지 중 · 재생을 누르면 이어집니다";
            if (visit.Duration > 0f) return $"김영수 · {Mathf.CeilToInt(visit.Duration - visit.Elapsed)}초 남음";
            return visit.Stage switch
            {
                VisitStage.Entering => "입장이 끝나면 접수할 수 있어요",
                VisitStage.Reception => selected ? "김영수 · 접수하면 CT실로 이동합니다" : "환자 또는 선택 버튼을 눌러주세요",
                VisitStage.AwaitingPlan => "김영수 · 치료 전에 계획 지시가 필요해요",
                VisitStage.Leaving or VisitStage.Complete => "오늘 일정 완료 · 수입 +200만",
                _ => "김영수 · 도착하면 자동으로 이어집니다"
            };
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
                UpdateCameraViewport(before.Camera);
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
            heading = new GUIStyle(GUI.skin.label)
            {
                font = font, fontSize = 24, alignment = TextAnchor.MiddleLeft, fontStyle = FontStyle.Bold
            };
            label = new GUIStyle(heading) { fontSize = 18, fontStyle = FontStyle.Normal };
            heading.normal.textColor = label.normal.textColor = Ink;
            primary = ButtonStyle(font, Mint, new Color(.15f, .48f, .38f), Color.white);
            quiet = ButtonStyle(font, Coral, new Color(1f, .82f, .74f), Ink);
            patientTag = ButtonStyle(font, Paper, new Color(.88f, .95f, .89f), Ink);
            patientTag.fontSize = 15;
        }

        private GUIStyle ButtonStyle(Font font, Color surface, Color hover, Color text)
        {
            var style = new GUIStyle
            {
                font = font,
                fontSize = 18,
                alignment = TextAnchor.MiddleCenter,
                border = new RectOffset(12, 12, 12, 12)
            };
            SetButtonState(style.normal, surface, text);
            SetButtonState(style.hover, hover, text);
            SetButtonState(style.active, Color.Lerp(surface, Ink, .23f), text);
            SetButtonState(style.focused, surface, text);
            return style;
        }

        private void SetButtonState(GUIStyleState state, Color surface, Color text)
        {
            const int size = 32;
            var texture = new Texture2D(size, size, TextureFormat.RGBA32, false);
            texture.wrapMode = TextureWrapMode.Clamp;
            for (int y = 0; y < size; y++)
            for (int x = 0; x < size; x++)
            {
                float dx = x - Mathf.Clamp(x, 10, size - 11);
                float dy = y - Mathf.Clamp(y, 10, size - 11);
                Color pixel = surface;
                pixel.a = Mathf.Clamp01(10.5f - Mathf.Sqrt(dx * dx + dy * dy));
                texture.SetPixel(x, y, pixel);
            }
            texture.Apply(false, true);
            hudTextures.Add(texture);
            state.background = texture;
            state.textColor = text;
        }

        private void OnDestroy()
        {
            foreach (var texture in hudTextures) Destroy(texture);
        }

        private static void Panel(Rect position, Color color)
        {
            Color previous = GUI.color;
            GUI.color = color;
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
