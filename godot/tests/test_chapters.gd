extends SceneTree
const Fixture = preload("res://tests/chapter_fixture.gd")
var checks := 0
var failures: Array[String] = []
var stored := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label); printerr("FAIL: ",label)
func roundtrip(sim: HospitalSimulation) -> HospitalSimulation:
 var store := HospitalSaveStore.new(); store.path = "user://chapter-unit.json"
 check(store.save(sim),"actual atomic chapter save")
 var loaded := HospitalSimulation.new()
 check(store.load_into(loaded),"actual chapter load")
 check(JSON.stringify(loaded.snapshot()) == JSON.stringify(sim.snapshot()),"operating and chapter records round-trip exactly")
 check(loaded.paused,"restored game waits for player resume")
 loaded.paused = false
 stored += 1
 return loaded
func run() -> void:
 for delegation in [false,true]:
  for expansion_day in [1,2]:
   var sim := HospitalSimulation.new()
   var transitions := 0
   var previous := 0
   var boundary := false
   for day in range(1,4):
    check(sim.day == day,"normal calendar advances sequentially")
    if delegation and day >= 2: sim.set_admission_delegated(true)
    for n in range(10000):
     Fixture.step(sim,expansion_day)
     var departed := (day-1)*4+sim.count_state("complete")
     if n % 100 == 0: check(sim.chapters.total() == departed,"only actual departures contribute")
     if day == 1 and sim.completed() == 4 and not sim.all_done():
      check(sim.chapters.chapter_one_day == 0,"last fee does not complete chapter one before departure")
     if day == 3 and sim.chapters.total() == 11 and sim.completed() == 4 and not boundary:
      boundary = true
      check(sim.chapters.chapter_two_day == 0 and sim.lifetime_completed == 12,"12 paid visits with 11 departures is not chapter completion")
      sim = roundtrip(sim)
      check(sim.chapters.total() == 11 and sim.chapters.chapter_two_day == 0,"restore before boundary gives no extra visit")
     if sim.chapters.chapter_two_day != previous:
      transitions += 1; previous = sim.chapters.chapter_two_day
     if sim.all_done(): break
    check(sim.all_done() and sim.chapters.total() == day*4,"all four actual departures counted per day")
    check(sim.chapters.chapter_one_day == 1,"chapter one completes at first journal eligibility")
    check(sim.chapters.dual_experienced == (day >= expansion_day),"early expansion/actual concurrent use carried forward")
    check(sim.ledger.income == 800 and sim.ledger.expansion_expense == (600 if day == expansion_day else 0),"daily receipts unchanged")
    sim = roundtrip(sim)
    if day < 3:
     var total := sim.chapters.total(); var balance := sim.money
     check(sim.start_next_day() and not sim.start_next_day(),"next day cannot be entered twice")
     check(sim.chapters.total() == total and sim.ledger.income == 0 and sim.ledger.expansion_expense == 0 and sim.money == balance,"daily reset preserves cumulative progress and balance")
   check(boundary and transitions == 1 and sim.chapters.chapter_two_day == 3,"11 to 12 completes chapter two exactly once")
   check(sim.money == 2700 and sim.chapters.total() == 12,"three-day economy is 900 + 2400 - 600 = 2700")
   var before := sim.chapters.snapshot()
   for n in range(10):
    sim.chapters.record_departure(3,4); sim.chapters.record_departure(1,1); sim.chapters.observe(sim)
   check(sim.chapters.snapshot() == before,"duplicate/archived visit keys and repeated observation are idempotent")
   check(sim.start_next_day() and sim.day == 4 and sim.chapters.total() == 12,"free operation continues after both chapters")
   check(sim.admission.enabled == delegation,"delegation preference survives chapter completion")
 var serial := HospitalSimulation.new()
 for day in range(3):
  Fixture.finish_day(serial,1,true)
  if day < 2: serial.start_next_day()
 check(serial.expanded and serial.chapters.total() == 12 and not serial.chapters.dual_experienced and serial.chapters.chapter_two_day == 0,"expanded empty rooms and sequential care do not qualify as concurrent treatment")
 var late := Fixture.prepare(4,4)
 check(late.chapters.total() == 12 and not late.expanded and late.chapters.chapter_two_day == 0,"postponing annex beyond three days is allowed")
 Fixture.finish_day(late,4)
 check(late.chapters.chapter_two_day == 4 and late.chapters.total() == 16 and late.money == 3500,"late annex and dual operation complete chapter without deadline or rewards")
 var partial := HospitalSimulation.new()
 while partial.completed() < 1: Fixture.step(partial,99)
 check(partial.count_state("leaving") == 1 and partial.chapters.total() == 0,"payment/going home do not count as completed visit")
 partial = roundtrip(partial)
 while partial.count_state("complete") < 1: partial.tick(.1)
 check(partial.chapters.total() == 1,"restored departure counts once")
 var legacy_sim := Fixture.prepare(3,1)
 Fixture.step(legacy_sim,1)
 var legacy := legacy_sim.snapshot(); legacy.erase("chapter_progress"); legacy.erase("daily_schedule")
 var loaded := HospitalSimulation.new()
 check(loaded.restore(legacy) and loaded.day == 3 and loaded.money == legacy_sim.money,"legacy save is preserved, never reset")
 check(loaded.chapters.total() == 8 and loaded.chapters.chapter_one_day == 1,"closed-day invariant restores exact eight departures")
 check(not loaded.chapters.dual_experienced and legacy.max_treating == 2,"old max_treating is not used as unsupported past evidence")
 check(loaded.chapters.seen.size() == 3 and loaded.chapters.presented == [1],"legacy users do not receive old scene/first-chapter ceremony backlog")
 loaded.paused = false
 while not HospitalChapterProgress.simultaneous(loaded): Fixture.step(loaded,1)
 check(loaded.chapters.dual_experienced,"actual restored gameplay can establish concurrent experience")
 var ongoing := loaded.snapshot(); ongoing.erase("chapter_progress")
 check(loaded.restore(ongoing) and loaded.chapters.dual_experienced,"two validated currently treating occupants are trustworthy evidence")
 legacy.lifetime_completed = 0
 check(loaded.restore(legacy) and loaded.chapters.legacy_partial and loaded.chapters.total() == 0,"contradictory legacy counters retain operations but do not invent historical visits")
 var valid := Fixture.prepare(3).snapshot()
 for field in ["version","visits","archived_visits","chapter_two_day"]:
  var invalid := valid.duplicate(true)
  invalid.chapter_progress[field] = {"version":99,"visits":["3:1"],"archived_visits":12,"chapter_two_day":2}[field]
  var before := loaded.snapshot()
  check(not loaded.restore(invalid) and loaded.snapshot() == before,"invalid chapter metadata rejected atomically: "+field)
 var game = load("res://main.tscn").instantiate(); root.add_child(game); game.set_process(false)
 await process_frame
 game.story.disable()
 Fixture.finish_day(game.sim,1); game.refresh()
 check(game.journal.visible and game.journal.chapter_stamp.text.contains("1장") and game.sim.chapters.presented == [1],"journal shows first-chapter stamp without another dialogue")
 var count: int = game.sim.chapters.total(); var money: int = game.sim.money
 game.open_journal(); game.journal.present(game.sim,false)
 check(game.sim.chapters.total() == count and game.sim.money == money and game.sim.chapters.presented == [1],"reopening journal cannot count visits, reward money or repeat ceremony")
 game.start_day(); game.sim.paused = false
 check(game.sim.chapters.total() == 4,"first-day visits are already part of chapter two")
 game.story.enabled = true; game.refresh(); game.answer_admission_offer(false)
 check(game.story_panel.visible and not game.admission_offer.visible and game.sim.chapters.active == "annex_ready","chapter speech yields to admission choice")
 var speech: String = game.story_text.text
 game.sim.tick(15); game.refresh()
 check(game.story_text.text == speech,"reading has no deadline or passive replacement")
 game.skip_story(); game.toggle_guidance(); game.toggle_guidance(); game.refresh()
 check(game.sim.chapters.active == "" and not game.sim.admission.enabled,"skip/re-enable preserves manual choice and suppresses historical story backlog")
 Fixture.finish_day(game.sim,1); game.sim.start_next_day(); Fixture.finish_day(game.sim,1)
 game.sim.chapters.finish_scene(); game.refresh()
 check(game.journal.visible and game.journal.chapter_stamp.text.contains("2장") and game.journal.quote.text.contains("자리"),"chapter-two completion reflection lives in actual end-of-day journal")
 var quote: String = game.journal.quote.text
 game.journal.present(game.sim,true)
 check(game.journal.quote.text != quote and game.sim.chapters.presented == [1,2],"completion speech is one-time; permanent stamp remains")
 roundtrip(game.sim)
 DirAccess.remove_absolute("user://chapter-unit.json")
 DirAccess.make_dir_recursive_absolute("res://../artifacts/chapter-unit")
 var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"real_file_roundtrips":stored,"physical_device":false}
 FileAccess.open("res://../artifacts/chapter-unit/results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("CHAPTERS: ",checks," checks, ",failures.size()," failures")
 game.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
