extends SceneTree
const Fixture = preload("res://tests/operations_fixture.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(value: bool, caption: String) -> void:
 checks += 1
 if not value: failures.append(caption); printerr("FAIL: ",caption)
func roundtrip(sim: HospitalSimulation) -> HospitalSimulation:
 var store := HospitalSaveStore.new(); store.path = "user://operations-unit.json"
 check(store.save(sim),"atomic save")
 var restored := HospitalSimulation.new()
 check(store.load_into(restored),"file restore")
 check(JSON.stringify(sim.snapshot()) == JSON.stringify(restored.snapshot()),"exact duty/source/receipt/chapter restore")
 var before := restored.snapshot(); restored.tick(30)
 check(restored.paused and before == restored.snapshot(),"restore hold freezes duties")
 restored.paused = false
 return restored
func run() -> void:
 var locked := HospitalSimulation.new()
 check(not locked.purchase_training() and locked.money == 900,"education locked before chapter two")
 check(not locked.set_plan_delegated(true),"untrained cannot enable plans")
 var buy: HospitalSimulation = Fixture.Chapter.prepare(4)
 var untouched := buy.snapshot()
 check(buy.training_reason() == "" and buy.snapshot() == untouched,"reading offer does not purchase")
 buy.money = 499
 check(not buy.purchase_training() and buy.money == 499 and buy.ledger.training_expense == 0,"insufficient balance no side effects")
 buy.money = 2700
 check(buy.purchase_training() and buy.money == 2200 and buy.ledger.training_expense == 500,"one actual transaction")
 check(not buy.operations.enabled and not buy.admission.enabled,"education never implies either duty consent")
 for n in range(5): check(not buy.purchase_training() and buy.money == 2200,"repeated purchase charged once")
 buy = roundtrip(buy)
 check(not buy.operations.enabled and buy.operations.trained,"purchase restore before enabling")
 for admission in [false,true]:
  for planning in [false,true]:
   var sim: HospitalSimulation = Fixture.prepare(admission,planning)
   var seen_prepare := false; var seen_plan := false; var seen_leave := false; var seen_dual := false
   var last_count := 0; var transitions := 0
   for n in range(10000):
    Fixture.step(sim)
    if sim.operations.candidate_id > 0 and not seen_prepare:
     seen_prepare = true; sim = roundtrip(sim)
    if sim.count_state("planning") > 0 and not seen_plan:
     seen_plan = true; sim = roundtrip(sim)
    if sim.count_state("leaving") > 0 and not seen_leave:
     seen_leave = true
     check(sim.operations.total() == 0,"fee and leaving event never credit delegated visit")
     sim = roundtrip(sim)
    if HospitalChapterProgress.simultaneous(sim): seen_dual = true
    if sim.operations.chapter_three_day != last_count:
     transitions += 1; last_count = sim.operations.chapter_three_day
    if n % 100 == 0:
     var qualified := 0
     for p in sim.patients:
      if p.state == "complete" and p.admission_source == "minji" and p.plan_source == "staff": qualified += 1
     check(sim.operations.total() == qualified,"only actual qualified departures count")
    if sim.all_done(): break
   check(sim.all_done() and seen_dual,"four combinations preserve concurrent normal operations")
   check(sim.money == 3000 and sim.lifetime_completed == 16,"four-day exact economy 900+3200-600-500")
   check(sim.chapters.total() == 16 and sim.chapters.chapter_one_day == 1 and sim.chapters.chapter_two_day == 3,"chapters one/two preserved")
   check(sim.ledger.income == 800 and sim.ledger.expansion_expense == 0 and sim.ledger.training_expense == 500,"separate daily expense receipts")
   check(sim.operations.total() == (4 if admission and planning else 0),"only both actual automated commands qualify")
   check(transitions == (1 if admission and planning else 0),"chapter three completion exactly once")
   for p in sim.patients:
    check(p.admission_source == ("minji" if admission else "manual") and p.plan_source == ("staff" if planning else "manual"),"actual immutable execution provenance")
   sim = roundtrip(sim)
   var prior := sim.operations.snapshot()
   for p in sim.patients: sim.operations.record_departure(sim.day,p)
   check(prior == sim.operations.snapshot(),"duplicate departure idempotent")
   check(sim.start_next_day() and not sim.start_next_day(),"next day double input safe")
   check(sim.operations.enabled == planning and sim.admission.enabled == admission and sim.operations.trained,"next day keeps independent duty settings and education")
   check(sim.ledger.training_expense == 0 and sim.ledger.income == 0 and sim.money == 3000,"new daily receipts preserve assets")
   sim = roundtrip(sim)
 var timing: HospitalSimulation = Fixture.prepare()
 while timing.operations.candidate_id < 0: timing.tick(.1)
 var id: int = timing.operations.candidate_id
 var elapsed: float = timing.operations.elapsed
 timing.tick(2.8-elapsed)
 check(timing.get_patient(id).state == "plan_ready" and timing.planner_owner == -1,"preparation requires three full simulation seconds")
 var before := timing.snapshot(); timing.paused = true; timing.tick(200)
 check(timing.snapshot() == before,"user pause freezes both duties")
 timing.paused = false
 timing.tick(.2)
 check(timing.get_patient(id).state == "planning" and timing.get_patient(id).elapsed < .2,"three-second preparation is separate from clinical review")
 check(not timing.assign_plan(id) and not timing.assign_plan(id,true),"automatic then manual race produces one assignment")
 timing.set_plan_delegated(false); timing.tick(4)
 check(timing.get_patient(id).state == "planning","turning off leaves existing normal five-second review running")
 timing.tick(1.1)
 check(timing.get_patient(id).state != "planning","existing five-second review completes normally")
 var race: HospitalSimulation = Fixture.prepare()
 while race.operations.candidate_id < 0: race.tick(.1)
 id = race.operations.candidate_id
 check(race.assign_plan(id) and race.operations.candidate_id == -1 and race.operations.elapsed == 0,"manual first immediately cancels preparation")
 check(not race.assign_plan(id,true) and race.get_patient(id).plan_source == "manual","stale automatic command cannot replace manual provenance")
 race = roundtrip(race)
 for n in range(5): race.set_plan_delegated(false); race.set_plan_delegated(true)
 check(race.operations.candidate_id == -1,"toggle invalidates pending work")
 Fixture.finish(race)
 check(race.operations.total() == 3 and race.money == 3000,"manual help affects only chapter eligibility without penalty")
 race.start_next_day()
 while race.operations.total() < 4: Fixture.step(race)
 check(race.day == 5 and race.operations.chapter_three_day == 5 and race.operations.total() == 4,"qualified visits accumulate across dates")
 race = roundtrip(race)
 var legacy := Fixture.Chapter.prepare(4,1,true).snapshot()
 legacy.erase("operations_training"); legacy.daily_ledger.version = 1; legacy.daily_ledger.erase("training_expense")
 for p in legacy.patients: p.erase("admission_source"); p.erase("plan_source")
 var old := HospitalSimulation.new()
 check(old.restore(JSON.parse_string(JSON.stringify(legacy))),"previous version snapshot migrates")
 check(old.admission.enabled and not old.operations.trained and not old.operations.enabled and old.operations.total() == 0,"old admission consent preserved; no education/plan consent inferred")
 old.paused = false; old.tick(10)
 check(old.get_patient(1).admission_source == "minji","migrated store records only new actual commands")
 var snapshot := race.snapshot()
 for field in ["trained","enabled","purchased_day","training_expense","visits","source"]:
  var bad := snapshot.duplicate(true)
  match field:
   "trained": bad.operations_training.trained = false
   "enabled": bad.operations_training.enabled = "yes"
   "purchased_day": bad.operations_training.purchased_day = 1
   "training_expense": bad.daily_ledger.training_expense = 500
   "visits": bad.operations_training.visits.append("5:4")
   "source": bad.patients[0].plan_source = "invented"
  var original := old.snapshot()
  check(not old.restore(bad) and old.snapshot() == original,"invalid "+field+" rejected transactionally")
 var fifo: HospitalSimulation = Fixture.prepare(true,false)
 while fifo.count_state("plan_ready") < 3: fifo.tick(.1)
 var order: Array[int] = []
 fifo.plan_assigned.connect(func(patient_id: int): order.append(patient_id))
 fifo.set_plan_delegated(true); fifo.tick(9.1)
 check(order == [1,2,3] and fifo.get_patient(3).state == "plan_queue","existing ready order and occupied planner FIFO retained")
 var closing: HospitalSimulation = Fixture.Chapter.prepare(3)
 Fixture.Chapter.finish_day(closing)
 check(closing.all_done() and closing.purchase_training() and closing.operations.purchased_day == 3,"education can be bought at chapter-two closing journal")
 closing = roundtrip(closing)
 closing.start_next_day(); closing.set_admission_delegated(true); closing.set_plan_delegated(true)
 Fixture.finish(closing)
 check(closing.money == 3000 and closing.operations.total() == 4 and closing.ledger.training_expense == 0,"education on previous closing date retains exact four-day economics")
 var dialogue: HospitalSimulation = Fixture.Chapter.prepare(4)
 dialogue.operations.sync_story(dialogue,true,true); dialogue.operations.next_line()
 dialogue = roundtrip(dialogue)
 check(dialogue.operations.active == "introduction" and dialogue.operations.line == 1,"planner line resumes without replaying Minji")
 dialogue.operations.finish_scene()
 check(dialogue.money == 2700 and not dialogue.operations.trained and not dialogue.operations.enabled,"skipping introduction is never purchase consent")
 dialogue.purchase_training(); dialogue.operations.sync_story(dialogue,true,true)
 dialogue.operations.guidance_changed(false,dialogue); dialogue.operations.guidance_changed(true,dialogue)
 dialogue.operations.sync_story(dialogue,true,true)
 check(dialogue.operations.active == "" and not dialogue.operations.enabled,"story off/re-enable never activates plans or replays past education")
 var ongoing: HospitalSimulation = Fixture.Chapter.prepare(4,1,true)
 while ongoing.count_state("planning") == 0: Fixture.Chapter.step(ongoing)
 var historical := ongoing.snapshot(); historical.erase("operations_training")
 historical.daily_ledger.version = 1; historical.daily_ledger.erase("training_expense")
 for p in historical.patients: p.erase("admission_source"); p.erase("plan_source")
 check(old.restore(historical) and old.planner_owner > 0,"old in-flight clinical work restores without new metadata")
 check(old.get_patient(old.planner_owner).plan_source == "legacy" and old.operations.total() == 0,"unknown historical work never becomes delegated credit")
 var result := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"platform":"Linux Godot headless; separate test save","physical_mobile":false}
 DirAccess.make_dir_recursive_absolute("res://../artifacts/operations-unit")
 FileAccess.open("res://../artifacts/operations-unit/results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("OPERATIONS: ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
