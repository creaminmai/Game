extends SceneTree
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label); printerr("FAIL: ",label)

func operate(sim: HospitalSimulation, expand: bool, until_purchase: bool = false) -> void:
 sim.paused = false
 for n in range(5000):
  for p in sim.patients:
   if p.state == "waiting": sim.admit(p.id)
   elif p.state == "plan_ready": sim.assign_plan(p.id)
  if expand and sim.expansion_reason().is_empty():
   sim.purchase_expansion()
   if until_purchase: return
  sim.tick(.1)
  if sim.all_done(): return

func roundtrip(sim: HospitalSimulation, story: FirstDayStory) -> HospitalSimulation:
 var store := HospitalSaveStore.new()
 store.path = "user://polish-save.json"
 check(store.save(sim,story),"save through the actual atomic save store")
 var restored := HospitalSimulation.new()
 var guidance := FirstDayStory.new()
 check(store.load_into(restored,guidance),"restore actual save store")
 check(JSON.stringify(restored.snapshot()) == JSON.stringify(sim.snapshot()),"all operational records round-trip exactly")
 check(guidance.snapshot() == story.snapshot(),"guide setting and current line round-trip exactly")
 DirAccess.remove_absolute(store.path)
 return restored

func run() -> void:
 var story := FirstDayStory.new()
 for expand in [false,true]:
  var sim := HospitalSimulation.new()
  check(sim.ledger.opening_money == 900 and sim.ledger.income == 0 and sim.ledger.expansion_expense == 0,"new game records actual opening funds")
  if expand:
   operate(sim,true,true)
   check(sim.expanded and sim.money == 500 and sim.ledger.expansion_expense == 600,"actual purchase records one 600 expense")
   sim = roundtrip(sim,story)
   var before := sim.snapshot()
   check(not sim.purchase_expansion() and before == sim.snapshot(),"purchase after reload cannot duplicate facility or expense")
  operate(sim,expand)
  check(sim.all_done() and sim.completed() == 4,"journal eligibility requires all four actual departures")
  check(sim.ledger.income == 800 and sim.ledger.expansion_expense == (600 if expand else 0),"income and expansion spending are distinct exact receipts")
  check(sim.money == (1100 if expand else 1700),"actual final funds match expansion decision")
  check(sim.ledger.new_annex == expand,"only a facility bought today is called new")
  if expand: check(sim.max_treating == 2,"both treatment rooms still operate concurrently")
  sim = roundtrip(sim,story)
  var money := sim.money
  sim.paused = false; sim.tick(90)
  check(sim.money == money and sim.ledger.income == 800,"reloading the completed day cannot pay again")
  check(sim.start_next_day() and not sim.start_next_day() and sim.day == 2,"double next-day request advances exactly one day")
  check(sim.ledger.opening_money == money and sim.ledger.income == 0 and sim.ledger.expansion_expense == 0 and not sim.ledger.new_annex,"next day resets receipts and preserves actual funds")
  check(sim.money == money and sim.expanded == expand,"next day retains funds and facilities")
  operate(sim,false)
  check(sim.ledger.income == 800 and sim.ledger.expansion_expense == 0 and sim.money == money+800,"second-day receipt collection restarts correctly")
  var legacy := sim.snapshot()
  legacy.erase("daily_ledger")
  var old := HospitalSimulation.new()
  check(old.restore(legacy),"existing v2 saves without ledger still load")
  check(old.ledger.opening_money == -1 and old.ledger.expansion_expense == -1 and old.ledger.income == 800,"legacy expense and opening balance stay explicitly unknown")
  roundtrip(old,story)
  var invalid := sim.snapshot()
  invalid.daily_ledger.expansion_expense = 123
  var untouched := HospitalSimulation.new()
  var snapshot := untouched.snapshot()
  check(not untouched.restore(invalid) and untouched.snapshot() == snapshot,"invalid ledger is rejected without partially restoring any game state")
 var sim := HospitalSimulation.new()
 story.sync(sim,-1)
 check(story.lines(sim).size() == 1,"welcome is one short spoken line")
 sim.tick(15); story.sync(sim,-1)
 check(story.active == "welcome" and story.line == 0,"reading time has no deadline")
 story.finish_dialogue(); story.sync(sim,-1)
 check(story.active == "arrival" and story.lines(sim).size() == 1,"arrival keeps Kim's nervous personality in one line")
 story.acknowledge_action("select"); story.sync(sim,1)
 check(story.active == "" and sim.get_patient(1).state == "waiting","selection immediately enables admission guidance without admitting")
 sim.admit(1); story.sync(sim,1)
 story.disable()
 var off := roundtrip(sim,story)
 var restored_story := FirstDayStory.new(); restored_story.restore(story.snapshot())
 check(not restored_story.enabled,"disabled guidance survives save/load")
 off.paused = false; off.tick(30)
 restored_story.enable_current(off,1)
 check(restored_story.enabled and restored_story.active == "" and restored_story.hint(off,1,false).contains("계획"),"re-enabled guidance starts at the current plan action, without old dialogue backlog")
 roundtrip(off,restored_story)
 var game = load("res://main.tscn").instantiate()
 root.add_child(game); game.set_process(false)
 await process_frame
 game.story.disable()
 operate(game.sim,true,true)
 game.refresh()
 check(game.world.wing_built and game.world.celebration_count == 0,"restored/synced facility appears complete without replaying purchase effects")
 game.world.celebrate_expansion()
 var funds: int = game.sim.money
 game.world.update_expansion_feedback(.4)
 var saved: Dictionary = game.sim.snapshot()
 var fresh = load("res://main.tscn").instantiate()
 root.add_child(fresh); fresh.set_process(false)
 check(fresh.sim.restore(saved),"save during completion animation restores")
 fresh.refresh()
 check(fresh.world.wing_built and fresh.world.exterior_annex.visible and fresh.world.celebration_elapsed < 0,"load during animation is immediately a complete usable facility")
 var fitted: Dictionary = fresh.world.fitted_view(fresh.world.operating_bounds(),fresh.world.operating_area)
 check(absf(fresh.world.camera.size-fitted.size) < .001 and fresh.world.view_center.distance_to(fitted.center) < .001,"restored expanded hospital starts at the correct fitted operating view")
 check(fresh.sim.money == funds and fresh.sim.ledger.expansion_expense == 600,"cosmetic playback has no economic authority")
 game.world.update_expansion_feedback(5)
 check(not game.world.expansion_sparkles.visible and game.world.exterior_annex.visible,"completion effect ends with the building visible")
 game.world.show_outside(true); game.world.show_outside(false)
 check(game.world.wing_built and game.sim.snapshot() == saved,"view changes never mutate facility receipts or patient state")
 game.free(); fresh.free()
 var output := ProjectSettings.globalize_path("res://../artifacts/first-day-polish-unit")
 DirAccess.make_dir_recursive_absolute(output)
 var result := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"mobile_hardware_test":false}
 FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("FIRST DAY POLISH: ",JSON.stringify(result))
 quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
 run.call_deferred()
