extends "res://tests/record_normal.gd"
const Fixture = preload("res://tests/staff_fixture.gd")
var segment := "offer"

func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
  if arg.begins_with("--segment="): segment = arg.trim_prefix("--segment=")
 root.size = Vector2i(1280,720)
 game = load("res://main.tscn").instantiate()
 root.add_child(game); game.set_process(false)
 await process_frame
 var checkpoint: HospitalSimulation = Fixture.day_two(true)
 if segment != "offer":
  checkpoint.set_admission_delegated(true)
  checkpoint.tick(24 if segment == "flow" else 8)
 game.sim.restore(checkpoint.snapshot()); game.sim.paused = false; game.user_paused = false
 game.story.enabled = true
 for actor in game.world.actors.values(): actor.free()
 game.world.actors.clear()
 game.refresh(); game.world.show_overview()
 while game.world.transition_active: await process_frame
 game.recording_caption = "Linux · 자동 입력 · 정상 1배속"
 cursor = ReviewCursor.new(); cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
 cursor.z_index = 100; cursor.hide(); game.hud.add_child(cursor)
 FileAccess.open(output.path_join("checkpoint.json"),FileAccess.WRITE).store_string(JSON.stringify(game.sim.snapshot(),"  "))
 var first_frame := Engine.get_process_frames()
 var duration: int = {"offer":24,"flow":45,"restore":24}[segment]
 var done := {}
 var trace: Array = []
 var last := ""
 var dual := false
 var queued := false
 var restore_ok := false
 var manual_ok := false
 var auto_ids: Array[int] = []
 game.sim.admitted.connect(func(id: int): auto_ids.append(id))
 game.set_process(true)
 while Engine.get_process_frames()-first_frame < duration*24:
  var seconds := float(Engine.get_process_frames()-first_frame)/24.0
  dual = dual or game.sim.count_state("treatment") == 2
  queued = queued or game.sim.count_state("ct_queue") > 0
  var states: Array = []
  for p in game.sim.patients: states.append(p.state)
  var key := str(states)+str(game.sim.admission.enabled)+str(game.sim.paused)
  if key != last:
   trace.append({"seconds":seconds,"states":states,"delegated":game.sim.admission.enabled,"selected":game.selected_id,"paused":game.sim.paused,"money":game.sim.money})
   last = key
  if segment == "offer":
   if seconds >= 4 and not done.has("accept"):
    await click(game.admission_accept); done.accept = true
   elif seconds >= 9 and not done.has("first"):
    await select_patient(1); done.first = true
   elif seconds >= 16 and not done.has("second"):
    await select_patient(2); done.second = true
  elif segment == "flow":
   if seconds >= 1 and not done.has("queue"):
    await select_patient(3); done.queue = true
   elif seconds >= 5 and not done.has("first"):
    await select_patient(1); done.first = true
   elif seconds >= 7 and not done.has("plan1"):
    await click(game.action_button); plans += 1; done.plan1 = true
   elif seconds >= 13 and not done.has("second") and game.sim.get_patient(2).state == "plan_ready":
    await select_patient(2); done.second = true
   elif seconds >= 15 and done.has("second") and not done.has("plan2"):
    await click(game.action_button); plans += 1; done.plan2 = true
   elif seconds >= 24 and not done.has("overview"):
    await click(game.dismiss_button); await click(game.overview_button); done.overview = true
  else:
   if seconds >= 1 and not done.has("settings"):
    await click(game.guide_settings); done.settings = true
   elif seconds >= 3 and not done.has("off"):
    await click(game.admission_toggle); done.off = true
   elif seconds >= 5 and not done.has("close"):
    await click(game.guide_close); done.close = true
   elif seconds >= 7 and not done.has("select"):
    await select_patient(2); done.select = true
   elif seconds >= 9 and not done.has("manual"):
    await click(game.action_button); done.manual = true
    manual_ok = game.sim.get_patient(2).history.count("ct_queue") == 1 and not game.sim.admission.enabled
   elif seconds >= 13 and not done.has("save"):
    await click(game.pause_button)
    game.store.path = "user://staff-video-isolated.json"
    game.store.save(game.sim,game.story); done.save = true
    game.show_notice("테스트 저장 완료 · 접수는 직접\n3초 뒤 같은 파일을 다시 불러옵니다.")
   elif seconds >= 16 and not done.has("restore"):
    var before: Dictionary = game.sim.snapshot()
    restore_ok = game.store.load_into(game.sim,game.story) and JSON.stringify(game.sim.snapshot()) == JSON.stringify(before) and game.sim.paused and not game.sim.admission.enabled
    if not restore_ok: printerr("FAIL: restore ",game.store.message," before=",JSON.stringify(before)," after=",JSON.stringify(game.sim.snapshot()))
    game.user_paused = game.sim.paused
    game.show_notice("테스트 저장 복원 · 접수: 직접\n재생을 눌러 이어가요.")
    game.refresh(); done.restore = true
   elif seconds >= 20 and not done.has("resume"):
    await click(game.pause_button); done.resume = true
  await process_frame
 game.set_process(false)
 var ok: bool = game.playback_speed == 1.0 and game.sim.ledger.expansion_expense == 0 and game.sim.money == 1100
 if segment == "offer": ok = ok and done.has("accept") and game.sim.admission.enabled and auto_ids.size() >= 3 and queued
 elif segment == "flow": ok = ok and plans == 2 and dual and queued
 else: ok = ok and restore_ok and manual_ok and not game.sim.admission.enabled and not game.sim.paused and game.sim.get_patient(3).state == "waiting"
 var result := {"passed":ok,"segment":segment,"automatic_input":true,"platform":"Linux Godot 4.6.3 OpenGL llvmpipe","physical_mobile":false,"simulation_speed":1,"fps":24,"recorded_frames":Engine.get_process_frames()-first_frame,"real_canvas_clicks":click_count,"admission_events":auto_ids,"manual_plan_commands":plans,"ct_queue_shown":queued,"two_rooms_treating":dual,"manual_admission":manual_ok,"real_file_restored":restore_ok,"reload_trigger":"QA invokes actual SaveStore.load_into; process restart tested separately","checkpoint_prepared_by_normal_simulation":true,"trace":trace}
 FileAccess.open(output.path_join("movie-results.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("STAFF MOVIE: ",JSON.stringify(result))
 quit(0 if ok else 1)
