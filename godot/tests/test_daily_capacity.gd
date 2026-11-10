extends SceneTree
const Fixture = preload("res://tests/daily_capacity_fixture.gd")
const Chapter = preload("res://tests/chapter_fixture.gd")
const Research = preload("res://tests/research_fixture.gd")
var checks := 0
var failures: Array[String] = []
var traces: Array = []
var restores := {}
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label); printerr("FAIL: ",label)
func roundtrip(sim: HospitalSimulation, label: String) -> void:
 var store := HospitalSaveStore.new(); store.path = "user://daily-capacity-test.json"
 check(store.save(sim),label+" file save")
 if label.begins_with("5:") or label.begins_with("6:"):
  DirAccess.make_dir_recursive_absolute("res://../artifacts/capacity-restart-checkpoints")
  var checkpoint := HospitalSaveStore.new()
  checkpoint.path = "res://../artifacts/capacity-restart-checkpoints/"+label.replace(":","-")+".json"
  check(checkpoint.save(sim),label+" restart checkpoint saved")
 var copy := HospitalSimulation.new()
 var loaded := store.load_into(copy)
 check(loaded,label+" file load")
 if loaded:
  check(JSON.stringify(copy.snapshot()) == JSON.stringify(sim.snapshot()),label+" exact data")
  var before := copy.snapshot(); copy.tick(20)
  check(copy.paused and copy.snapshot() == before,label+" restores paused")
func day(sim: HospitalSimulation, record: bool = false) -> void:
 var seen := {}
 for n in range(10000):
  for p in sim.patients:
   if p.id >= 5 and record:
    var key: String = str(p.id)+":"+p.state
    if not seen.has(key):
     seen[key] = true; roundtrip(sim,key)
     restores[key] = true
   if p.state == "complete" and not seen.has("counted"+str(p.id)):
    seen["counted"+str(p.id)] = true
    var before := sim.chapters.total()
    sim.chapters.record_departure(sim.day,p.id,sim.schedule.today_count)
    check(before == sim.chapters.total(),"departure idempotent")
  if sim.schedule.today_count == 6 and sim.count_state("complete") == 4:
   check(not sim.all_done() and not sim.start_next_day(4),"four of six cannot close")
   check(sim.research.closed_through == sim.day-1,"four of six cannot produce research")
  Fixture.step(sim)
  if sim.all_done(): break
 for p in sim.patients:
  if p.id >= 5 and record and p.state == "complete": restores[str(p.id)+":complete"] = true
 check(sim.all_done(),"all booked patients depart")
 traces.append({"day":sim.day,"booked":sim.schedule.today_count,"departed":sim.count_state("complete"),"income":sim.ledger.income,"money":sim.money,"visits":sim.chapters.total(),"research_points":sim.research.points,"dual_treatment":sim.max_treating,"sim_seconds":sim.time})
 roundtrip(sim,"closed day "+str(sim.day))
func run() -> void:
 var sim := HospitalSimulation.new()
 check(sim.schedule.today_count == 4 and sim.schedule.preferred_count == 4,"new game first day four")
 Chapter.finish_day(sim,99)
 var before := sim.snapshot()
 check(not sim.start_next_day(6) and sim.snapshot() == before,"no annex six rejected transactionally")
 check(sim.start_next_day() and sim.schedule.today_count == 4,"no annex default four")
 sim = Fixture.first_journal()
 before = sim.snapshot()
 for count in [0,5,7]: check(not sim.start_next_day(count) and sim.snapshot() == before,"invalid next booking")
 check(sim.start_next_day() and sim.schedule.today_count == 4,"annex default initially four")
 # User's exact manual reference path: no education or research purchases.
 sim = Fixture.first_journal(); traces.append({"day":1,"booked":4,"departed":4,"income":800,"money":sim.money,"visits":sim.chapters.total()})
 check(sim.schedule.closed_counts == [4],"first day exact close receipt")
 check(sim.start_next_day(6) and not sim.start_next_day(6),"six commits once")
 check(sim.time == 0 and sim.patients.size() == 1 and sim.schedule.preferred_count == 6,"bookings fixed before arrivals; preference committed")
 day(sim,true)
 check(sim.money == 2300 and sim.ledger.income == 1200 and sim.chapters.total() == 10,"manual six day exact income")
 check(sim.schedule.closed_counts == [4,6],"variable closed receipts preserved")
 check(sim.start_next_day() and sim.schedule.today_count == 6,"last committed six is default")
 day(sim)
 check(sim.money == 3500 and sim.chapters.total() == 16 and sim.lifetime_completed == 16,"4+6+6 manual 16 visits and 3500")
 check(sim.chapters.chapter_two_day == 3 and sim.max_treating == 2 and not sim.operations.trained and sim.research.built_day == 0,"chapters and two treatment rooms, no extra purchases")
 check(sim.start_next_day(4) and sim.schedule.today_count == 4 and sim.schedule.preferred_count == 4,"six to four retains exact history")
 roundtrip(sim,"4-6-6-4")
 # Midday construction does not add bookings or advance future arrivals.
 sim = HospitalSimulation.new()
 while sim.completed() == 0: Fixture.step(sim)
 check(sim.purchase_expansion() and sim.schedule.today_count == 4,"midday annex keeps current four")
 day(sim)
 # Actual old 0.6.0 checkpoint from the previous release, never a player save.
 var old: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/capacity-legacy-0.6.0.json"))
 check(old is Dictionary and not old.has("daily_schedule"),"old fixture has no new booking fields")
 var migrated := HospitalSimulation.new()
 check(migrated.restore(old),"0.6.0 save migrates")
 check(migrated.schedule.today_count == 4 and migrated.schedule.preferred_count == 4 and migrated.money == int(old.money),"legacy current day/cash unchanged")
 check(JSON.parse_string(JSON.stringify(migrated.research.snapshot())) == old.research_lab and migrated.operations.enabled == old.operations_training.enabled and migrated.admission.enabled == old.staff_admission.enabled,"legacy research, education and duty settings retained")
 roundtrip(migrated,"legacy migrated resave")
 Fixture.finish(migrated); check(migrated.start_next_day(6),"legacy next transition allows six")
 day(migrated,true)
 check(migrated.schedule.closed_counts.back() == 6,"post-migration variable day stores actual count")
 # Actual earned education + lab. Independent four-point production with six visits.
 sim = Research.prepare(); check(sim.purchase_lab() and sim.start_research("ct"),"real earned research setup")
 Fixture.finish(sim); sim.start_next_day(6)
 var points := sim.research.points
 day(sim,true)
 check(sim.ledger.income == 1200 and sim.research.points == points+4,"six visits still produce four research points")
 check(sim.research.projects.ct.completed_day == 6 and not sim.research.applied("ct"),"research completes once at full six-person close")
 check(sim.operations.visits.size() == 6,"all six delegated visits eligible")
 check(sim.start_next_day(4) and sim.duration_for("ct_scan") == 4,"effect applied before next arrivals")
 roundtrip(sim,"research after six-day close")
 # New variable histories cannot be reconstructed by multiplying the date.
 var saved := sim.snapshot()
 for kind in ["count","history","day_one","preference","payment","malformed"]:
  var bad := saved.duplicate(true)
  match kind:
   "count": bad.daily_schedule.today_count = 5
   "malformed": bad.daily_schedule.today_count = {}
   "history": bad.daily_schedule.closed_counts[5] = 4
   "day_one": bad.daily_schedule.closed_counts[0] = 6
   "preference": bad.daily_schedule.preferred_count = 5
   "payment": bad.lifetime_completed += 1
  var target := HospitalSimulation.new(); before = target.snapshot()
  check(not target.restore(bad) and target.snapshot() == before,"invalid "+kind+" rejected without clearing save")
 for id in [5,6]:
  for state in ["entering","waiting","walk_ct","ct_scan","walk_plan","plan_ready","walk_treatment","treatment","leaving","complete"]:
   check(restores.has(str(id)+":"+state),"real save coverage "+str(id)+":"+state)
 var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"full_day_records":traces,"save_phases":restores.keys(),"platform":"Linux Godot 4.6.3 headless; normal simulation commands, accelerated test loop","physical_mobile":false}
 DirAccess.make_dir_recursive_absolute("res://../artifacts/daily-capacity-unit")
 FileAccess.open("res://../artifacts/daily-capacity-unit/results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("DAILY CAPACITY: ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
