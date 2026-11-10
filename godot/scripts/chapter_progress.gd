class_name HospitalChapterProgress
extends RefCounted
# Operational evidence only; no payments, purchases or automatic commands.
const TARGET := 12
const SCENES := ["annex_absent","annex_ready","dual"]
var archived_visits := 0
var through_day := 0
var visits: Array[String] = []
var dual_experienced := false
var chapter_one_day := 0
var chapter_two_day := 0
var presented: Array[int] = []
var seen: Array[String] = []
var active := ""
var legacy_partial := false

func total() -> int:
 return archived_visits+visits.size()

func record_departure(day: int, id: int) -> void:
 if day <= through_day or id < 1 or id > 4: return
 var key := "%d:%d" % [day,id]
 if not key in visits: visits.append(key)

func close_day(day: int) -> void:
 # Called only by the existing all_done() guarded next-day command. A closed
 # day is a compact receipt for its four distinct day:patient visits.
 if day <= through_day: return
 archived_visits += visits.size()
 visits.clear()
 through_day = day

static func simultaneous(sim: HospitalSimulation) -> bool:
 if not sim.expanded or sim.treatment_owners.size() != 2: return false
 if sim.treatment_owners[0] == sim.treatment_owners[1]: return false
 for room in range(2):
  var p := sim.get_patient(sim.treatment_owners[room])
  if p.is_empty() or p.state != "treatment" or p.room != room or p.paid: return false
 return true

func observe(sim: HospitalSimulation) -> void:
 if simultaneous(sim): dual_experienced = true
 if chapter_one_day == 0 and sim.all_done(): chapter_one_day = sim.day
 if chapter_two_day == 0 and chapter_one_day > 0 and sim.expanded and dual_experienced and total() >= TARGET:
  chapter_two_day = sim.day

func goal(sim: HospitalSimulation) -> String:
 if chapter_one_day == 0: return "1장 · 오늘 방문 일정 %d/4  >" % sim.count_state("complete")
 if chapter_two_day > 0:
  if sim.operations.chapter_three_day > 0:
   if sim.research.chapter_four_day > 0: return "1~4장 완료 ✓ · 성장 기록  >"
   if sim.research.built_day == 0: return "4장 · 기록을 살필 연구소 마련하기  >"
   if sim.research.slot() != "": return "4장 · 연구 완료와 다음 날 적용 기다리기  >"
   return "4장 · 첫 연구 선택하기  >"
  if not sim.operations.trained: return "3장 · 함께 일하는 운영 교육  >"
  return "3장 · 위임 방문 일정 %d/4 완료  >" % mini(sim.operations.total(),4)
 if not sim.expanded: return "2장 · 치료별관 마련하기  >"
 if not dual_experienced: return "2장 · 두 치료실 함께 운영하기  >"
 return "2장 · 방문 일정 %d/12 완료  >" % mini(total(),TARGET)

func finish_scene() -> void:
 if active != "" and not active in seen: seen.append(active)
 active = ""

func guidance_changed(enabled: bool, sim: HospitalSimulation) -> void:
 finish_scene()
 if enabled:
  # Re-enable at the current task; never replay a historical speech queue.
  if sim.day >= 2:
   for id in ["annex_absent","annex_ready"]:
    if not id in seen: seen.append(id)
  if dual_experienced and not "dual" in seen: seen.append("dual")

func sync_story(sim: HospitalSimulation, enabled: bool, allow_new: bool) -> void:
 if not enabled: finish_scene(); return
 if active != "" or not allow_new or sim.day < 2 or chapter_two_day > 0: return
 if not "annex_absent" in seen and not "annex_ready" in seen:
  if sim.expanded: active = "annex_ready"
  elif sim.count_state("treatment_queue") > 0: active = "annex_absent"
 if active == "" and dual_experienced and not "dual" in seen: active = "dual"

func speech() -> String:
 match active:
  "annex_absent": return "치료를 기다리고 계세요.\n옆 공간에 치료실을\n더 마련할 수 있어요."
  "annex_ready": return "치료실이 더 생겼네요.\n두 공간을 함께\n운영해 볼까요?"
  "dual": return "두 분의 일정을\n각자의 치료실에서\n함께 진행했네요."
 return ""

func snapshot() -> Dictionary:
 return {"version":1,"archived_visits":archived_visits,"through_day":through_day,"visits":visits.duplicate(),"dual_experienced":dual_experienced,"chapter_one_day":chapter_one_day,"chapter_two_day":chapter_two_day,"presented":presented.duplicate(),"seen":seen.duplicate(),"active":active,"legacy_partial":legacy_partial}

static func from_save(data: Variant, day: int, lifetime_paid: int, patients: Array[Dictionary], expanded: bool) -> HospitalChapterProgress:
 var result := HospitalChapterProgress.new()
 var complete_keys: Array[String] = []
 var paid_today := 0
 for p in patients:
  if p.paid: paid_today += 1
  if p.state == "complete": complete_keys.append("%d:%d" % [day,p.id])
 complete_keys.sort()
 if data == null:
  # Normal legacy code can advance a day only after all four have departed.
  # A contradictory legacy counter is retained, but its past visits are not invented.
  result.through_day = day-1
  result.legacy_partial = lifetime_paid != (day-1)*4+paid_today
  result.archived_visits = 0 if result.legacy_partial else (day-1)*4
  result.visits = complete_keys
  if day > 1 or complete_keys.size() == 4: result.chapter_one_day = 1
  result.seen.assign(SCENES) # Existing players never receive old scene backlogs.
  if result.chapter_one_day > 0: result.presented.append(1)
  # Do not infer simultaneous treatment from old max_treating, money or expansion.
  return result
 if not data is Dictionary or data.get("version") != 1: return null
 if not HospitalSimulation.whole(data.get("through_day"),day-1,day-1): return null
 if not HospitalSimulation.whole(data.get("archived_visits"),0,(day-1)*4): return null
 if not data.get("legacy_partial") is bool or not data.get("dual_experienced") is bool: return null
 if not data.legacy_partial and data.archived_visits != (day-1)*4: return null
 if int(data.archived_visits) % 4 != 0: return null
 if not data.get("visits") is Array or data.visits.size() > 4: return null
 var keys: Array[String] = []
 for key in data.visits:
  if not key is String or key in keys: return null
  keys.append(key)
 keys.sort()
 if keys != complete_keys: return null
 for field in ["chapter_one_day","chapter_two_day"]:
  if not HospitalSimulation.whole(data.get(field),0,day): return null
 if data.chapter_one_day == 0 and (day > 1 or keys.size() == 4): return null
 if data.chapter_one_day > 0 and day == 1 and keys.size() != 4: return null
 if data.chapter_two_day > 0 and (data.chapter_one_day == 0 or not expanded or not data.dual_experienced or data.archived_visits+keys.size() < TARGET): return null
 var qualified: bool = data.chapter_one_day > 0 and expanded and data.dual_experienced and data.archived_visits+keys.size() >= TARGET
 if (data.chapter_two_day > 0) != qualified: return null
 if data.chapter_two_day > 0 and data.chapter_two_day < data.chapter_one_day: return null
 if data.dual_experienced and not expanded: return null
 if not data.get("active") is String or (data.active != "" and not data.active in SCENES): return null
 for field in ["seen","presented"]:
  if not data.get(field) is Array: return null
 if data.seen.size() > SCENES.size() or data.presented.size() > 2: return null
 for id in data.seen:
  if not id in SCENES or id in result.seen: return null
  result.seen.append(id)
 for id in data.presented:
  if not HospitalSimulation.whole(id,1,2) or int(id) in result.presented: return null
  if (id == 1 and data.chapter_one_day == 0) or (id == 2 and data.chapter_two_day == 0): return null
  result.presented.append(int(id))
 if data.active != "" and data.active in result.seen: return null
 result.archived_visits = int(data.archived_visits); result.through_day = int(data.through_day)
 result.visits.assign(data.visits)
 result.dual_experienced = data.dual_experienced
 result.chapter_one_day = int(data.chapter_one_day); result.chapter_two_day = int(data.chapter_two_day)
 result.active = data.active; result.legacy_partial = data.legacy_partial
 return result
