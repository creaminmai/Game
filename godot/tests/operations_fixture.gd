extends RefCounted
const Chapter = preload("res://tests/chapter_fixture.gd")
static func prepare(admission: bool = true, planning: bool = true) -> HospitalSimulation:
 var sim: HospitalSimulation = Chapter.prepare(4)
 assert(sim.chapters.chapter_two_day == 3 and sim.money == 2700)
 assert(sim.purchase_training())
 sim.set_admission_delegated(admission)
 sim.set_plan_delegated(planning)
 return sim
static func step(sim: HospitalSimulation, assist: bool = true, delta: float = .1) -> void:
 if assist:
  for p in sim.patients:
   if p.state == "waiting" and not sim.admission.enabled: sim.admit(p.id)
   if p.state == "plan_ready" and not sim.operations.enabled: sim.assign_plan(p.id)
 sim.tick(delta)
static func finish(sim: HospitalSimulation) -> void:
 sim.paused = false
 for i in range(10000):
  step(sim)
  if sim.all_done(): return
 assert(false,"operations fixture timed out")
