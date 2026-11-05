extends "res://tests/record_normal.gd"
# Each clip runs continuously at 1x from an ordinary simulation checkpoint.
# The checkpoint is prepared through the same public actions/time progression,
# never by changing patient states, payment flags or equipment owners.
var segment := "admission"
func prepare_checkpoint() -> void:
 game.sim = HospitalSimulation.new()
 if segment == "admission": game.sim.tick(6.0); return
 for step in range(150*60):
  for p in game.sim.patients:
   if segment == "therapy" and p.id != 1: continue
   if p.state == "waiting": game.sim.admit(p.id)
   elif p.state == "plan_ready": game.sim.assign_plan(p.id)
  if segment == "dual" and game.sim.completed()>0 and not game.sim.expanded: game.sim.purchase_expansion()
  game.sim.tick(1.0/60)
  if segment == "therapy":
   var p: Dictionary = game.sim.get_patient(1)
   if p.state == "walk_treatment" and p.route.size() == 1 and p.position.distance_to(CharacterMotion.bed_position(p)) < 1.7: return
  else:
   for p in game.sim.patients:
    if p.state == "walk_treatment" and p.room == 1 and p.position.distance_to(CharacterMotion.bed_position(p)) < 2.1 and game.sim.count_state("treatment") == 1: return
 printerr("ERROR: motion checkpoint could not be reached"); quit(1)

func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
  if arg.begins_with("--segment="): segment = arg.trim_prefix("--segment=")
 root.size = Vector2i(1280,720)
 game = load("res://main.tscn").instantiate()
 root.add_child(game)
 game.set_process(false)
 await process_frame
 prepare_checkpoint()
 for actor in game.world.actors.values(): actor.free()
 game.world.actors.clear()
 game.sim.changed.connect(game.on_change)
 game.refresh()
 game.world.show_overview()
 while game.world.transition_active: await process_frame
 game.recording_caption = "자동 입력 · 정상 1배속 · "+{"admission":"접수·CT","therapy":"치료·귀가","dual":"두 치료실"}[segment]
 cursor = ReviewCursor.new()
 cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
 cursor.z_index = 100; cursor.hide(); game.hud.add_child(cursor)
 var start_time: float = game.sim.time
 var initial: Dictionary = game.sim.snapshot()
 FileAccess.open(output.path_join("checkpoint.json"),FileAccess.WRITE).store_string(JSON.stringify(initial,"  "))
 var duration := {"admission":24,"therapy":37,"dual":13}[segment] as int
 var first_frame := Engine.get_process_frames()
 var seen := {}
 var phases := {}
 var trace: Array = []
 var last := ""
 var done := {}
 var max_shift := 0.0
 var max_zoom := 0.0
 var center: Vector3 = game.world.view_center
 var zoom: float = game.world.camera.size
 var minji_reactions: int = game.world.staff_models[0].staff_event_count
 var dual_seen := false
 game.set_process(true)
 while Engine.get_process_frames()-first_frame < duration*24:
  var elapsed: float = game.sim.time-start_time
  var p: Dictionary = game.sim.get_patient(1)
  if segment == "admission":
   if elapsed >= 1 and not done.has("select"):
    await select_patient(1,true); done.select = true
   elif elapsed >= 2 and not done.has("admit"):
    await click(game.action_button); admitted += 1; done.admit = true
   elif p.state == "plan_ready" and not done.has("plan"):
    await click(game.action_button); plans += 1; done.plan = true
  elif segment == "therapy" and elapsed >= .2 and not done.has("select"):
   await select_patient(1); done.select = true
  if segment == "dual":
   dual_seen = dual_seen or game.sim.count_state("treatment") == 2
   for other in game.sim.patients:
    if other.room == 1: p = other
  seen[p.state] = true
  var actor: HospitalActor = game.world.actors[p.id]
  phases[p.state+":"+actor.pose_phase] = true
  var key: String = p.state+":"+actor.pose_phase
  if key != last:
   trace.append({"seconds":elapsed,"patient":p.id,"state":p.state,"pose":actor.pose_phase})
   last = key
  max_shift = maxf(max_shift,center.distance_to(game.world.view_center))
  max_zoom = maxf(max_zoom,absf(zoom-game.world.camera.size))
  await process_frame
 game.set_process(false)
 var frames := Engine.get_process_frames()-first_frame
 var simulated: float = game.sim.time-start_time
 var normal := absf(simulated-float(frames)/24.0)<.1
 var ok := normal and max_zoom < .001 and max_shift < .01
 if segment == "admission": ok = ok and admitted == 1 and plans == 1 and phases.has("ct_scan:lie_down") and phases.has("ct_scan:rise") and game.world.staff_models[0].staff_event_count > minji_reactions
 elif segment == "therapy": ok = ok and phases.has("treatment:lie_down") and phases.has("treatment:rise") and seen.has("leaving") and game.sim.get_patient(1).paid and game.sim.money == initial.money+200
 else: ok = ok and dual_seen and phases.has("treatment:lie_down") and phases.has("treatment:service")
 var result := {"passed":ok,"segment":segment,"automatic_input":true,"checkpoint_prepared_by_normal_simulation":true,"simulation_speed":1,"simulation_seconds":simulated,"recorded_frames":frames,"fps":24,"real_canvas_clicks":click_count,"max_camera_shift":max_shift,"max_zoom_delta":max_zoom,"trace":trace,"simultaneous_treatment":dual_seen,"money":game.sim.money,"mobile_performance_test":false}
 FileAccess.open(output.path_join("movie-results.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("MOVIE MOTION: ",JSON.stringify(result))
 quit(0 if ok else 1)
