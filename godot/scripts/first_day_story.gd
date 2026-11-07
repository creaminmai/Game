class_name FirstDayStory
extends RefCounted
# Presentation state only. This class never admits, pays, purchases or ticks.
const IDS := ["welcome","arrival","admission","ct","plan","treatment","complete","expansion","day_end"]
const STAGES := ["select","admit","ct","plan","treatment","complete","day_end","finished","disabled"]
var enabled := true
var seen: Dictionary = {}
var active := ""
var line := 0
var stage := "select"
var selected_first := false

func snapshot() -> Dictionary:
 return {"version":1,"enabled":enabled,"seen":seen.duplicate(),"active":active,"line":line,"stage":stage,"selected_first":selected_first}

static func valid(data: Variant) -> bool:
 if not data is Dictionary or data.get("version") != 1: return false
 if not data.get("enabled") is bool or not data.get("selected_first") is bool: return false
 if not data.get("seen") is Dictionary or not data.get("active") is String: return false
 if data.active != "" and not data.active in IDS: return false
 if not data.get("stage") in STAGES: return false
 var n: Variant = data.get("line")
 if not (n is int or n is float) or not is_finite(float(n)) or n != floor(float(n)) or n < 0 or n > 2: return false
 if not data.active in ["welcome","expansion"] and n > 1: return false
 if data.active == "" and n != 0: return false
 for id in data.seen:
  if not id in IDS or not data.seen[id] is bool: return false
 return true

func restore(data: Variant) -> void:
 # Legacy v2 saves have already begun their day. Never replay a new tutorial.
 if data == null:
  disable()
  return
 enabled = data.enabled
 seen = data.seen.duplicate()
 active = data.active
 line = int(data.line)
 stage = data.stage
 selected_first = data.selected_first

func disable() -> void:
 enabled = false
 active = ""
 line = 0
 stage = "disabled"

func enable_current(sim: RefCounted, selected: int) -> void:
 # Re-enabling is a fresh look at the current action, never a dialogue backlog.
 enabled = true
 active = ""
 line = 0
 selected_first = selected == 1 or sim.get_patient(1).state not in ["entering","waiting"]
 for id in IDS: seen[id] = true
 var first: Dictionary = sim.get_patient(1)
 if sim.day == 1 and not sim.all_done():
  if not first.paid: seen.erase("complete")
  if not sim.expanded and sim.expansion_reason() != "": seen.erase("expansion")
  seen.erase("day_end")
 sync(sim,selected,false)

func acknowledge_action(action: String) -> void:
 # Only explicit player actions can dismiss now-obsolete action instructions.
 var obsolete: Array = ["welcome","arrival","admission"] if action == "select" else ["welcome","arrival","admission","ct","plan"]
 if active in obsolete: finish_dialogue()

func finish_dialogue() -> void:
 if active != "": seen[active] = true
 active = ""
 line = 0

func next_line(sim: RefCounted) -> void:
 if active == "": return
 line += 1
 if line >= lines(sim).size(): finish_dialogue()

func applicable(id: String, sim: RefCounted, selected: int) -> bool:
 var p: Dictionary = sim.get_patient(1)
 if sim.day != 1 or p.is_empty(): return false
 match id:
  "welcome": return p.state in ["entering","waiting"] and not selected_first
  "arrival": return p.state == "waiting" and not selected_first
  "admission": return false # Legacy scene ID is kept for save compatibility; guidance lives by the button.
  "ct": return p.state in ["ct_queue","walk_ct","ct_scan"]
  "plan": return p.state == "plan_ready"
  "treatment": return p.state == "treatment"
  "complete": return p.paid and not sim.all_done()
  "expansion": return sim.expansion_reason().is_empty() and not sim.all_done()
  "day_end": return sim.all_done()
 return false

func sync(sim: RefCounted, selected: int, allow_new: bool = true) -> void:
 if not enabled: return
 if sim.day != 1:
  finish_dialogue()
  stage = "finished"
  return
 var p: Dictionary = sim.get_patient(1)
 if p.is_empty(): return
 if selected == 1: selected_first = true
 var index: int = sim.STATES.find(p.state)
 stage = "select" if not selected_first else "admit"
 if index >= sim.STATES.find("ct_queue"): stage = "ct"
 if index >= sim.STATES.find("plan_ready"): stage = "plan"
 if index >= sim.STATES.find("planning"): stage = "treatment"
 if p.paid: stage = "complete"
 if sim.all_done(): stage = "day_end"
 # Retire missed instructions, but never expire a line the player is reading.
 if selected_first: seen.welcome = true; seen.arrival = true
 if index >= sim.STATES.find("ct_queue"): seen.welcome = true; seen.arrival = true; seen.admission = true
 if index >= sim.STATES.find("walk_plan"): seen.ct = true
 if index >= sim.STATES.find("plan_queue"): seen.plan = true
 if p.paid: seen.treatment = true
 if sim.expanded: seen.expansion = true
 if sim.all_done():
  for id in IDS:
   if id != "day_end": seen[id] = true
 if active == "admission": finish_dialogue() # Migrate the removed instruction without replay.
 # An active spoken line survives passive state changes, focus loss and new hints.
 if active != "" or not allow_new: return
 for id in IDS:
  if not seen.get(id,false) and applicable(id,sim,selected):
   active = id
   line = 0
   return

func lines(sim: RefCounted) -> Array:
 match active:
  "welcome": return [["민지","오셨어요! 햇살병원을 함께 돌봐요. 먼저 첫 환자분을 맞이할까요?"]]
  "arrival": return [["김영수","간판은 잘 찾았는데… 처음이라 조금 떨리네요. 저, 접수 부탁해요."]]
  "ct": return [["민지","CT는 차례대로 자동 진행돼요. 다른 환자분도 살펴볼까요?"]]
  "plan": return [["민지","촬영을 마쳤어요. 의료진에게 치료 계획 검토를 맡겨 주세요."]]
  "treatment": return [["민지","치료를 시작했어요. 준비와 마무리는 환자 카드에서 확인해요."]]
  "complete": return [["김영수","처음이라 긴장했는데, 차근차근 알려줘서 고맙네요."],["민지","오늘 일정은 모두 마치셨어요. 조심히 들어가세요."]]
  "expansion": return [["민지","치료실이 하나 더 있으면 두 분을 함께 도울 수 있겠어요."],["민지","병원 밖 예정지를 살펴볼까요? 오늘은 미뤄도 괜찮아요."]]
  "day_end": return [["민지","첫날이 끝났네요. 오늘 오신 분들 얼굴이 벌써 기억나요."],["민지","내일도 편하게 찾아오실 수 있도록, 조금씩 가꿔봐요."]]
 return []

func hint(sim: RefCounted, selected: int, outside: bool) -> String:
 if not enabled or sim.day != 1 or active != "": return ""
 if outside: return "병원 안에서 진료 계속 · 증축은 선택이에요"
 var p: Dictionary = sim.get_patient(1)
 if p.is_empty(): return ""
 if p.state == "entering": return "자리에 앉으면 접수할 수 있어요" if selected == 1 else "김영수 님이 들어오고 있어요 · 선택해 보세요"
 if p.state == "waiting":
  return "김영수 님 카드에서 접수하기" if selected == 1 else "김영수 님 또는 환자 목록을 눌러 선택해요"
 if p.state in ["ct_queue","walk_ct","ct_scan"]: return "CT는 자동 진행 · 다른 환자도 살펴보세요"
 if p.state == "walk_plan": return "계획실 도착 후 의료진에게 검토를 맡겨요"
 if p.state == "plan_ready":
  return "김영수 님 카드에서 계획 맡기기" if selected == 1 else "김영수 님을 선택해 계획 검토를 맡겨요"
 if p.state in ["plan_queue","planning","treatment_queue","walk_treatment","treatment"]: return "이후 치료는 자동 진행 · 다른 환자도 살펴요"
 if sim.all_done(): return "첫날 일정 완료 · 준비되면 다음 날을 시작해요"
 return "오늘 일정을 마친 김영수 님 · 다른 환자도 돌봐요"

func day_summary(sim: RefCounted) -> String:
 return "오늘 완료 %d명 · 진료 수입 %d만 · 별관 %s" % [sim.completed(),sim.completed()*sim.VISIT_FEE,"운영 중" if sim.expanded else "미증축"]
