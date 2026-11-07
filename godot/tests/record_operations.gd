extends "res://tests/record_normal.gd"
const Fixture = preload("res://tests/operations_fixture.gd")
var segment := "education"
func prepare_checkpoint() -> void:
 var checkpoint: HospitalSimulation = Fixture.Chapter.prepare(4) if segment == "education" else Fixture.prepare()
 checkpoint.set_admission_delegated(segment != "education")
 if segment == "completion":
  for n in range(10000):
   checkpoint.tick(.05)
   if checkpoint.operations.total() == 3 and checkpoint.completed() == 4:
    var near_exit := false
    for p in checkpoint.patients:
     if p.state == "leaving" and p.route.size() == 1 and p.position.distance_to(p.route[0]) < 4: near_exit = true
    if near_exit: break
 assert(game.sim.restore(checkpoint.snapshot()))
 game.sim.paused = false
 game.story.enable_current(game.sim,-1)
 game.sim.chapters.guidance_changed(true,game.sim)
 if segment != "education": game.sim.operations.guidance_changed(true,game.sim)
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
  if arg.begins_with("--segment="): segment = arg.trim_prefix("--segment=")
 var compact := "--mobile-preview" in OS.get_cmdline_user_args()
 root.size = Vector2i(844,390) if compact else Vector2i(1280,720)
 game = load("res://main.tscn").instantiate()
 if compact: game.safe_insets_test = Vector4(47,0,47,21)
 root.add_child(game); game.set_process(false); await process_frame
 prepare_checkpoint()
 for actor in game.world.actors.values(): actor.free()
 game.world.actors.clear()
 game.refresh(); game.world.show_overview()
 while game.world.transition_active: await process_frame
 game.recording_caption = "Linux · 자동 입력 · 정상 1배속"
 cursor = ReviewCursor.new(); cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
 cursor.z_index = 100; cursor.hide(); game.hud.add_child(cursor)
 var checkpoint: Dictionary = game.sim.snapshot()
 checkpoint.first_day_story = game.story.snapshot()
 FileAccess.open(output.path_join("checkpoint.json"),FileAccess.WRITE).store_string(JSON.stringify(checkpoint,"  "))
 var first_frame := Engine.get_process_frames()
 var duration: int = {"education":25,"flow":85,"completion":29}[segment]
 var done := {}; var trace: Array = []; var last := ""
 var dual := false; var dual_uncovered := false; var prepared := false; var assigned := false; var journal_seen := false; var restored := false
 game.set_process(true)
 while Engine.get_process_frames()-first_frame < duration*24:
  var seconds := float(Engine.get_process_frames()-first_frame)/24.0
  dual = dual or HospitalChapterProgress.simultaneous(game.sim)
  dual_uncovered = dual_uncovered or (HospitalChapterProgress.simultaneous(game.sim) and not game.selection_panel.visible)
  prepared = prepared or game.sim.operations.candidate_id > 0
  assigned = assigned or game.sim.count_state("planning") > 0
  journal_seen = journal_seen or game.journal.visible
  var state := {"seconds":seconds,"day":game.sim.day,"money":game.sim.money,"training":game.sim.operations.trained,"auto_admission":game.sim.admission.enabled,"auto_planning":game.sim.operations.enabled,"preparing":game.sim.operations.candidate_id,"states":game.sim.patients.map(func(p): return [p.id,p.state,p.admission_source,p.plan_source]),"qualified":game.sim.operations.total(),"chapter_three_day":game.sim.operations.chapter_three_day,"journal":game.journal.visible}
  var key := str(state.values().slice(1))
  if key != last: trace.append(state); last = key
  if segment == "education":
   if seconds >= 3 and not done.has("park"): await click(game.story_next); done.park = true
   elif seconds >= 6 and not done.has("read"): await click(game.story_next); done.read = true
   elif seconds >= 8 and not done.has("settings"): await click(game.guide_settings); done.settings = true
   elif seconds >= 10 and not done.has("offer"): await click(game.training_button); done.offer = true
   elif seconds >= 14 and not done.has("purchase"):
    await click(game.training_dialog.ok_button); done.purchase = true
    assert(game.sim.operations.trained and not game.sim.operations.enabled and game.sim.money == 2200)
   elif seconds >= 17 and not done.has("enable"): await click(game.planning_toggle); done.enable = true
   elif seconds >= 20 and not done.has("close"): await click(game.guide_close); done.close = true
  elif segment == "flow":
   if seconds >= 4 and not done.has("select"):
    await select_patient(1); done.select = true
   elif seconds >= 36 and not done.has("dismiss"):
    await click(game.dismiss_button); done.dismiss = true
   elif game.sim.operations.total() >= 1 and not done.has("goals"):
    await click(game.goal_ribbon); done.goals = seconds
   elif done.has("goals") and seconds > float(done.goals)+8 and not done.has("close"):
    await click(game.chapter_panel.close_button); done.close = true
  else:
   if seconds >= 8 and game.journal.visible and not done.has("close"): await click(game.journal.close_button); done.close = true
   elif seconds >= 10 and not done.has("goals"): await click(game.goal_ribbon); done.goals = true
   elif seconds >= 14 and not done.has("journal"):
    await click(game.chapter_panel.close_button); await click(game.next_day_button); done.journal = true
   elif seconds >= 17 and not done.has("next"): await click(game.journal.next_button); done.next = true
   elif seconds >= 20 and not done.has("save"):
    await click(game.pause_button)
    game.store.path = "user://operations-video-isolated.json"
    game.store.save(game.sim,game.story)
    game.show_notice("5일차 테스트 저장\n교육 완료 · 위임 방문 4회")
    done.save = true
   elif seconds >= 24 and not done.has("restore"):
    var before: Dictionary = game.sim.snapshot()
    restored = game.store.load_into(game.sim,game.story) and JSON.stringify(game.sim.snapshot()) == JSON.stringify(before)
    game.user_paused = game.sim.paused
    game.show_notice("저장 복원 ✓ · 자금 3000만\n접수·계획 위임 유지")
    game.refresh(); done.restore = true
  await process_frame
 game.set_process(false)
 var ok: bool = game.playback_speed == 1.0
 if segment == "education": ok = ok and game.sim.operations.trained and game.sim.operations.enabled and not game.sim.admission.enabled and game.sim.money == 2200
 elif segment == "flow": ok = ok and dual and dual_uncovered and prepared and assigned and game.sim.operations.total() >= 1 and done.has("goals")
 else: ok = ok and journal_seen and restored and game.sim.day == 5 and game.sim.operations.total() == 4 and game.sim.operations.chapter_three_day == 4 and game.sim.money == 3000 and game.sim.ledger.training_expense == 0
 var result := {"passed":ok,"segment":segment,"automatic_input":true,"platform":"Linux Godot 4.6.3 OpenGL llvmpipe","physical_mobile":false,"simulation_speed":1,"fps":24,"recorded_frames":Engine.get_process_frames()-first_frame,"real_canvas_clicks":click_count,"two_rooms_actually_treating":dual,"two_rooms_without_patient_card":dual_uncovered,"preparation_shown":prepared,"normal_planning_shown":assigned,"journal_shown":journal_seen,"real_file_restored":restored,"checkpoint_prepared_by_normal_simulation":true,"trace":trace}
 FileAccess.open(output.path_join("movie-results.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("OPERATIONS MOVIE: ",JSON.stringify(result))
 quit(0 if ok else 1)
