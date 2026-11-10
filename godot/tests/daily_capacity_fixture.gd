extends RefCounted
const Chapter = preload("res://tests/chapter_fixture.gd")
const Operations = preload("res://tests/operations_fixture.gd")
static func first_journal() -> HospitalSimulation:
 var sim := HospitalSimulation.new()
 Chapter.finish_day(sim)
 assert(sim.day == 1 and sim.money == 1100 and sim.chapters.total() == 4)
 return sim
static func six_day() -> HospitalSimulation:
 var sim := first_journal()
 assert(sim.start_next_day(6))
 return sim
static func step(sim: HospitalSimulation, delta: float = .1) -> void: Operations.step(sim,true,delta)
static func finish(sim: HospitalSimulation) -> void: Operations.finish(sim)
