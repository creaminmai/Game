class_name PatientFeedback
extends RefCounted
# Presentation only: ownership, FIFO and action rules stay in the simulation.
static func describe(sim: HospitalSimulation, p: Dictionary) -> Dictionary:
 var result := {"action":"", "reason":"", "bubble":"", "heading":sim.status_text(p.id)}
 match p.state:
  "entering":
   result.action = "대기실로 이동 중"
   result.reason = "자리에 앉으면 접수할 수 있어요."
  "waiting":
   result.action = "접수하기"
   result.reason = "아래 버튼으로 접수해 주세요.\nCT 순서에 등록돼요."
   result.bubble = "접수해 주세요"
  "plan_ready":
   result.action = "계획 맡기기"
   result.reason = "CT 촬영을 마쳤어요.\n직원에게 검토를 맡겨 주세요."
   result.bubble = "계획 부탁해요"
  "ct_queue", "plan_queue", "treatment_queue":
   var destination := {"ct_queue":"CT", "plan_queue":"계획", "treatment_queue":"치료실"}[p.state] as String
   var rank := sim.queue_rank(p.id)
   result.heading = destination+" 대기"
   result.action = "%s 대기 · %d번째" % [destination,rank]
   var use_text := "앞 환자가 이용 중이에요."
   var owner := sim.ct_owner if p.state == "ct_queue" else sim.planner_owner
   if p.state == "treatment_queue":
    use_text = "치료실이 예약·사용 중이에요."
   else:
    var occupant := sim.get_patient(owner)
    if not occupant.is_empty() and occupant.state == "walk_ct": use_text = "앞 환자가 CT로 이동 중이에요."
   result.reason = use_text+"\n대기 %d번째 · 앞에 %d명\n추가 지시 없이 자동 진행해요." % [rank,rank-1]
  "walk_ct", "walk_plan", "walk_treatment":
   result.action = sim.status_text(p.id)
   result.reason = "도착하면 자동으로 CT 촬영을 시작해요."
   if p.state == "walk_plan": result.reason = "계획실에 도착하면 검토를 맡겨 주세요."
   elif p.state == "walk_treatment": result.reason = "%d번 치료실을 예약했어요. 도착하면 자동으로 치료해요." % (p.room+1)
  "ct_scan", "planning", "treatment":
   result.action = sim.status_text(p.id)
   result.reason = "%d초 후 마쳐요. " % maxi(0,ceili(sim.DURATIONS[p.state]-p.elapsed))
   result.reason += "끝나면 계획실로 이동해요." if p.state == "ct_scan" else ("끝나면 치료 순서에 등록돼요." if p.state == "planning" else "끝나면 자동으로 귀가해요.")
  "leaving", "complete":
   result.action = sim.status_text(p.id)
   result.reason = "오늘 진료를 마쳤어요. 추가 지시는 없어요."
 return result
