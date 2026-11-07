extends SceneTree
const Fixture = preload("res://tests/staff_fixture.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label); printerr("FAIL: ",label)
func run() -> void:
 var first := HospitalSimulation.new()
 check(not first.set_admission_delegated(true),"day one cannot enable delegation")
 first.tick(60)
 check(first.count_state("waiting") == 4 and first.serial == 0,"day one stays manual")
 for expand in [false,true]:
  var sim: HospitalSimulation = Fixture.day_two(expand)
  check(not sim.admission.enabled and not sim.admission.offer_seen,"day two starts off without consent")
  sim.tick(25)
  sim.set_admission_delegated(true)
  var successes: Array[int] = []
  sim.admitted.connect(func(id: int): successes.append(id))
  sim.tick(2.9)
  check(sim.serial == 0,"no immediate or per-frame admission")
  sim.tick(.1)
  check(successes == [1] and sim.ct_owner == 1,"oldest actual waiting patient reserves CT normally")
  check(not sim.admit(1),"auto then manual same instant is idempotent")
  sim.tick(2.9)
  check(sim.admit(2),"manual can win immediately before automatic deadline")
  sim.tick(.1)
  check(successes == [1,2] and sim.queue_rank(2) == 1,"manual and auto never duplicate queue entry")
  sim.tick(6)
  check(successes == [1,2,3,4],"arrival order stays stable behind busy CT")
  sim.tick(60)
  check(sim.count_state("plan_ready") == 4 and sim.planner_owner == -1 and sim.completed() == 0,"plans and income never advance automatically")
  check(sim.next_action_patient(-1) == 1,"attention directs player to plan review")
  var funds := sim.money
  Fixture.finish_day(sim)
  check(sim.money == funds+800 and sim.ledger.income == 800 and sim.ledger.expansion_expense == 0,"delegated day preserves actual receipts without new spending")
  if expand: check(sim.max_treating == 2,"two treatment rooms remain concurrent")
  check(sim.start_next_day() and sim.admission.enabled and sim.admission.offer_seen,"choice persists into day three")
  sim.tick(1)
  check(sim.serial == 0,"entering patients cannot be admitted early")
 var sim: HospitalSimulation = Fixture.day_two()
 sim.tick(25); sim.set_admission_delegated(true); sim.tick(2)
 var store := HospitalSaveStore.new(); store.path = "user://staff-unit.json"
 var story := FirstDayStory.new(); story.disable()
 check(store.save(sim,story),"save partially elapsed duty through atomic store")
 var restored := HospitalSimulation.new(); var restored_story := FirstDayStory.new()
 check(store.load_into(restored,restored_story),"restore delegated state and pending clock")
 check(restored.admission.snapshot() == sim.admission.snapshot() and not restored_story.enabled,"guidance and delegation save independently")
 var before := restored.snapshot(); restored.tick(100)
 check(restored.snapshot() == before and restored.paused,"restored pause prevents all automatic work")
 restored.paused = false; restored.tick(1)
 check(restored.ct_owner == 1 and restored.serial == 1,"resumed clock admits exactly once")
 for n in range(4):
  sim.set_admission_delegated(false); sim.tick(5)
  check(sim.serial == 0,"disabled duty cancels previous deadline")
  sim.set_admission_delegated(true); sim.tick(2.9)
  check(sim.serial == 0,"re-enable requires fresh preparation time")
 var legacy := sim.snapshot(); legacy.erase("staff_admission")
 check(restored.restore(legacy) and not restored.admission.enabled and not restored.admission.offer_seen,"old day two save defaults to off")
 for invalid in [{"version":99},{"version":1,"enabled":true,"offer_seen":false,"candidate_id":-1,"elapsed":0},{"version":1,"enabled":false,"offer_seen":true,"candidate_id":1,"elapsed":2}]:
  var bad := sim.snapshot(); bad.staff_admission = invalid
  before = restored.snapshot()
  check(not restored.restore(bad) and restored.snapshot() == before,"invalid new metadata cannot partially overwrite state")
 var game = load("res://main.tscn").instantiate(); root.add_child(game); game.set_process(false)
 await process_frame
 game.sim.restore(Fixture.day_two().snapshot()); game.sim.paused = false; game.user_paused = false
 game.story.enabled = true; game.refresh()
 check(game.admission_offer.visible and not game.sim.admission.enabled,"one day-two offer does not imply consent")
 game.answer_admission_offer(false); game.refresh()
 check(not game.admission_offer.visible and not game.sim.admission.enabled,"decline remains manual and closes offer")
 game.toggle_admission()
 check(game.sim.admission.enabled,"declined offer can be enabled in settings")
 game.toggle_guidance()
 check(game.sim.admission.enabled and not game.story.enabled,"turning guidance off does not revoke duty")
 game.sim.tick(6)
 for hold in ["outside","application_focus","application_background","web_hidden"]:
  game.set_pause_hold(hold,true); before = game.sim.snapshot(); game.sim.tick(100)
  check(game.sim.snapshot() == before,"no automatic work during "+hold)
  game.set_pause_hold(hold,false)
  check(not game.sim.paused,"temporary hold restores playing intent")
 game.toggle_pause(); game.set_pause_hold("application_background",true); game.set_pause_hold("application_background",false)
 check(game.sim.paused,"background resume preserves explicit user pause")
 game.sim.restore(Fixture.day_two().snapshot()); game.sim.paused = false; game.user_paused = false
 game.refresh()
 check(not game.admission_offer.visible and not game.sim.admission.enabled,"guidance off does not force old-save proposal")
 game.story.enabled = true; game.refresh(); game.admission_skip.pressed.emit(); game.refresh()
 check(not game.admission_offer.visible and not game.sim.admission.enabled and game.sim.admission.offer_seen,"skip uses refusal, never consent")
 game.sim.admission.offer_seen = false; game.refresh(); game.admission_accept.pressed.emit()
 check(game.sim.admission.enabled and not game.admission_offer.visible,"explicit acceptance enables only admission")
 game.sim.tick(25); game.selected_id = 3
 var camera: Vector3 = game.world.view_center; var zoom: float = game.world.camera.size
 game.sim.tick(15); game.refresh()
 check(game.selected_id == 3 and game.world.view_center == camera and game.world.camera.size == zoom,"automatic work does not select or move camera")
 DirAccess.remove_absolute(store.path)
 var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"physical_mobile":false}
 DirAccess.make_dir_recursive_absolute("res://../artifacts/staff-unit")
 FileAccess.open("res://../artifacts/staff-unit/results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("STAFF ADMISSION: ",checks," checks, ",failures.size()," failures")
 game.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
