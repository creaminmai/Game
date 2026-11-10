class_name HospitalSimulation
extends RefCounted

signal changed
signal admitted(id: int)
signal plan_assigned(id: int)
const VISIT_FEE := 200
const EXPANSION_COST := 600
const SPEED := 2.1
const DURATIONS := {"ct_scan": 5.0, "planning": 5.0, "treatment": 30.0}
const STATES := ["entering", "waiting", "ct_queue", "walk_ct", "ct_scan", "walk_plan", "plan_ready", "plan_queue", "planning", "treatment_queue", "walk_treatment", "treatment", "leaving", "complete"]
const CAPTIONS := {
 "entering": "대기실로 이동", "waiting": "접수 필요", "ct_queue": "CT 대기",
 "walk_ct": "CT실로 이동", "ct_scan": "CT 촬영 중", "walk_plan": "계획실로 이동",
 "plan_ready": "계획 필요", "plan_queue": "계획 대기", "planning": "계획 검토 중",
 "treatment_queue": "치료 대기", "walk_treatment": "치료실로 이동",
 "treatment": "치료 중", "leaving": "귀가 중", "complete": "오늘 일정 완료"}
var patients: Array[Dictionary] = []
var day := 1
var lifetime_completed := 0
var time := 0.0
var next_arrival := 6.0
var money := 900
var expanded := false
var paused := false
var ct_owner := -1
var planner_owner := -1
var treatment_owners: Array[int] = [-1]
var serial := 0
var max_treating := 0
var ledger := HospitalDailyLedger.new()
var admission := HospitalAdmissionDuty.new()
var chapters := HospitalChapterProgress.new()
var operations := HospitalOperationsTraining.new()
var research := HospitalResearchLab.new()
var schedule := HospitalDailySchedule.new()

func _init() -> void:
 spawn()

func get_patient(id: int) -> Dictionary:
 for p in patients:
  if p.id == id: return p
 return {}

func wait_position(id: int) -> Vector3:
 return HospitalPatientProfiles.wait_position(id)

func plan_position(id: int) -> Vector3:
 if id >= 5: return Vector3(4.8,0,-1.8+(id-5)*.8)
 return Vector3(2.4 + ((id - 1) % 2) * 1.2, 0, -1.8 + floori((id - 1) / 2.0) * 0.8)

func spawn() -> void:
 if patients.size() >= schedule.today_count: return
 var id := patients.size() + 1
 var p := {"id": id, "name": HospitalPatientProfiles.patient_name(id,day), "state": "entering",
  "position": Vector3(0,0,6.6), "route": [], "next_state": "", "elapsed": 0.0,
  "service_duration":0.0, "room": -1, "paid": false, "queue_order": 0, "history": ["entering"],"admission_source":"none","plan_source":"none"}
 patients.append(p)
 travel(p, "entering", [Vector3(0,0,3), Vector3(-1.5,0,3), wait_position(id)], "waiting")
 changed.emit()

func set_state(p: Dictionary, state: String) -> void:
 p.state = state
 p.elapsed = 0.0
 p.service_duration = duration_for(state)
 p.history.append(state)
 if state == "complete":
  chapters.record_departure(day,p.id,schedule.today_count)
  operations.record_departure(day,p)
 changed.emit()

func travel(p: Dictionary, state: String, points: Array, destination: String) -> void:
 p.route = points.duplicate()
 if schedule.today_count == 6:
  for i in range(p.route.size()):
   var at: Vector3 = p.route[i]
   if is_zero_approx(at.x):
    at.x = -.34 if state in ["entering","walk_ct"] else .34
    p.route[i] = at
  if p.id == 6 and state == "entering": p.route.insert(p.route.size()-1,Vector3(-1.5,0,5.8))
  if p.id == 6 and state == "walk_ct": p.route.push_front(Vector3(-1.5,0,5.8))
  if state == "walk_plan" and p.id >= 5:
   p.route = [Vector3(-1.5,0,-2.8),Vector3(.34,0,-2.8),Vector3(.34,0,-1),Vector3(1.5,0,-1),Vector3(1.5,0,-2.6),Vector3(5.45,0,-2.6),Vector3(5.45,0,plan_position(p.id).z),plan_position(p.id)]
  if state == "walk_treatment" and p.id >= 5:
   p.route.push_front(Vector3(1.5,0,-.4))
   p.route.push_front(Vector3(5.45,0,-.4))
   p.route.push_front(Vector3(5.45,0,p.position.z))
 p.next_state = destination
 set_state(p, state)

func enqueue(p: Dictionary, state: String) -> void:
 serial += 1
 p.queue_order = serial
 set_state(p, state)

func completed() -> int:
 var total := 0
 for p in patients:
  if p.paid: total += 1
 return total

func all_done() -> bool:
 return patients.size() == schedule.today_count and count_state("complete") == schedule.today_count

func count_state(state: String) -> int:
 var total := 0
 for p in patients:
  if p.state == state: total += 1
 return total

func needs_action(p: Dictionary) -> bool:
 return p.state in ["waiting", "plan_ready"]

func needs_player_action(p: Dictionary) -> bool:
 return (p.state == "plan_ready" and not operations.enabled) or (p.state == "waiting" and not admission.enabled)

func set_admission_delegated(value: bool) -> bool:
 if not admission.set_enabled(value,day): return false
 changed.emit()
 return true

func next_action_patient(current: int) -> int:
 # Cycle only on an explicit user action; never steal a selection during refresh.
 for offset in range(1, schedule.today_count + 1):
  var id := ((maxi(current, 0) + offset - 1) % schedule.today_count) + 1
  var p := get_patient(id)
  if not p.is_empty() and needs_player_action(p): return id
 return -1

func queue_rank(id: int) -> int:
 var p := get_patient(id)
 if p.is_empty() or not p.state.ends_with("_queue"): return 0
 var rank := 1
 for other in patients:
  if other.state == p.state and other.queue_order < p.queue_order: rank += 1
 return rank

func status_text(id: int) -> String:
 var p := get_patient(id)
 if p.is_empty(): return "도착 예정 · %d초 후" % maxi(0, ceili((id - 1) * 6.0 - time))
 var caption: String = CAPTIONS[p.state]
 if p.state == "waiting" and admission.enabled: caption = "민지 접수"
 if p.state == "plan_ready" and operations.enabled: caption = "계획 준비" if operations.candidate_id == id else "지시 대기"
 var rank := queue_rank(id)
 if rank > 0: caption += " · %d번째" % rank
 return caption

func admit(id: int, automatic: bool = false) -> bool:
 var p := get_patient(id)
 if paused or p.is_empty() or p.state != "waiting": return false
 if automatic and (not admission.enabled or admission.candidate_id != id or admission.elapsed+.000001 < admission.DELAY): return false
 p.admission_source = "minji" if automatic else "manual"
 if admission.candidate_id == id: admission.reset_pending()
 enqueue(p, "ct_queue")
 dispatch()
 admitted.emit(id)
 return true

func assign_plan(id: int, automatic: bool = false) -> bool:
 var p := get_patient(id)
 if paused or p.is_empty() or p.state != "plan_ready": return false
 if automatic and (not operations.trained or not operations.enabled or operations.candidate_id != id or operations.elapsed+.000001 < operations.DELAY): return false
 p.plan_source = "staff" if automatic else "manual"
 if operations.candidate_id == id: operations.reset_pending()
 enqueue(p, "plan_queue")
 dispatch()
 plan_assigned.emit(id)
 return true

func first_queued(state: String) -> Dictionary:
 var result: Dictionary = {}
 for p in patients:
  if p.state == state and (result.is_empty() or p.queue_order < result.queue_order): result = p
 return result

func dispatch() -> void:
 var p: Dictionary
 if ct_owner == -1:
  p = first_queued("ct_queue")
  if not p.is_empty():
   ct_owner = p.id
   travel(p, "walk_ct", [Vector3(-1.5,0,3),Vector3(0,0,3),Vector3(0,0,-2.8),Vector3(-1.5,0,-2.8),Vector3(-4,0,-2.8)], "ct_scan")
 if planner_owner == -1:
  p = first_queued("plan_queue")
  if not p.is_empty():
   planner_owner = p.id
   set_state(p, "planning")
 for room in range(treatment_owners.size()):
  if treatment_owners[room] != -1: continue
  p = first_queued("treatment_queue")
  if p.is_empty(): break
  treatment_owners[room] = p.id
  p.room = room
  var points: Array = [Vector3(1.5,0,-1),Vector3(0,0,-1),Vector3(0,0,3),Vector3(1.5,0,3)]
  if room == 1: points.append(Vector3(4,0,5.2)); points.append(Vector3(10,0,5.2))
  points.append(Vector3(4 + room * 6,0,3))
  travel(p, "walk_treatment", points, "treatment")

func tick(delta: float) -> void:
 if paused or delta <= 0: return
 # Small bounded steps keep movement and service completion stable at fast QA speeds.
 var remaining := delta
 while remaining > 0.00001:
  var step := minf(remaining, 0.1)
  _step(step)
  remaining -= step

func _step(delta: float) -> void:
 time += delta
 while patients.size() < schedule.today_count and time + 0.000001 >= next_arrival:
  spawn()
  next_arrival += 6.0
 for p in patients:
  if not p.route.is_empty():
   # Let the departing patient clear the shared couch approach. The next room
   # is still reserved normally; no clinical time, queue or payment is skipped.
   var passage_busy := false
   if schedule.today_count == 6 and p.state == "walk_treatment":
    for other in patients:
     if other.id != p.id and other.state == "leaving" and other.room == p.room and other.route.size() > 1: passage_busy = true
     if p.room == 1 and other.room == 0 and other.state == "treatment" and (other.elapsed < 1.7 or service_duration(other)-other.elapsed < 1.7): passage_busy = true
   if passage_busy: continue
   var distance := SPEED * delta
   while distance > 0 and not p.route.is_empty():
    var target: Vector3 = p.route[0]
    var length: float = p.position.distance_to(target)
    if length <= distance:
     p.position = target
     distance -= length
     p.route.pop_front()
    else:
     p.position = p.position.move_toward(target, distance)
     distance = 0
   if p.route.is_empty(): set_state(p, p.next_state)
  elif DURATIONS.has(p.state):
   p.elapsed += delta
   if p.elapsed+.000001 >= service_duration(p):
    match p.state:
     "ct_scan":
      ct_owner = -1
      travel(p, "walk_plan", [Vector3(-1.5,0,-2.8),Vector3(0,0,-2.8),Vector3(0,0,-1),Vector3(1.5,0,-1),plan_position(p.id)], "plan_ready")
     "planning":
      planner_owner = -1
      enqueue(p, "treatment_queue")
     "treatment":
      if not p.paid:
       p.paid = true
       money += VISIT_FEE
       ledger.income += VISIT_FEE
       lifetime_completed += 1
      treatment_owners[p.room] = -1
      var points: Array = []
      if p.room == 1: points = [Vector3(10,0,5.2),Vector3(4,0,5.2)]
      points.append(Vector3(1.5,0,3)); points.append(Vector3(0,0,3)); points.append(Vector3(0,0,7))
      travel(p, "leaving", points, "complete")
 admission.tick(self,delta)
 operations.tick(self,delta)
 dispatch()
 max_treating = maxi(max_treating, count_state("treatment"))
 chapters.observe(self)
 if all_done(): schedule.record_close(day,count_state("complete"))
 research.close_operating_day(self)

func duration_for(state: String) -> float:
 if state == "ct_scan" and research.applied("ct"): return 4.0
 if state == "planning" and research.applied("plan"): return 4.0
 return DURATIONS.get(state,0.0)

static func service_duration(p: Dictionary) -> float:
 return float(p.get("service_duration",DURATIONS.get(p.state,0.0)))

func purchase_lab() -> bool:
 if research.build_reason(self) != "": return false
 money -= research.BUILD_COST
 ledger.lab_expense = research.BUILD_COST
 research.record_build(self)
 changed.emit()
 return true

func start_research(id: String) -> bool:
 if research.start_reason(self,id) != "": return false
 money -= research.COST
 ledger.research_expense += research.COST
 research.record_start(day,id)
 changed.emit()
 return true

func training_reason() -> String:
 if operations.trained: return "운영 교육 완료"
 if chapters.chapter_two_day == 0: return "2장 완료 후 이용해요 · 교육비 500만"
 if money < operations.COST: return "자금이 부족해요 · 500만 필요"
 return ""

func purchase_training() -> bool:
 if not training_reason().is_empty(): return false
 money -= operations.COST
 ledger.training_expense = operations.COST
 operations.trained = true
 operations.purchased_day = day
 operations.set_enabled(false)
 operations.finish_scene()
 if not "introduction" in operations.seen: operations.seen.append("introduction")
 changed.emit()
 return true

func set_plan_delegated(value: bool) -> bool:
 if not operations.set_enabled(value): return false
 changed.emit()
 return true

func expansion_reason() -> String:
 if expanded: return "치료별관 운영 중"
 if lifetime_completed < 1: return "첫 환자 치료 후 열려요"
 if money < EXPANSION_COST: return "자금이 부족해요 · 600만 필요"
 return ""

func purchase_expansion() -> bool:
 if not expansion_reason().is_empty(): return false
 money -= EXPANSION_COST
 ledger.expansion_expense = EXPANSION_COST
 ledger.new_annex = true
 expanded = true
 treatment_owners.append(-1)
 dispatch()
 changed.emit()
 return true

func start_next_day(count: int = -1) -> bool:
 if count == -1: count = schedule.preferred_count if expanded else 4
 if not count in [4,6] or (count == 6 and not expanded) or not all_done(): return false
 schedule.record_close(day,count_state("complete"))
 chapters.observe(self)
 research.close_operating_day(self)
 chapters.close_day(day)
 operations.close_day(day)
 day += 1
 schedule.next_day(count)
 ledger.start_day(money)
 research.apply_before_arrivals(day)
 patients.clear()
 time = 0.0
 next_arrival = 6.0
 serial = 0
 admission.reset_pending()
 ct_owner = -1
 planner_owner = -1
 treatment_owners.assign([-1, -1] if expanded else [-1])
 spawn()
 changed.emit()
 return true

func snapshot() -> Dictionary:
 var saved: Array = []
 for p in patients:
  var copy: Dictionary = p.duplicate(true)
  copy.position = [p.position.x,p.position.y,p.position.z]
  copy.route = []
  for point in p.route: copy.route.append([point.x,point.y,point.z])
  saved.append(copy)
 return {"version": 2,"implementation": "sunshine-rebuild-2026-11", "day": day,"lifetime_completed": lifetime_completed,"time": time,"next_arrival": next_arrival,
  "money": money,"expanded": expanded,"serial": serial,"max_treating": max_treating,"patients": saved,"daily_ledger":ledger.snapshot(),"staff_admission":admission.snapshot(),"chapter_progress":chapters.snapshot(),"operations_training":operations.snapshot(),"research_lab":research.snapshot(),"daily_schedule":schedule.snapshot()}

static func whole(value: Variant, low: int, high: int) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= low and value <= high

static func finite_number(value: Variant, low: float, high: float) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high

static func valid_point(value: Variant) -> bool:
 if not value is Array or value.size() != 3: return false
 return finite_number(value[0],-20,20) and finite_number(value[1],0,0) and finite_number(value[2],-12,12)

func restore(data: Variant) -> bool:
 # Validate a candidate completely before applying. No old source exists to verify v1 migration.
 if not data is Dictionary or data.get("version") != 2: return false
 if data.get("implementation") != "sunshine-rebuild-2026-11": return false
 for field in ["day","lifetime_completed","money","serial","max_treating"]:
  if not whole(data.get(field), 1 if field == "day" else 0, 100000000): return false
 if not data.get("expanded") is bool: return false
 var booking: Variant = data.get("daily_schedule")
 if booking != null and not booking is Dictionary: return false
 if booking != null and not whole(booking.get("today_count"),4,6): return false
 var today: int = int(booking.get("today_count",0)) if booking != null else 4
 if not today in [4,6] or (today == 6 and (not data.expanded or data.day == 1)): return false
 if not finite_number(data.get("time"),0,100000000) or not finite_number(data.get("next_arrival"),6,today*6): return false
 if not data.get("patients") is Array or data.patients.size() < 1 or data.patients.size() > today: return false
 var candidate: Array[Dictionary] = []
 var ct := -1
 var planner := -1
 var rooms: Array[int] = []
 rooms.assign([-1,-1] if data.expanded else [-1])
 var ids: Array[int] = []
 var orders: Array[int] = []
 var paid_count := 0
 for raw in data.patients:
  if not raw is Dictionary: return false
  if not whole(raw.get("id"),1,today) or int(raw.id) in ids: return false
  if not raw.get("name") is String or raw.name.length() > 40: return false
  if not raw.get("state") in STATES or not raw.get("paid") is bool: return false
  if not whole(raw.get("room"),-1,rooms.size()-1): return false
  if not finite_number(raw.get("elapsed"),0,30.1): return false
  if not whole(raw.get("queue_order"),0,int(data.serial)): return false
  if not valid_point(raw.get("position")): return false
  if not raw.get("route") is Array or raw.route.size() > 16: return false
  if not raw.get("next_state") is String or (raw.next_state != "" and not raw.next_state in STATES): return false
  if not raw.get("history") is Array or raw.history.size() > 64: return false
  for state in raw.history:
   if not state in STATES: return false
  var moving: bool = raw.state in ["entering","walk_ct","walk_plan","walk_treatment","leaving"]
  if moving != (not raw.route.is_empty()): return false
  var destinations := {"entering":"waiting","walk_ct":"ct_scan","walk_plan":"plan_ready","walk_treatment":"treatment","leaving":"complete"}
  if moving and raw.next_state != destinations[raw.state]: return false
  if raw.paid != (raw.state in ["leaving","complete"]): return false
  if raw.paid: paid_count += 1
  if raw.state.ends_with("_queue"):
   if raw.queue_order == 0 or int(raw.queue_order) in orders: return false
   orders.append(int(raw.queue_order))
  if raw.state in ["walk_ct","ct_scan"]:
   if ct != -1: return false
   ct = int(raw.id)
  if raw.state == "planning":
   if planner != -1: return false
   planner = int(raw.id)
  if raw.state in ["walk_treatment","treatment"]:
   if raw.room < 0 or rooms[int(raw.room)] != -1: return false
   rooms[int(raw.room)] = int(raw.id)
  if raw.state in ["leaving","complete"] and raw.room < 0: return false
  var p: Dictionary = raw.duplicate(true)
  var admitted_before: bool = STATES.find(p.state) >= STATES.find("ct_queue")
  var planned_before: bool = STATES.find(p.state) >= STATES.find("plan_queue")
  if raw.has("admission_source") != raw.has("plan_source"): return false
  if data.has("operations_training") and not raw.has("admission_source"): return false
  p.admission_source = raw.get("admission_source","legacy" if admitted_before else "none")
  p.plan_source = raw.get("plan_source","legacy" if planned_before else "none")
  if not p.admission_source in ["none","manual","minji","legacy"] or not p.plan_source in ["none","manual","staff","legacy"]: return false
  if (p.admission_source != "none") != admitted_before or (p.plan_source != "none") != planned_before: return false
  if p.admission_source == "minji" and data.day < 2: return false
  p.service_duration = raw.get("service_duration",DURATIONS.get(p.state,0.0))
  if not finite_number(p.service_duration,0,30): return false
  if DURATIONS.has(p.state):
   if not float(p.service_duration) in ([4.0,5.0] if p.state != "treatment" else [30.0]): return false
   if p.elapsed >= p.service_duration+.00001: return false
  elif p.service_duration != 0: return false
  p.id = int(p.id); p.room = int(p.room); p.queue_order = int(p.queue_order)
  p.position = Vector3(raw.position[0],raw.position[1],raw.position[2])
  p.route = []
  for point in raw.route:
   if not valid_point(point): return false
   p.route.append(Vector3(point[0],point[1],point[2]))
  ids.append(p.id)
  candidate.append(p)
 for id in range(1,candidate.size()+1):
  if not id in ids: return false
 if data.lifetime_completed < paid_count or data.next_arrival != minf(today*6.0, candidate.size()*6.0): return false
 var done: bool = candidate.size() == today and candidate.all(func(p): return p.state == "complete")
 var candidate_schedule := HospitalDailySchedule.from_save(booking,int(data.day),data.expanded,done,int(data.lifetime_completed),paid_count)
 if candidate_schedule == null: return false
 var candidate_ledger := HospitalDailyLedger.from_save(data.get("daily_ledger"),paid_count,int(data.money),data.expanded)
 if candidate_ledger == null: return false
 var candidate_admission := HospitalAdmissionDuty.from_save(data.get("staff_admission"),int(data.day),candidate)
 if candidate_admission == null: return false
 var candidate_chapters := HospitalChapterProgress.from_save(data.get("chapter_progress"),int(data.day),int(data.lifetime_completed),candidate,data.expanded,candidate_schedule)
 if candidate_chapters == null: return false
 var candidate_operations := HospitalOperationsTraining.from_save(data.get("operations_training"),int(data.day),candidate,candidate_chapters.chapter_two_day,candidate_ledger.training_expense,candidate_schedule)
 if candidate_operations == null: return false
 var candidate_research := HospitalResearchLab.from_save(data.get("research_lab"),int(data.day),done,candidate_operations.chapter_three_day,candidate_ledger)
 if candidate_research == null: return false
 for p in candidate:
  if p.service_duration == 4 and not candidate_research.applied("ct" if p.state == "ct_scan" else "plan"): return false
 schedule = candidate_schedule
 research = candidate_research
 operations = candidate_operations
 chapters = candidate_chapters
 admission = candidate_admission
 ledger = candidate_ledger
 patients = candidate
 day = int(data.day); lifetime_completed = int(data.lifetime_completed)
 money = int(data.money); expanded = data.expanded
 time = float(data.time); next_arrival = float(data.next_arrival)
 serial = int(data.serial); max_treating = int(data.max_treating)
 ct_owner = ct; planner_owner = planner; treatment_owners = rooms
 chapters.observe(self)
 paused = true
 changed.emit()
 return true
