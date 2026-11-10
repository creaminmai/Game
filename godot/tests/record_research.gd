extends "res://tests/record_normal.gd"
const Fixture = preload("res://tests/research_fixture.gd")
var segment := "building"
var checkpoints := {}
var checkpoint_switches: Array[Dictionary] = []

func prepare_checkpoints() -> void:
 var sim: HospitalSimulation = Fixture.prepare()
 if segment != "building": assert(sim.purchase_lab())
 checkpoints.initial = sim.snapshot()
 if segment == "progress" or segment == "application":
  assert(sim.start_research("ct"))
  Fixture.finish(sim); assert(sim.start_next_day())
  for n in range(10000):
   Fixture.step(sim,.05)
   if sim.count_state("complete") == 3 and sim.count_state("leaving") == 1:
    var leaving: Dictionary = sim.patients.filter(func(p): return p.state == "leaving")[0]
    if leaving.route.size() == 1 and leaving.position.distance_to(leaving.route[0]) < 5: break
  checkpoints.day_six_close = sim.snapshot()
  Fixture.finish(sim)
  checkpoints.day_six_journal = sim.snapshot()
  if segment == "application":
   checkpoints.initial = sim.snapshot()
   assert(sim.start_next_day())
   for n in range(10000):
    Fixture.step(sim,.05)
    if sim.count_state("complete") == 3 and sim.count_state("leaving") == 1:
     var leaving: Dictionary = sim.patients.filter(func(p): return p.state == "leaving")[0]
     if leaving.route.size() == 1 and leaving.position.distance_to(leaving.route[0]) < 5: break
   checkpoints.day_seven_close = sim.snapshot()
 FileAccess.open(output.path_join("checkpoints.json"),FileAccess.WRITE).store_string(JSON.stringify(checkpoints,"  "))

func use_checkpoint(id: String, seconds: float = -1) -> void:
 game.set_process(false)
 if game.outside: game.toggle_outside()
 game.research_panel.close(); game.journal.hide(); game.chapter_panel.hide(); game.guide_panel.hide()
 game.clear_selection()
 assert(game.sim.restore(checkpoints[id]))
 game.pause_holds.clear(); game.sim.paused = false; game.user_paused = false
 game.story.enable_current(game.sim,-1)
 game.sim.chapters.guidance_changed(true,game.sim)
 game.sim.operations.guidance_changed(true,game.sim)
 if segment != "building": game.sim.research.guidance_changed(true)
 game.journal_seen_day = -1
 for actor in game.world.actors.values(): actor.free()
 game.world.actors.clear()
 game.refresh(); game.world.show_overview()
 if seconds >= 0:
  checkpoint_switches.append({"video_second":seconds,"checkpoint":id,"day":game.sim.day,"time":game.sim.time,"normal_commands_only":true})
  game.show_notice("다음 구간 · %d일차 마감 직전\n정상 운영으로 준비한 저장에서 재개" % game.sim.day)
 game.set_process(true)

func reveal(control: Control) -> void:
 game.research_panel.scroll.ensure_control_visible(control)
 for n in range(3): await process_frame

func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
  if arg.begins_with("--segment="): segment = arg.trim_prefix("--segment=")
 var compact := "--mobile-preview" in OS.get_cmdline_user_args()
 root.size = Vector2i(844,390) if compact else Vector2i(1280,720)
 game = load("res://main.tscn").instantiate()
 if compact: game.safe_insets_test = Vector4(47,0,47,21)
 root.add_child(game); game.set_process(false); await process_frame
 prepare_checkpoints(); use_checkpoint("initial"); game.set_process(false)
 if segment in ["building","progress"]: game.toggle_outside()
 game.recording_caption = "Linux · 자동 입력 · 정상 1배속"
 game.refresh()
 cursor = ReviewCursor.new(); cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
 cursor.z_index = 100; cursor.hide(); game.hud.add_child(cursor)
 var first_frame := Engine.get_process_frames()
 var duration: int = {"building":27,"progress":34,"application":55}[segment]
 var done := {}; var trace: Array = []; var last := ""
 var ct_entry := -1.0; var ct_duration := 0.0; var ct_actual := 0.0; var previous := ""
 var restore_ok := false; var stamp := false
 game.set_process(true)
 while Engine.get_process_frames()-first_frame < duration*24:
  var seconds := float(Engine.get_process_frames()-first_frame)/24.0
  var p: Dictionary = game.sim.get_patient(1)
  if segment == "application" and not done.has("jump"):
   if p.state == "ct_scan" and ct_entry < 0:
    ct_entry = game.sim.time; ct_duration = game.sim.service_duration(p)
   if previous == "ct_scan" and p.state != "ct_scan" and ct_entry >= 0: ct_actual = game.sim.time-ct_entry
  previous = p.state
  stamp = stamp or (game.journal.visible and game.journal.chapter_stamp.text.contains("4장"))
  var state := {"seconds":seconds,"day":game.sim.day,"time":game.sim.time,"money":game.sim.money,"research":game.sim.research.snapshot(),"states":game.sim.patients.map(func(patient): return [patient.id,patient.state,patient.service_duration]),"journal":game.journal.visible}
  var key := str([state.day,state.money,state.research,state.states,state.journal])
  if key != last: trace.append(state); last = key
  if segment == "building":
   if seconds >= 3 and not done.has("site"):
    var point: Vector2 = game.world.camera.unproject_position(game.world.LAB_POSITION)*game.size/Vector2(game.viewport.size)
    await click_at(point); done.site = true
   elif seconds >= 6 and not done.has("offer"):
    await reveal(game.research_panel.build_button); await click(game.research_panel.build_button); done.offer = true
   elif seconds >= 11 and not done.has("build"):
    await click(game.research_panel.confirmation.ok_button); done.build = true
   elif seconds >= 15 and not done.has("view"):
    await click(game.research_panel.close_button); done.view = true
   elif seconds >= 20 and not done.has("minji"):
    await click(game.story_next); done.minji = true
   elif seconds >= 24 and not done.has("read"):
    await click(game.story_next); done.read = true
  elif segment == "progress":
   if seconds >= 2 and not done.has("open"): await click(game.expansion_button); done.open = true
   elif seconds >= 4 and not done.has("offer"):
    await reveal(game.research_panel.project_buttons.ct); await click(game.research_panel.project_buttons.ct); done.offer = true
   elif seconds >= 9 and not done.has("start"):
    await click(game.research_panel.confirmation.ok_button); done.start = true
   elif seconds >= 16 and not done.has("jump"):
    use_checkpoint("day_six_close",seconds); done.jump = true
   elif seconds >= 25 and game.journal.visible and not done.has("scroll"):
    game.journal.financial_scroll.scroll_vertical = 390; done.scroll = true
  else:
   if seconds >= 4 and not done.has("next"):
    await click(game.journal.next_button)
    if game.capacity_dialog.visible: await click(game.capacity_dialog.start_button)
    done.next = true
   elif seconds >= 8 and not done.has("read"):
    await click(game.story_next); done.read = true
   elif seconds >= 10 and not done.has("patient"):
    await select_patient(1); done.patient = true
   elif seconds >= 28 and not done.has("save"):
    await click(game.pause_button)
    game.store.path = "user://research-video-isolated.json"
    var before: Dictionary = game.sim.snapshot()
    assert(game.store.save(game.sim,game.story))
    restore_ok = game.store.load_into(game.sim,game.story) and JSON.stringify(game.sim.snapshot()) == JSON.stringify(before)
    game.user_paused = true
    game.show_notice("저장 복원 ✓ · CT 4초 적용 유지\n연구비·점수 중복 처리 없음")
    game.refresh(); done.save = true
   elif seconds >= 33 and not done.has("goal"):
    await click(game.dismiss_button); await click(game.goal_ribbon); done.goal = true
   elif seconds >= 40 and not done.has("jump"):
    use_checkpoint("day_seven_close",seconds); done.jump = true
   elif seconds >= 48 and game.journal.visible and not done.has("scroll"):
    game.journal.financial_scroll.scroll_vertical = 390; done.scroll = true
  await process_frame
 game.set_process(false)
 var ok: bool = game.playback_speed == 1.0
 if segment == "building": ok = ok and done.has("read") and game.sim.research.built_day == 5 and game.sim.money == 1200 and game.sim.research.points == 6 and game.world.lab_model.visible and game.world.researcher.visible
 elif segment == "progress": ok = ok and done.has("start") and done.has("jump") and game.sim.research.projects.ct.completed_day == 6 and not game.sim.research.applied("ct") and game.sim.money == 2300 and game.sim.research.points == 8
 else: ok = ok and restore_ok and stamp and game.sim.research.chapter_four_day == 7 and game.sim.research.applied("ct") and ct_duration == 4 and absf(ct_actual-4) < .1
 var result := {"passed":ok,"segment":segment,"automatic_input":true,"platform":"Linux Godot 4.6.3 OpenGL llvmpipe","physical_mobile":false,"simulation_speed":1,"fps":24,"recorded_frames":Engine.get_process_frames()-first_frame,"real_canvas_clicks":click_count,"checkpoint_prepared_by_normal_simulation":true,"checkpoint_switches":checkpoint_switches,"continuous_single_day":segment == "building","trace":trace,"ct_latched_duration":ct_duration,"ct_observed_seconds":ct_actual,"real_file_restored":restore_ok,"chapter_four_journal_stamp":stamp}
 FileAccess.open(output.path_join("movie-results.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("RESEARCH MOVIE: ",segment," passed=",ok," CT=",ct_actual," restore=",restore_ok)
 quit(0 if ok else 1)
