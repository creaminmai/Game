extends SceneTree
# Fast fixture creation, not a replay or gameplay video. No forced patient state,
# balance or command provenance: every transition uses normal simulation rules.
const Fixture = preload("res://tests/operations_fixture.gd")
func write_checkpoint(sim: HospitalSimulation, name_text: String) -> void:
 var story := FirstDayStory.new()
 story.enable_current(sim,-1); story.disable()
 var saved := sim.snapshot(); saved.first_day_story = story.snapshot()
 var folder := "res://../artifacts/operations-web-checkpoints"
 DirAccess.make_dir_recursive_absolute(folder)
 FileAccess.open(folder.path_join(name_text+".json"),FileAccess.WRITE).store_string(JSON.stringify(saved,"  "))
func _initialize() -> void:
 var education: HospitalSimulation = Fixture.Chapter.prepare(4)
 education.set_admission_delegated(false)
 education.tick(24)
 assert(education.count_state("waiting") == 4 and education.money == 2700)
 write_checkpoint(education,"education")
 var planning: HospitalSimulation = Fixture.prepare()
 for n in range(10000):
  planning.tick(.1)
  if planning.operations.candidate_id == 1 and planning.operations.elapsed >= 2.5: break
 assert(planning.get_patient(1).state == "plan_ready" and planning.get_patient(1).admission_source == "minji" and planning.get_patient(1).plan_source == "none")
 write_checkpoint(planning,"planning")
 print("WEB CHECKPOINTS: normal day-four waiting and actual delegated planning preparation")
 quit()
