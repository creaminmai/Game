extends SceneTree
func _initialize() -> void:
 var path := ""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--checkpoint="): path = arg.trim_prefix("--checkpoint=")
 var store := HospitalSaveStore.new(); store.path = path
 var sim := HospitalSimulation.new()
 var valid := store.load_into(sim)
 assert(valid and sim.paused and sim.schedule.today_count == 6)
 var data := sim.snapshot(); sim.tick(10); assert(sim.snapshot() == data)
 preload("res://tests/daily_capacity_fixture.gd").finish(sim)
 assert(sim.all_done() and sim.ledger.income == 1200 and sim.schedule.closed_counts.back() == 6)
 print("RESTART PASS ",path.get_file()," six departed; one 1200 income receipt")
 quit()
