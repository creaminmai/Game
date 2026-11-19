using System;
using System.IO;
using UnityEngine;
#if UNITY_EDITOR
using System.Collections;
#endif

namespace SunshineHospital
{
    public sealed partial class HospitalGame : MonoBehaviour
    {
        private static readonly Quaternion TreatmentYaw = Quaternion.Euler(0, -35, 0);
        private HospitalDay day;
        private HospitalRoom room;
        private Transform roomRoot;
        private HospitalRoom.Actor[] actors;
        private int selectedId;
        private HospitalSave save;
        private string saveNotice;
        private float saveNoticeUntil;
        private PatientVisit Selection => selectedId == 0 ? null : day.Patients[selectedId - 1];
#if UNITY_EDITOR
        private bool capturing;
#endif
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
            save = new HospitalSave(Path.Combine(Application.persistentDataPath, "UnitySaves", "first-day.bin"));
            SetDay(new HospitalDay(room.UsesOriginalArt));
            LoadDay(reportMissing: false);
        }

        private void SetDay(HospitalDay next)
        {
            if (actors != null)
                foreach (var actor in actors)
                {
                    actor.Root.gameObject.SetActive(false);
                    Destroy(actor.Root.gameObject);
                }
            day = next;
            selectedId = 0;
            actors = new HospitalRoom.Actor[day.Patients.Count];
            for (int i = 0; i < actors.Length; i++) actors[i] = room.CreatePatient(day.Patients[i]);
            RefreshActors();
        }

        private void Update()
        {
            UpdateCameraViewport(room.Camera);
            if (Portrait) return;
            float speed = 1f;
#if UNITY_EDITOR
            if (capturing) return;
            if (!qaRunning && room.UsesOriginalArt)
            {
                if (Input.GetKeyDown(KeyCode.F9)) StartCoroutine(VerifyVisit());
                if (Input.GetKeyDown(KeyCode.F10)) StartCoroutine(VerifyDay());
                if (Input.GetKeyDown(KeyCode.F11)) VerifySaveInEditor();
                if (Input.GetKeyDown(KeyCode.F8) && day.Patients[0].Stage == VisitStage.Reception)
                {
                    StartCoroutine(CaptureComparison());
                    return;
                }
            }
            speed = qaSpeed;
            if (!qaRunning)
#endif
                PickPatient();
            day.Tick(Time.deltaTime * speed);
            RefreshActors();
        }

        private void PickPatient()
        {
            if (!Input.GetMouseButtonDown(0)) return;
            Vector3 mouse = Input.mousePosition;
            if (mouse.y >= Screen.height - Header * Scale || mouse.y <= Footer * Scale) return;
            Physics.SyncTransforms();
            if (!Physics.Raycast(room.Camera.ScreenPointToRay(mouse), out RaycastHit hit)) return;
            for (int i = 0; i < actors.Length; i++)
                if (hit.transform == actors[i].Root)
                    Select(i + 1);
        }

        private void Select(int id)
        {
            if (id < 1 || id > day.Patients.Count || day.Patients[id - 1].Stage == VisitStage.NotArrived) return;
            selectedId = id;
        }

        private void RefreshActors()
        {
            float lift = 0;
            foreach (var patient in day.Patients)
                lift = Mathf.Max(lift, RefreshActor(patient, actors[patient.Id - 1]));
            room.SetTreatmentHeadLift(lift);
            room.SetLamp(room.CtLamp, day.CtOwner != 0 && day.Patients[day.CtOwner - 1].Stage == VisitStage.Ct);
            room.SetLamp(room.TreatmentLamp, day.TreatmentOwner != 0 && day.Patients[day.TreatmentOwner - 1].Stage == VisitStage.Treatment);
        }

        private float RefreshActor(PatientVisit patient, HospitalRoom.Actor actor)
        {
            bool visible = patient.Stage is not (VisitStage.NotArrived or VisitStage.Complete);
            actor.Root.gameObject.SetActive(visible);
            if (!visible) return 0;
            actor.Root.SetPositionAndRotation(World(patient.Position), Quaternion.LookRotation(World(patient.Heading)));
            bool inService = patient.Stage is VisitStage.Ct or VisitStage.Treatment;
            actor.Selection.gameObject.SetActive(selectedId == patient.Id && !inService);
            if (inService && room.UsesOriginalArt)
            {
                bool treatment = patient.Stage == VisitStage.Treatment;
                var yaw = treatment ? TreatmentYaw : Quaternion.identity;
                var bed = World(treatment ? DayRoutes.TreatmentBed : DayRoutes.CtBed);
                float edgeTime = Mathf.Min(patient.Elapsed, patient.Duration - patient.Elapsed);
                float recline = Mathf.SmoothStep(0, 1, Mathf.InverseLerp(.15f, .75f, edgeTime));
                float shift = Mathf.SmoothStep(0, 1, Mathf.InverseLerp(.75f, 1.35f, edgeTime));
                var elevated = Vector3.Lerp(World(DayRoutes.Bedside), new Vector3(1.05f, 1.22f, 2.05f), recline);
                var at = Vector3.Lerp(elevated, new Vector3(0, 1.22f, .65f), shift);
                actor.Body.SetPositionAndRotation(bed + yaw * at, yaw * Quaternion.Euler(-90 * recline, 0, 0));
                return treatment ? 1 - Mathf.SmoothStep(0, 1, Mathf.InverseLerp(1.35f, 1.75f, edgeTime)) : 0;
            }

            actor.Body.localPosition = inService
                ? actor.Root.InverseTransformVector(new Vector3(0, .8f, -.36f))
                : new Vector3(0, room.UsesOriginalArt ? .055f : 0f, 0);
            actor.Body.localRotation = inService
                ? Quaternion.Inverse(actor.Root.rotation) * Quaternion.Euler(-90, 0, 0)
                : Quaternion.identity;
            return patient.Stage is VisitStage.WalkingToTreatment or VisitStage.Leaving
                ? Mathf.InverseLerp(2.5f, .5f, System.Numerics.Vector2.Distance(patient.Position, DayRoutes.TreatmentApproach))
                : 0;
        }

        private static Vector3 World(System.Numerics.Vector2 point) => new(point.X, 0, point.Y);

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
            GUI.Label(new Rect(20, 0, 140, Header), "햇살병원", heading);
            foreach (var patient in day.Patients)
            {
                bool enabled = GUI.enabled;
                GUI.enabled = enabled && patient.Stage != VisitStage.NotArrived;
                string name = patient.Stage == VisitStage.Complete ? patient.Name + " ✓" : patient.Name;
                if (GUI.Button(new Rect(160 + (patient.Id - 1) * 96, 10, 90, 38), name,
                        selectedId == patient.Id ? primary : patientTag) && acceptInput)
                    Select(patient.Id);
                GUI.enabled = enabled;
            }
            bool controlsEnabled = GUI.enabled;
            GUI.enabled = controlsEnabled && day.Patients.Count == HospitalDay.BookingCount;
            if (GUI.Button(new Rect(width - 420, 10, 62, 38), "저장", patientTag) && acceptInput) SaveDay();
            if (GUI.Button(new Rect(width - 353, 10, 72, 38), "불러오기", patientTag) && acceptInput) LoadDay(reportMissing: true);
            GUI.enabled = controlsEnabled;
            GUI.Label(new Rect(width - 277, 0, 155, Header), $"운영 자금  {day.Funds:N0}만", label);
            if (GUI.Button(new Rect(width - 116, 8, 96, 42), day.Paused ? "재생" : "일시정지",
                    day.Paused ? primary : quiet) && acceptInput)
                day.TogglePause();

            float footer = height - Footer;
            Panel(new Rect(0, footer, width, Footer), Paper);
            Panel(new Rect(0, footer, width, 1), new Color(.84f, .80f, .70f));
            Panel(new Rect(20, footer + 15, 4, 23), day.Paused ? Coral : Mint);
            var selection = Selection;
            string status = day.Complete ? "첫날 운영 완료"
                : selection == null ? $"첫날 진료 · 귀가 {day.Departed}/{day.Patients.Count}"
                : $"{selection.Name} · {Status(selection.Stage)}";
            GUI.Label(new Rect(34, footer + 7, width - 255, 36), status, heading);
            string guidance = Time.unscaledTime < saveNoticeUntil ? saveNotice : Guidance(selection);
            GUI.Label(new Rect(34, footer + 42, width - 255, 34), guidance, label);
            string action = selection?.Stage switch
            {
                VisitStage.Reception => "접수하기",
                VisitStage.AwaitingPlan => "계획 지시",
                _ => null
            };
            if (action != null)
            {
                bool enabled = GUI.enabled;
                GUI.enabled = enabled && !day.Paused;
                if (GUI.Button(new Rect(width - 195, footer + 19, 175, 50), action, primary) && acceptInput)
                {
                    if (selection.Stage == VisitStage.Reception) day.Admit(selection.Id);
                    else day.AssignPlan(selection.Id);
                }
                GUI.enabled = enabled;
            }

            if (selection != null && selection.Stage is VisitStage.Reception or VisitStage.AwaitingPlan)
            {
                var marker = room.Camera.WorldToScreenPoint(World(selection.Position) + Vector3.up * 2.13f);
                var rect = new Rect(marker.x / scale - 43, (Screen.height - marker.y) / scale - 30, 86, 28);
                GUI.Label(rect, selection.Name, primary);
            }
        }

        private void SaveDay()
        {
            try
            {
                save.Save(day);
                SetSaveNotice("첫날 진료를 저장했어요");
            }
            catch (Exception error) when (error is IOException or UnauthorizedAccessException or NotSupportedException)
            {
                Debug.LogWarning($"[Hospital Save] Write failed ({error.GetType().Name}).");
                SetSaveNotice("저장하지 못했어요 · 저장 공간을 확인해 주세요");
            }
        }

        private void LoadDay(bool reportMissing)
        {
            HospitalLoadResult result = save.Load(room.UsesOriginalArt, out HospitalDay restored);
            if (restored != null) SetDay(restored);
            string message = result switch
            {
                HospitalLoadResult.Loaded => "저장한 진료를 불러왔어요 · 재생을 눌러주세요",
                HospitalLoadResult.RecoveredBackup => "직전 백업을 불러왔어요 · 재생을 눌러주세요",
                HospitalLoadResult.Unreadable => "저장 파일을 읽지 못했어요 · 현재 진료는 유지됩니다",
                _ => reportMissing ? "저장한 진료가 없어요" : null
            };
            if (message != null) SetSaveNotice(message);
        }

        private void SetSaveNotice(string message)
        {
            saveNotice = message;
            saveNoticeUntil = Time.unscaledTime + 6f;
        }

        private string Guidance(PatientVisit patient)
        {
            if (day.Complete) return $"귀가 {day.Departed}/{day.Patients.Count}명 · 오늘 수입 {day.Income:N0}만";
            if (day.Paused) return "일시정지 중 · 재생을 누르면 이어집니다";
            if (patient == null) return "환자 또는 상단 이름을 눌러주세요";
            if (patient.Duration > 0f) return $"{Mathf.CeilToInt(patient.Duration - patient.Elapsed)}초 남음";
            int rank = day.Rank(patient.Id);
            if (rank > 0) return $"대기 {rank}번째 · 차례가 오면 자동으로 이어집니다";
            return patient.Stage switch
            {
                VisitStage.Entering => "입장이 끝나면 접수할 수 있어요",
                VisitStage.Reception => "접수하면 CT 순서가 정해집니다",
                VisitStage.WalkingToPlanning => "계획실에 도착하면 지시할 수 있어요",
                VisitStage.AwaitingPlan => "치료 전에 계획 지시가 필요해요",
                VisitStage.Leaving or VisitStage.Complete => "오늘 일정 완료 · 수입 +200만",
                _ => "시설 예약 완료 · 도착하면 자동으로 진행합니다"
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
                foreach (var patient in day.Patients)
                {
                    var source = actors[patient.Id - 1];
                    if (!source.Root.gameObject.activeSelf) continue;
                    var actor = before.CreatePatient(patient);
                    actor.Root.SetPositionAndRotation(source.Root.position, source.Root.rotation);
                    actor.Selection.gameObject.SetActive(patient.Id == selectedId);
                }
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

        private static string Status(VisitStage stage) => stage switch
        {
            VisitStage.Entering => "병원에 도착했어요",
            VisitStage.Reception => "접수를 기다리고 있어요",
            VisitStage.CtQueue => "CT 대기",
            VisitStage.WalkingToCt => "CT실로 이동 중",
            VisitStage.Ct => "CT 촬영 중",
            VisitStage.WalkingToPlanning => "계획실로 이동 중",
            VisitStage.AwaitingPlan => "치료 계획 지시 대기",
            VisitStage.PlanQueue => "계획 검토 대기",
            VisitStage.Planning => "치료 계획 검토 중",
            VisitStage.TreatmentQueue => "치료실 대기",
            VisitStage.WalkingToTreatment => "치료실로 이동 중",
            VisitStage.Treatment => "방사선치료 중",
            VisitStage.Leaving => "치료를 마치고 귀가 중",
            _ => "환자가 귀가했어요"
        };

    }
}
