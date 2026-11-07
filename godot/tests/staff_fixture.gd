extends RefCounted

static func finish_day(sim: HospitalSimulation, expand: bool = false) -> void:
 sim.paused = false
 for n in range(6000):
  for p in sim.patients:
   if p.state == "waiting": sim.admit(p.id)
   elif p.state == "plan_ready": sim.assign_plan(p.id)
  if expand and sim.expansion_reason().is_empty(): sim.purchase_expansion()
  sim.tick(.1)
  if sim.all_done(): return
 assert(false,"normal day fixture timed out")

static func day_two(expand: bool = false) -> HospitalSimulation:
 var sim := HospitalSimulation.new()
 finish_day(sim,expand)
 assert(sim.start_next_day())
 return sim
