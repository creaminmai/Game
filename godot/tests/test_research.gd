extends SceneTree
const Fixture = preload("res://tests/research_fixture.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(value: bool, caption: String) -> void:
 checks += 1
 if not value: failures.append(caption); printerr("FAIL: ",caption)
func roundtrip(sim: HospitalSimulation, label: String) -> HospitalSimulation:
 var store := HospitalSaveStore.new(); store.path = "user://research-unit.json"
 check(store.save(sim),label+" file save")
 var restored := HospitalSimulation.new()
 var loaded := store.load_into(restored)
 check(loaded,label+" actual file restore")
 if not loaded: quit(1); return sim
 check(JSON.stringify(sim.snapshot()) == JSON.stringify(restored.snapshot()),label+" exact receipts and states")
 var before := restored.snapshot(); restored.tick(100)
 check(restored.paused and before == restored.snapshot(),label+" restored pause preserves all clocks")
 restored.paused = false
 return restored
func run() -> void:
 var locked := HospitalSimulation.new()
 check(not locked.purchase_lab() and locked.money == 900,"chapter three lock no charge")
 check(not locked.start_research("ct"),"research requires lab")
 var sim := Fixture.prepare()
 var before := sim.snapshot()
 check(sim.research.build_reason(sim) == "" and sim.snapshot() == before,"read/cancel construction no mutation")
 sim.money = 1799
 check(not sim.purchase_lab() and sim.money == 1799,"insufficient construction funds")
 sim.money = 3000
 check(sim.purchase_lab() and sim.money == 1200 and sim.research.points == 6,"one actual 1800 transaction and six-point initial grant")
 for n in range(4): check(not sim.purchase_lab() and sim.money == 1200 and sim.research.points == 6,"duplicate construction rejected")
 sim = roundtrip(sim,"construction")
 sim.money = 499
 check(not sim.start_research("ct") and sim.research.points == 6,"insufficient research funds")
 sim.money = 1200
 check(not sim.start_research("unknown"),"unknown project rejected")
 for order in [["ct","plan"],["plan","ct"]]:
  sim = Fixture.prepare()
  check(sim.purchase_lab() and sim.start_research(order[0]),"user chooses either first research")
  check(sim.money == 700 and sim.research.points == 0 and sim.ledger.lab_expense == 1800 and sim.ledger.research_expense == 500,"separate exact costs")
  check(not sim.start_research(order[1]) and not sim.start_research(order[0]),"single slot and duplicate start rejected")
  check(sim.research.chapter_four_day == 0 and sim.duration_for("ct_scan") == 5 and sim.duration_for("planning") == 5,"purchase has no early effect or chapter award")
  sim = roundtrip(sim,"research started")
  Fixture.finish(sim)
  check(sim.day == 5 and sim.money == 1500 and sim.research.points == 4,"real five-day economy 3000-1800-500+800=1500")
  check(sim.research.projects[order[0]].progress_days == 0 and sim.research.projects[order[0]].completed_day == 0,"start day is not a progress day")
  before = sim.snapshot()
  for n in range(4): sim.research.close_operating_day(sim); sim.chapters.observe(sim)
  check(sim.snapshot() == before,"reopening/day-close retries do not produce twice")
  sim = roundtrip(sim,"start-day journal")
  check(sim.start_next_day() and not sim.start_next_day(),"next day double click increments once")
  check(sim.day == 6 and sim.ledger.lab_expense == 0 and sim.ledger.research_expense == 0,"daily costs reset; research kept")
  for n in range(10000):
   Fixture.step(sim)
   if sim.count_state("complete") == 3 and sim.count_state("leaving") == 1: break
  check(not sim.all_done() and sim.research.points == 4,"last patient must actually depart")
  sim = roundtrip(sim,"before completion")
  Fixture.finish(sim)
  check(sim.research.projects[order[0]].completed_day == 6 and sim.research.points == 8,"next normal close completes and produces once")
  check(sim.research.slot() == order[0] and not sim.start_research(order[1]) and sim.research.chapter_four_day == 0,"completed pending effect still occupies slot")
  check(sim.duration_for("ct_scan") == 5 and sim.duration_for("planning") == 5,"no same-day effect")
  sim = roundtrip(sim,"awaiting application")
  sim.start_next_day()
  check(sim.research.applied(order[0]) and sim.research.chapter_four_day == 7 and sim.research.slot() == "","day seven applies before arrivals, completes chapter four")
  check(sim.patients.size() == 1 and sim.get_patient(1).state == "entering" and sim.time == 0,"effect applied before any new service starts")
  check(sim.duration_for("ct_scan") == (4 if order[0] == "ct" else 5) and sim.duration_for("planning") == (4 if order[0] == "plan" else 5),"only exact researched phase shortened")
  check(sim.duration_for("treatment") == 30 and sim.operations.DELAY == 3,"treatment and preparation unchanged")
  sim = roundtrip(sim,"applied")
  check(sim.start_research(order[1]) and sim.money == 1800 and sim.research.points == 2,"second choice starts only after release")
  for manual in [false,true]:
   var timing := HospitalSimulation.new(); check(timing.restore(sim.snapshot()),"timing scenario restore")
   timing.paused = false; timing.set_admission_delegated(not manual); timing.set_plan_delegated(not manual)
   var entered := {}; var observed := {}
   var times := {}
   for n in range(10000):
    var p := timing.get_patient(1)
    var state: String = p.state
    if state in ["ct_scan","planning"] and not entered.has(state):
     entered[state] = timing.time; times[state] = timing.service_duration(p)
     check(times[state] == timing.duration_for(state),"per-service duration latched at actual start")
     timing = roundtrip(timing,"active "+state)
    if entered.has(state): observed[state] = true
    Fixture.step(timing)
    if entered.has(state) and timing.get_patient(1).state != state and not times.has(state+"checked"):
     check(absf(timing.time-entered[state]-times[state]) <= .101,"actual "+state+" service matches UI seconds")
     times[state+"checked"] = true
    if timing.all_done(): break
   check(times.has("ct_scanchecked") and times.has("planningchecked"),"both timed phases exercised with manual/automatic commands")
   check(timing.money == 2600 and timing.max_treating == 2,"normal income and two treatment rooms preserved")
  Fixture.finish(sim); sim.start_next_day(); Fixture.finish(sim)
  check(sim.research.projects[order[1]].completed_day == 8 and not sim.research.applied(order[1]),"second project also waits through full next operating day")
  sim.start_next_day()
  check(sim.duration_for("ct_scan") == 4 and sim.duration_for("planning") == 4,"both applied by day nine independent of order")
  before = sim.research.snapshot()
  sim.research.apply_before_arrivals(sim.day)
  check(sim.research.snapshot() == before,"effect application idempotent, never cumulative")
  check(not sim.start_research(order[0]) and not sim.start_research(order[1]),"completed research cannot be purchased again")
  sim = roundtrip(sim,"both applied")
 # Built after an existing close: no retroactive grant, even across restoration.
 sim = Fixture.prepare(4)
 check(sim.all_done() and sim.purchase_lab(),"construct on completed day")
 check(sim.research.daily(4).initial == 6 and sim.research.daily(4).produced == 0,"initial grant distinct from production")
 sim.research.close_operating_day(sim)
 check(sim.research.points == 6,"closed day never retroactively produces")
 sim = roundtrip(sim,"built after close")
 sim.start_next_day(); Fixture.finish(sim)
 check(sim.research.points == 10 and sim.research.daily(5).produced == 4,"next actual operating day earns four")
 # Cap is reached by real days; saturation receipt may be partial or zero.
 for day_index in range(50): sim.start_next_day(); Fixture.finish(sim)
 check(sim.research.points == 200,"real operating days respect 200 cap")
 check(sim.research.daily(sim.day).produced == 0,"full cap records zero production truthfully")
 sim = roundtrip(sim,"capped")
 check(sim.start_research("ct") and sim.research.points == 194,"spending at cap deducts exact six")
 # Insufficient points independent of occupied-slot reason.
 sim = Fixture.prepare(); sim.purchase_lab(); sim.start_research("ct")
 Fixture.finish(sim); sim.start_next_day(); Fixture.finish(sim); sim.start_next_day(); sim.start_research("plan")
 # Isolated malformed-budget boundary tests do not author gameplay checkpoints.
 var scarce := Fixture.prepare(); scarce.purchase_lab(); scarce.research.points = 5
 var scarce_before := scarce.snapshot()
 check(scarce.research.start_reason(scarce,"ct").contains("점수 부족") and not scarce.start_research("ct") and scarce.snapshot() == scarce_before,"point shortage distinct from funds/slot, no mutation")
 var idle := Fixture.prepare(); idle.purchase_lab(); idle.paused = true
 var idle_before := idle.snapshot(); idle.tick(999)
 idle.research.close_operating_day(idle)
 check(idle.snapshot() == idle_before,"paused or unfinished operating day cannot produce points")
 check(not idle.start_next_day(),"empty/unfinished day cannot be skipped for production")
 var speech_sim := Fixture.prepare(); speech_sim.purchase_lab()
 speech_sim.research.sync_story(true,true)
 check(speech_sim.research.active == "introduction" and speech_sim.research.speech()[0] == "윤서진","named researcher introduction")
 speech_sim = roundtrip(speech_sim,"research dialogue")
 speech_sim.research.next_line()
 check(speech_sim.research.speech()[0] == "민지","two-line shared scene")
 speech_sim.research.finish_scene(); speech_sim.research.sync_story(true,true)
 check(speech_sim.research.active == "" and speech_sim.research.projects.is_empty() and speech_sim.money == 1200,"skip does not repeat or consent to project")
 speech_sim.research.guidance_changed(false); speech_sim.research.guidance_changed(true); speech_sim.research.sync_story(true,true)
 check(speech_sim.research.active == "","reenable does not replay historical research introduction")
 # Old data safely defaults, retains money/facilities/education/consent.
 var old := Fixture.prepare().snapshot(); old.erase("research_lab")
 old.daily_ledger.version = 2; old.daily_ledger.erase("lab_expense"); old.daily_ledger.erase("research_expense")
 for p in old.patients: p.erase("service_duration")
 var migrated := HospitalSimulation.new()
 check(migrated.restore(JSON.parse_string(JSON.stringify(old))),"old chapter three save migrates")
 check(migrated.money == 3000 and migrated.expanded and migrated.operations.trained and migrated.operations.enabled and migrated.admission.enabled and migrated.research.points == 0 and migrated.research.built_day == 0,"old assets and explicit duties preserved")
 var valid := sim.snapshot()
 for kind in ["points","duplicate","date","ledger","effect","grant"]:
  var broken := valid.duplicate(true)
  match kind:
   "points": broken.research_lab.points += 1
   "duplicate": broken.research_lab.events.append(broken.research_lab.events[0])
   "date": broken.research_lab.projects.ct.start_day -= 1
   "ledger": broken.daily_ledger.research_expense = 0
   "effect": broken.research_lab.chapter_four_day = 0
   "grant": broken.research_lab.initial_granted = false
  var target := HospitalSimulation.new(); var original := target.snapshot()
  check(not target.restore(broken) and target.snapshot() == original,"invalid "+kind+" rejected atomically")
 var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"platform":"Linux Godot headless","physical_mobile":false}
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../artifacts/research-unit"))
 FileAccess.open("res://../artifacts/research-unit/results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("RESEARCH: ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
