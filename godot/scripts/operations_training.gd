class_name HospitalOperationsTraining
extends RefCounted
# One optional planning duty. Clinical work still uses the existing FIFO planner.
const COST := 500
const DELAY := 3.0
const SCENES := ["introduction","educated"]
var trained := false
var purchased_day := 0
var enabled := false
var candidate_id := -1
var elapsed := 0.0
var archived_visits := 0
var through_day := 0
var visits: Array[String] = []
var chapter_three_day := 0
var presented := false
var seen: Array[String] = []
var active := ""
var line := 0

func total() -> int: return archived_visits+visits.size()

func reset_pending() -> void:
 candidate_id = -1
 elapsed = 0.0

func set_enabled(value: bool) -> bool:
 if value and not trained: return false
 enabled = value
 reset_pending()
 return true

func first_ready(sim: HospitalSimulation) -> Dictionary:
 var first: Dictionary = {}
 for p in sim.patients:
  if p.state == "plan_ready" and (first.is_empty() or p.queue_order < first.queue_order): first = p
 return first

func tick(sim: HospitalSimulation, delta: float) -> void:
 if not trained or not enabled: return
 var first := first_ready(sim)
 var id: int = first.get("id",-1)
 if id != candidate_id:
  reset_pending()
  candidate_id = id
 if id < 0: return
 elapsed += delta
 if elapsed+.000001 < DELAY: return
 sim.assign_plan(id,true)
 reset_pending()

func record_departure(day: int, p: Dictionary) -> void:
 if not trained or day <= through_day or p.admission_source != "minji" or p.plan_source != "staff": return
 var key := "%d:%d" % [day,p.id]
 if not key in visits: visits.append(key)
 if chapter_three_day == 0 and total() >= 4: chapter_three_day = day

func close_day(day: int) -> void:
 if day <= through_day: return
 archived_visits += visits.size()
 visits.clear()
 through_day = day
 reset_pending()

func finish_scene() -> void:
 if active != "" and not active in seen: seen.append(active)
 active = ""
 line = 0

func next_line() -> void:
 line += 1
 if active != "introduction" or line >= 2: finish_scene()

func guidance_changed(enabled_guidance: bool, sim: HospitalSimulation) -> void:
 finish_scene()
 if enabled_guidance:
  if sim.chapters.chapter_two_day > 0 and not "introduction" in seen: seen.append("introduction")
  if trained and not "educated" in seen: seen.append("educated")

func sync_story(sim: HospitalSimulation, enabled_guidance: bool, allow_new: bool) -> void:
 if not enabled_guidance: finish_scene(); return
 if active != "" or not allow_new or sim.chapters.chapter_two_day == 0 or chapter_three_day > 0: return
 if trained and not "educated" in seen: active = "educated"
 elif not trained and not sim.all_done() and not "introduction" in seen: active = "introduction"

func speech() -> Array:
 if active == "educated": return ["민지","함께 맡을 일을 정하니\n훨씬 든든하네요."]
 if line == 0: return ["민지","접수는 익숙해졌어요.\n계획 확인도 함께\n나눠 맡아 볼까요?"]
 return ["박 선생","확인 순서를 정리하면\n준비된 분부터\n제가 맡을 수 있어요."]

func snapshot() -> Dictionary:
 return {"version":1,"trained":trained,"purchased_day":purchased_day,"enabled":enabled,"candidate_id":candidate_id,"elapsed":elapsed,"archived_visits":archived_visits,"through_day":through_day,"visits":visits.duplicate(),"chapter_three_day":chapter_three_day,"presented":presented,"seen":seen.duplicate(),"active":active,"line":line}

static func from_save(data: Variant, day: int, patients: Array[Dictionary], chapter_two_day: int, training_expense: int) -> HospitalOperationsTraining:
 var result := HospitalOperationsTraining.new()
 result.through_day = day-1
 if data == null:
  if training_expense != 0: return null
  for p in patients:
   if p.plan_source == "staff": return null
  return result # Past manual/unknown commands never become delegated visits.
 if not data is Dictionary or data.get("version") != 1: return null
 for field in ["trained","enabled","presented"]:
  if not data.get(field) is bool: return null
 if not HospitalSimulation.whole(data.get("purchased_day"),0,day): return null
 if data.trained != (data.purchased_day > 0): return null
 if data.trained and (chapter_two_day == 0 or data.purchased_day < chapter_two_day): return null
 if (training_expense == COST) != (data.trained and data.purchased_day == day): return null
 if data.enabled and not data.trained: return null
 if not HospitalSimulation.whole(data.get("candidate_id"),-1,patients.size()) or data.candidate_id == 0: return null
 if not HospitalSimulation.finite_number(data.get("elapsed"),0,DELAY): return null
 if (not data.enabled or data.candidate_id == -1) and (data.candidate_id != -1 or data.elapsed != 0): return null
 var complete_keys: Array[String] = []
 var candidate_valid: bool = data.candidate_id == -1
 for p in patients:
  if p.plan_source == "staff" and not data.trained: return null
  if p.id == data.candidate_id and p.state == "plan_ready": candidate_valid = true
  if p.state == "complete" and p.admission_source == "minji" and p.plan_source == "staff": complete_keys.append("%d:%d" % [day,p.id])
 if not candidate_valid: return null
 if not HospitalSimulation.whole(data.get("through_day"),day-1,day-1): return null
 if not HospitalSimulation.whole(data.get("archived_visits"),0,maxi(0,day-int(data.purchased_day))*4): return null
 if not data.get("visits") is Array or data.visits.size() > 4: return null
 var keys: Array[String] = []
 for key in data.visits:
  if not key is String or key in keys: return null
  keys.append(key)
 keys.sort(); complete_keys.sort()
 if keys != complete_keys: return null
 if not data.trained and (data.archived_visits != 0 or not keys.is_empty()): return null
 if not HospitalSimulation.whole(data.get("chapter_three_day"),0,day): return null
 if (data.chapter_three_day > 0) != (data.trained and data.archived_visits+keys.size() >= 4): return null
 if data.chapter_three_day > 0 and data.chapter_three_day < data.purchased_day: return null
 if data.presented and data.chapter_three_day == 0: return null
 if not data.get("seen") is Array or data.seen.size() > SCENES.size(): return null
 for id in data.seen:
  if not id in SCENES or id in result.seen: return null
  result.seen.append(id)
 if not data.get("active") is String or (data.active != "" and not data.active in SCENES) or data.active in result.seen: return null
 if not HospitalSimulation.whole(data.get("line"),0,1): return null
 if data.active != "introduction" and data.line != 0: return null
 if data.active == "educated" and not data.trained: return null
 for field in ["trained","enabled","presented","active"]: result.set(field,data[field])
 for field in ["purchased_day","candidate_id","archived_visits","through_day","chapter_three_day","line"]: result.set(field,int(data[field]))
 result.elapsed = float(data.elapsed); result.visits.assign(data.visits)
 return result
