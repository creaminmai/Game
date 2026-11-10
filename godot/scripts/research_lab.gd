class_name HospitalResearchLab
extends RefCounted
# All money/point changes have immutable receipts. Closing a day is an operating
# event, never a side effect of opening a journal or restoring a save.
const BUILD_COST := 1800
const COST := 500
const POINT_COST := 6
const CAP := 200
const PROJECTS := {"ct":"CT 촬영 흐름 개선 I","plan":"계획 협업 개선 I"}
const SCENES := ["introduction","applied"]
var built_day := 0
var points := 0
var closed_through := 0
var projects := {}
var events: Array[Dictionary] = []
var chapter_four_day := 0
var presented := false
var seen: Array[String] = []
var active := ""
var line := 0

func slot() -> String:
 for id in projects:
  if projects[id].applied_day == 0: return id
 return ""

func applied(id: String) -> bool:
 return projects.has(id) and projects[id].applied_day > 0

func build_reason(sim: HospitalSimulation) -> String:
 if built_day > 0: return "연구소 1단계 운영 중"
 if sim.operations.chapter_three_day == 0: return "3장 완료 후 설립할 수 있어요"
 if sim.money < BUILD_COST: return "자금 부족 · 설립비 1,800만 필요"
 return ""

func start_reason(sim: HospitalSimulation, id: String) -> String:
 if not PROJECTS.has(id): return "연구 항목을 확인해 주세요"
 if built_day == 0: return "연구소 1단계를 먼저 설립해 주세요"
 if projects.has(id): return "이미 적용한 연구예요" if applied(id) else "이미 시작한 연구예요"
 if slot() != "": return "다른 연구가 진행·적용 대기 중이에요 · 슬롯 1개"
 if sim.money < COST: return "자금 부족 · 500만 필요"
 if points < POINT_COST: return "연구점수 부족 · 6점 필요"
 return ""

func record_build(sim: HospitalSimulation) -> void:
 # A purchase after today's normal close must never earn today's production.
 if sim.all_done(): closed_through = sim.day
 built_day = sim.day
 points = 6
 events.append({"kind":"build","day":sim.day,"points":6,"money":BUILD_COST,"after_close":sim.all_done()})

func record_start(day: int, id: String) -> void:
 points -= POINT_COST
 projects[id] = {"start_day":day,"progress_days":0,"completed_day":0,"applied_day":0}
 events.append({"kind":"start","day":day,"id":id,"points":-POINT_COST,"money":COST})

func close_operating_day(sim: HospitalSimulation) -> void:
 if not sim.all_done() or sim.ledger.income <= 0 or sim.day <= closed_through: return
 closed_through = sim.day
 if built_day == 0: return
 var gained := mini(4,CAP-points)
 points += gained
 events.append({"kind":"produce","day":sim.day,"points":gained,"money":0})
 var id := slot()
 if id != "" and projects[id].completed_day == 0 and sim.day > projects[id].start_day:
  projects[id].progress_days = 1
  projects[id].completed_day = sim.day
  events.append({"kind":"complete","day":sim.day,"id":id,"points":0,"money":0})

func apply_before_arrivals(day: int) -> void:
 var id := slot()
 if id == "" or projects[id].completed_day == 0 or day <= projects[id].completed_day: return
 projects[id].applied_day = day
 events.append({"kind":"apply","day":day,"id":id,"points":0,"money":0})
 if chapter_four_day == 0: chapter_four_day = day

func daily(day: int) -> Dictionary:
 var result := {"initial":0,"produced":0,"used":0,"lab_expense":0,"research_expense":0,"completed":[],"applied":[]}
 for e in events:
  if e.day != day: continue
  match e.kind:
   "build": result.initial += e.points; result.lab_expense += e.money
   "produce": result.produced += e.points
   "start": result.used -= e.points; result.research_expense += e.money
   "complete": result.completed.append(e.id)
   "apply": result.applied.append(e.id)
 return result

func status(id: String) -> String:
 if not projects.has(id): return "미시작 · 시작 다음 운영일의 마감까지"
 var p: Dictionary = projects[id]
 if p.applied_day > 0: return "%d일차부터 적용 완료 ✓" % p.applied_day
 if p.completed_day > 0: return "연구 완료 · 적용 대기\n%d일차부터 적용 · 슬롯 사용 중" % (p.completed_day+1)
 return "%d일차 마감 예정 / %d일차부터 적용\n진행 0/1일 · 시작한 날은 제외" % [p.start_day+1,p.start_day+2]

func finish_scene() -> void:
 if active != "" and not active in seen: seen.append(active)
 active = ""; line = 0

func next_line() -> void:
 line += 1
 if active != "introduction" or line >= 2: finish_scene()

func guidance_changed(enabled: bool) -> void:
 finish_scene()
 if enabled:
  if built_day > 0 and not "introduction" in seen: seen.append("introduction")
  if chapter_four_day > 0 and not "applied" in seen: seen.append("applied")

func sync_story(enabled: bool, allow_new: bool) -> void:
 if not enabled: finish_scene(); return
 if active != "" or not allow_new or built_day == 0: return
 if chapter_four_day > 0 and not "applied" in seen:
  if not "introduction" in seen: seen.append("introduction")
  active = "applied"
 elif not "introduction" in seen: active = "introduction"

func speech() -> Array:
 if active == "applied": return ["윤서진","첫 개선을 적용했어요.\n실제 운영에서도\n살펴볼게요."]
 if line == 0: return ["윤서진","진료 기록을 모으면\n기다림을 줄일 방법을\n찾을 수 있어요."]
 return ["민지","병원에서 느낀 불편을\n하나씩 고쳐 보는\n거군요."]

func snapshot() -> Dictionary:
 return {"version":1,"built_day":built_day,"initial_granted":built_day>0,"points":points,"closed_through":closed_through,"projects":projects.duplicate(true),"events":events.duplicate(true),"chapter_four_day":chapter_four_day,"presented":presented,"seen":seen.duplicate(),"active":active,"line":line}

static func from_save(data: Variant, day: int, done: bool, chapter_three_day: int, ledger: HospitalDailyLedger) -> HospitalResearchLab:
 var r := HospitalResearchLab.new()
 r.closed_through = day if done else day-1
 if data == null:
  if ledger.lab_expense != 0 or ledger.research_expense != 0: return null
  return r
 if not data is Dictionary or data.get("version") != 1: return null
 if not HospitalSimulation.whole(data.get("closed_through"),day-1,day): return null
 if data.closed_through == day and not done: return null
 if not data.get("events") is Array or not data.get("projects") is Dictionary: return null
 if not data.get("initial_granted") is bool or not data.get("presented") is bool: return null
 for field in ["built_day","chapter_four_day"]:
  if not HospitalSimulation.whole(data.get(field),0,day): return null
 if not HospitalSimulation.whole(data.get("points"),0,CAP): return null
 var last_day := 0
 var production_days: Array[int] = []
 var after_close := false
 for raw in data.events:
  if not raw is Dictionary or not raw.get("kind") in ["build","produce","start","complete","apply"]: return null
  if not HospitalSimulation.whole(raw.get("day"),maxi(1,last_day),day): return null
  if not HospitalSimulation.whole(raw.get("points"),-6,6) or not HospitalSimulation.whole(raw.get("money"),0,BUILD_COST): return null
  var d := int(raw.day)
  last_day = d
  var id: String = raw.get("id","") if raw.get("id","") is String else ""
  if raw.kind in ["start","complete","apply"] and not PROJECTS.has(id): return null
  if raw.kind != "build" and r.built_day == 0: return null
  match raw.kind:
   "build":
    if r.built_day != 0 or chapter_three_day == 0 or d < chapter_three_day or raw.points != 6 or raw.money != BUILD_COST or not raw.get("after_close") is bool: return null
    r.built_day = d; r.points = 6; after_close = raw.after_close
   "produce":
    if d > data.closed_through or d in production_days or (d == r.built_day and after_close) or raw.money != 0 or raw.points != mini(4,CAP-r.points): return null
    production_days.append(d); r.points += int(raw.points)
   "start":
    if r.slot() != "" or r.projects.has(id) or r.points < POINT_COST or raw.points != -POINT_COST or raw.money != COST: return null
    r.points -= POINT_COST
    r.projects[id] = {"start_day":d,"progress_days":0,"completed_day":0,"applied_day":0}
   "complete":
    if not r.projects.has(id) or r.projects[id].completed_day > 0 or d != r.projects[id].start_day+1 or d > data.closed_through or not d in production_days or raw.points != 0 or raw.money != 0: return null
    r.projects[id].progress_days = 1; r.projects[id].completed_day = d
   "apply":
    if not r.projects.has(id) or r.projects[id].completed_day == 0 or r.projects[id].applied_day > 0 or d != r.projects[id].completed_day+1 or raw.points != 0 or raw.money != 0: return null
    r.projects[id].applied_day = d
    if r.chapter_four_day == 0: r.chapter_four_day = d
  var receipt: Dictionary = raw.duplicate(true)
  for field in ["day","points","money"]: receipt[field] = int(receipt[field])
  r.events.append(receipt)
 if r.built_day > 0:
  var first_production := r.built_day+(1 if after_close else 0)
  if production_days.size() != maxi(0,int(data.closed_through)-first_production+1): return null
 for id in r.projects:
  var p: Dictionary = r.projects[id]
  if p.completed_day == 0 and data.closed_through > p.start_day: return null
  if p.completed_day > 0 and p.applied_day == 0 and day > p.completed_day: return null
 if data.built_day != r.built_day or data.initial_granted != (r.built_day > 0) or data.points != r.points or data.chapter_four_day != r.chapter_four_day: return null
 if data.projects.size() != r.projects.size(): return null
 for id in r.projects:
  if not data.projects.has(id) or not data.projects[id] is Dictionary or data.projects[id].size() != 4: return null
  for field in ["start_day","progress_days","completed_day","applied_day"]:
   if not HospitalSimulation.whole(data.projects[id].get(field),0,day) or int(data.projects[id][field]) != r.projects[id][field]: return null
 var daily_record := r.daily(day)
 if daily_record.lab_expense != ledger.lab_expense or daily_record.research_expense != ledger.research_expense: return null
 if data.presented and r.chapter_four_day == 0: return null
 if not data.get("seen") is Array or data.seen.size() > SCENES.size(): return null
 for id in data.seen:
  if not id in SCENES or id in r.seen: return null
  r.seen.append(id)
 if not data.get("active") is String or (data.active != "" and not data.active in SCENES) or data.active in r.seen: return null
 if not HospitalSimulation.whole(data.get("line"),0,1) or (data.active != "introduction" and data.line != 0): return null
 if (data.active != "" or not r.seen.is_empty()) and r.built_day == 0: return null
 if (data.active == "applied" or "applied" in r.seen) and r.chapter_four_day == 0: return null
 r.closed_through = int(data.closed_through); r.presented = data.presented
 r.active = data.active; r.line = int(data.line)
 return r
