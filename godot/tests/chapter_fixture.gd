extends RefCounted

static func step(sim: HospitalSimulation, expansion_day: int = 1, serial_plans: bool = false, delta: float = .1) -> void:
 for p in sim.patients:
  if p.state == "waiting" and not sim.admission.enabled: sim.admit(p.id)
  if p.state == "plan_ready":
   if not serial_plans or (sim.planner_owner == -1 and sim.count_state("walk_treatment")+sim.count_state("treatment")+sim.count_state("planning") == 0): sim.assign_plan(p.id)
 if sim.day >= expansion_day and sim.expansion_reason().is_empty(): sim.purchase_expansion()
 sim.tick(delta)

static func finish_day(sim: HospitalSimulation, expansion_day: int = 1, serial_plans: bool = false) -> void:
 sim.paused = false
 for n in range(10000):
  step(sim,expansion_day,serial_plans)
  if sim.all_done(): return
 assert(false,"chapter fixture day timed out")

static func prepare(day: int, expansion_day: int = 1, delegate: bool = false) -> HospitalSimulation:
 var sim := HospitalSimulation.new()
 while sim.day < day:
  finish_day(sim,expansion_day)
  assert(sim.start_next_day())
  if delegate: sim.set_admission_delegated(true)
 return sim
