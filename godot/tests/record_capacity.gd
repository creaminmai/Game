extends "res://tests/record_normal.gd"
const Fixture = preload("res://tests/daily_capacity_fixture.gd")
var segment := "booking"
var checkpoints := {}
var switches: Array = []
func prepare() -> void:
 var sim := Fixture.first_journal()
 checkpoints.booking = sim.snapshot()
 assert(sim.start_next_day(6))
 sim.tick(40) # Real staggered arrivals; the user has not yet admitted anyone.
 checkpoints.waiting = sim.snapshot()
 for n in range(10000):
  Fixture.step(sim,.05)
  if HospitalChapterProgress.simultaneous(sim): break
 checkpoints.dual = sim.snapshot()
 for n in range(10000):
  Fixture.step(sim,.05)
  if sim.count_state("complete") == 5 and sim.count_state("leaving") == 1:
   var last: Dictionary = sim.patients.filter(func(p): return p.state == "leaving")[0]
   if last.route.size() == 1 and last.position.distance_to(last.route[0]) < 5: break
 checkpoints.ending = sim.snapshot()
 FileAccess.open(output.path_join("checkpoints.json"),FileAccess.WRITE).store_string(JSON.stringify(checkpoints,"  "))
func use_checkpoint(id: String, second: float = -1) -> void:
 game.set_process(false)
 game.journal.hide(); game.capacity_dialog.hide(); game.roster.hide(); game.clear_selection()
 assert(game.sim.restore(checkpoints[id]))
 game.sim.paused = false; game.user_paused = false; game.pause_holds.clear()
 game.story.disable(); game.answer_admission_offer(false)
 game.journal_seen_day = -1
 for actor in game.world.actors.values(): actor.free()
 game.world.actors.clear()
 game.refresh(); game.world.show_overview()
 if second >= 0:
  switches.append({"video_second":second,"checkpoint":id,"day":game.sim.day,"simulation_time":game.sim.time})
  game.show_notice("다음 구간 · 정상 운영 저장에서 재개\n여섯 환자의 두 치료실 운영")
 game.set_process(true)
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
  if arg.begins_with("--segment="): segment = arg.trim_prefix("--segment=")
 root.size = Vector2i(844,390) if "--mobile-preview" in OS.get_cmdline_user_args() else Vector2i(1280,720)
 game = load("res://main.tscn").instantiate()
 if root.size.x == 844: game.safe_insets_test = Vector4(47,0,47,21)
 root.add_child(game); game.set_process(false); await process_frame
 prepare(); use_checkpoint({"booking":"booking","flow":"waiting","journal":"ending"}[segment])
 if segment == "booking": game.story.enable_current(game.sim,-1)
 game.recording_caption = "Linux · 자동 입력 · 정상 1배속"
 game.refresh()
 cursor = ReviewCursor.new(); cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
 cursor.z_index = 100; cursor.hide(); game.hud.add_child(cursor)
 var first_frame := Engine.get_process_frames()
 var duration: int = {"booking":22,"flow":54,"journal":25}[segment]
 var done := {}; var trace: Array = []; var last := ""; var dual := false; var restored := false
 while Engine.get_process_frames()-first_frame < duration*24:
  var second := float(Engine.get_process_frames()-first_frame)/24.0
  dual = dual or HospitalChapterProgress.simultaneous(game.sim)
  var state := {"seconds":second,"day":game.sim.day,"time":game.sim.time,"booked":game.sim.schedule.today_count,"money":game.sim.money,"income":game.sim.ledger.income,"departed":game.sim.count_state("complete"),"states":game.sim.patients.map(func(p): return [p.id,p.state]),"journal":game.journal.visible}
  var key := str([state.day,state.booked,state.money,state.departed,state.states,state.journal])
  if key != last: trace.append(state); last = key
  if segment == "booking":
   if second >= 3 and not done.has("open"): await click(game.journal.next_button); done.open = true
   elif second >= 6 and not done.has("choose"): await click(game.capacity_dialog.six); done.choose = true
   elif second >= 12 and not done.has("start"): await click(game.capacity_dialog.start_button); done.start = true
   elif second >= 15 and not done.has("manual"):
    if game.admission_offer.visible: await click(game.admission_decline)
    game.story.disable(); game.refresh(); done.manual = true
  elif segment == "flow":
   if second >= 1 and not done.has("list"): await click(game.patient_button); done.list = true
   elif second >= 4 and not done.has("six"):
    game.roster_scroll.ensure_control_visible(game.rows[5]); done.six = true
   elif second >= 7 and not done.has("first"):
    game.roster_scroll.ensure_control_visible(game.rows[0]); await process_frame
    await click(game.rows[0]); await click(game.action_button); done.first = true
   elif second >= 10 and not done.has("duty"): await click(game.guide_settings); done.duty = true
   elif second >= 12 and not done.has("auto"): await click(game.admission_toggle); done.auto = true
   elif second >= 14 and not done.has("close"): await click(game.guide_close); done.close = true
   elif game.sim.get_patient(1).state == "plan_ready" and not done.has("plan"):
    await click(game.action_button); done.plan = true
   elif second >= 36 and done.has("plan") and not done.has("jump"):
    use_checkpoint("dual",second); done.jump = true
   elif second >= 42 and not done.has("card"):
    await select_patient(2); done.card = true
  else:
   if second >= 7 and game.journal.visible and not done.has("open"): await click(game.journal.next_button); done.open = true
   elif second >= 10 and not done.has("four"): await click(game.capacity_dialog.four); done.four = true
   elif second >= 15 and not done.has("start"): await click(game.capacity_dialog.start_button); done.start = true
   elif second >= 18 and not done.has("restore"):
    await click(game.pause_button)
    game.store.path = "user://capacity-movie-test.json"
    var before: Dictionary = game.sim.snapshot()
    assert(game.store.save(game.sim,game.story))
    restored = game.store.load_into(game.sim,game.story) and JSON.stringify(game.sim.snapshot()) == JSON.stringify(before)
    game.user_paused = true; game.refresh()
    game.show_notice("저장 복원 ✓ · 3일차 예약 4명\n보유 자금 2300만 · 지난 6명 기록 유지")
    done.restore = true
  await process_frame
 game.set_process(false)
 var ok: bool = game.playback_speed == 1
 if segment == "booking": ok = ok and done.has("start") and game.sim.day == 2 and game.sim.schedule.today_count == 6 and game.sim.money == 1100
 elif segment == "flow": ok = ok and done.has("plan") and dual and game.sim.schedule.today_count == 6
 else: ok = ok and restored and game.sim.day == 3 and game.sim.schedule.today_count == 4 and game.sim.money == 2300 and game.sim.schedule.closed_counts == [4,6]
 var result := {"passed":ok,"segment":segment,"automatic_input":true,"platform":"Linux Godot 4.6.3 Compatibility llvmpipe","physical_mobile":false,"simulation_speed":1,"fps":24,"recorded_frames":Engine.get_process_frames()-first_frame,"real_canvas_clicks":click_count,"checkpoint_prepared_by_normal_simulation":true,"checkpoint_switches":switches,"continuous_segment":segment != "flow","full_day_validation":"test_daily_capacity.gd","trace":trace,"dual_treatment":dual,"file_restored":restored}
 FileAccess.open(output.path_join("movie-results.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("CAPACITY MOVIE ",segment," passed=",ok)
 quit(0 if ok else 1)
