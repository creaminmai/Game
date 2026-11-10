extends SceneTree
const Chapter = preload("res://tests/chapter_fixture.gd")
const Fixture = preload("res://tests/daily_capacity_fixture.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label); printerr("FAIL: ",label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
 # Real chapter-three boundary inside a six-person day, not on its last visit.
 var sim: HospitalSimulation = Chapter.prepare(3)
 Chapter.finish_day(sim)
 check(sim.chapters.chapter_two_day == 3 and sim.purchase_training(),"actual chapter-two close unlocks training")
 check(sim.start_next_day(6),"six-person fourth day starts")
 sim.set_admission_delegated(true); sim.set_plan_delegated(true)
 for n in range(10000):
  Fixture.step(sim)
  if sim.count_state("complete") == 4: break
 check(sim.operations.total() == 4 and sim.operations.chapter_three_day == 4,"four delegated departures complete chapter three")
 check(not sim.all_done() and not sim.start_next_day(4) and sim.schedule.closed_through() == 3 and sim.research.closed_through == 3,"chapter goal does not close six-person day or produce research")
 # The exact game pause holds, not an alternative testing implementation.
 var game: Control = load("res://main.tscn").instantiate()
 root.add_child(game); await process_frame; game.set_process(false)
 game.story.disable()
 check(game.sim.restore(sim.snapshot()),"unfinished sixth-day roster restores in actual game")
 game.pause_holds.clear(); game.toggle_pause()
 game.refresh()
 for kind in ["app_focus","web_hidden"]:
  game.set_pause_hold(kind,true)
  var before: Dictionary = game.sim.snapshot(); game.sim.tick(100)
  check(before == game.sim.snapshot(),"six-patient operations freeze for "+kind)
  game.set_pause_hold(kind,false)
  check(not game.sim.paused,"temporary hold releases without changing user choice")
 game.toggle_pause()
 game.set_pause_hold("app_focus",true); game.set_pause_hold("app_focus",false)
 check(game.sim.paused and game.user_paused,"user pause survives app return with six bookings")
 game.toggle_pause()
 game.toggle_outside()
 var before: Dictionary = game.sim.snapshot(); game.sim.tick(100)
 check(game.sim.snapshot() == before,"outside holds both automatic duties")
 game.toggle_outside()
 check(not game.sim.paused,"interior resumes only temporary hold")
 Fixture.finish(game.sim)
 check(game.sim.ledger.income == 1200 and game.sim.operations.total() == 6 and game.sim.money == 3400,"six-person actual educational path closes with exact receipts")
 game.free()
 var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"platform":"Linux actual main scene headless; simulated lifecycle notifications; no phone hardware"}
 FileAccess.open("res://../artifacts/capacity-edges-results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("CAPACITY EDGES: ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
