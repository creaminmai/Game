extends SceneTree
const Fixture = preload("res://tests/research_fixture.gd")
func write_checkpoint(sim: HospitalSimulation, name_text: String) -> void:
 var story := FirstDayStory.new(); story.enable_current(sim,-1); story.disable()
 var saved := sim.snapshot(); saved.first_day_story = story.snapshot()
 var folder := "res://../artifacts/research-web-checkpoints"
 DirAccess.make_dir_recursive_absolute(folder)
 FileAccess.open(folder.path_join(name_text+".json"),FileAccess.WRITE).store_string(JSON.stringify(saved,"  "))
func _initialize() -> void:
 var sim: HospitalSimulation = Fixture.prepare()
 write_checkpoint(sim,"construction")
 assert(sim.purchase_lab() and sim.start_research("ct"))
 Fixture.finish(sim); sim.start_next_day(); Fixture.finish(sim)
 write_checkpoint(sim,"pending")
 sim.start_next_day()
 for n in range(10000):
  Fixture.step(sim,.1)
  if sim.get_patient(1).state == "ct_scan" and sim.get_patient(1).elapsed >= 1: break
 assert(sim.service_duration(sim.get_patient(1)) == 4)
 write_checkpoint(sim,"active")
 print("RESEARCH WEB CHECKPOINTS: normal construction, pending effect, actual four-second CT")
 quit()
