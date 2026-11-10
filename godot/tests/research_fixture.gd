extends RefCounted
const Operations = preload("res://tests/operations_fixture.gd")
static func prepare(day: int = 5) -> HospitalSimulation:
 var sim: HospitalSimulation = Operations.prepare()
 Operations.finish(sim)
 assert(sim.money == 3000 and sim.operations.chapter_three_day == 4)
 while sim.day < day:
  assert(sim.start_next_day())
  if sim.day < day: Operations.finish(sim)
 return sim
static func finish(sim: HospitalSimulation) -> void: Operations.finish(sim)
static func step(sim: HospitalSimulation, delta: float = .1) -> void: Operations.step(sim,true,delta)
