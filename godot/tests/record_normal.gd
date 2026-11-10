extends SceneTree
# 54 seconds of the real running game at 1x. Only input is automated.
# One patient remains selected from admission through CT, planning and treatment.
# No simulation jumps, accelerated tick loop, state edits or hidden cuts.
var game: Control
var output := ""
var admitted := 0
var plans := 0
var selected_by_ray := 0
var click_count := 0
var cursor: Control

class ReviewCursor extends Control:
 var pressed := false
 func _draw() -> void:
  if pressed: draw_circle(Vector2.ZERO,15,Color(1,.73,.25,.7))
  var points := PackedVector2Array([Vector2(0,0),Vector2(2,18),Vector2(7,13),Vector2(12,21),Vector2(16,18),Vector2(11,11),Vector2(18,10)])
  draw_colored_polygon(points,Color("fffdf4"))
  points.append(points[0])
  draw_polyline(points,Color("654d35"),1.5,true)

func click_at(point: Vector2) -> void:
 cursor.position = point-game.hud.position
 cursor.show()
 var pixels := point*Vector2(root.size)/root.get_visible_rect().size
 var motion := InputEventMouseMotion.new()
 motion.position = pixels
 Input.parse_input_event(motion)
 for pressed in [true,false]:
  cursor.pressed = pressed
  cursor.queue_redraw()
  var event := InputEventMouseButton.new()
  event.button_index = MOUSE_BUTTON_LEFT
  event.position = pixels
  event.pressed = pressed
  Input.parse_input_event(event)
  await process_frame
  await process_frame
 click_count += 1

func click(control: Control) -> void:
 await click_at(control.get_global_rect().get_center())

func select_patient(id: int, ray: bool = false) -> void:
 if ray:
  var actor = game.world.actors[id]
  var pixel: Vector2 = game.world.camera.unproject_position(actor.head.to_global(Vector3(0,.065,.34)))
  await click_at(pixel*game.size/Vector2(game.viewport.size))
  selected_by_ray += 1
 else:
  await click(game.patient_button)
  game.roster_scroll.ensure_control_visible(game.rows[id-1])
  for n in range(3): await process_frame
  await click(game.rows[id-1])
 if game.selected_id != id:
  printerr("ERROR: normal-speed patient selection failed")
  quit(1)

func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
 if output.is_empty(): quit(1); return
 root.size = Vector2i(1280,720)
 game = load("res://main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.recording_caption = "자동 입력 시연 · 정상 1배속"
 cursor = ReviewCursor.new()
 cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
 cursor.z_index = 100
 cursor.hide()
 game.hud.add_child(cursor)
 var first_frame := Engine.get_process_frames()
 var start_time: float = game.sim.time
 var done := {}
 var plan_due := -1.0
 var seen := {}
 var trace: Array = []
 var last_state := ""
 var stable_center := Vector3.ZERO
 var stable_size := 0.0
 var max_shift := 0.0
 var max_zoom_delta := 0.0
 var detail_requested := false
 var overview_restored := false
 while Engine.get_process_frames()-first_frame < 54*24:
  var elapsed: float = game.sim.time-start_time
  var p: Dictionary = game.sim.get_patient(1)
  if not p.is_empty(): seen[p.state] = true
  if elapsed >= 7 and not done.has("select1"):
   await select_patient(1,true); done.select1 = true
  elif elapsed >= 9 and not done.has("admit1"):
   await click(game.action_button); admitted += 1; done.admit1 = true
  elif elapsed >= 44 and not done.has("detail"):
   await click(game.patient_view_button); done.detail = true
  elif elapsed >= 49 and not done.has("overview"):
   await click(game.overview_button); done.overview = true
  if not p.is_empty() and p.state == "plan_ready":
   if plan_due < 0: plan_due = elapsed+1.5
   elif elapsed >= plan_due:
    await click(game.action_button)
    plans += 1
  if elapsed >= 10 and elapsed < 44:
   if stable_size == 0:
    stable_center = game.world.view_center
    stable_size = game.world.camera.size
   max_shift = maxf(max_shift,stable_center.distance_to(game.world.view_center))
   max_zoom_delta = maxf(max_zoom_delta,absf(stable_size-game.world.camera.size))
   if p.state != last_state:
    var center: Vector3 = game.world.view_center
    trace.append({"time":elapsed,"patient_id":1,"state":p.state,"camera_center":[center.x,center.y,center.z],"camera_size":game.world.camera.size})
    last_state = p.state
  if elapsed >= 46 and elapsed < 49:
   detail_requested = game.world.camera.size < stable_size*.85
  if elapsed >= 50:
   overview_restored = absf(game.world.camera.size-stable_size) < .01 and game.world.view_center.distance_to(stable_center) < .01
  await process_frame
 game.set_process(false)
 var simulated: float = game.sim.time-start_time
 var frames := Engine.get_process_frames()-first_frame
 var stable := max_shift < .01 and max_zoom_delta < .001
 var result := {"passed":admitted == 1 and plans == 1 and selected_by_ray == 1 and seen.has("ct_scan") and seen.has("planning") and seen.has("treatment") and stable and detail_requested and overview_restored and absf(simulated-float(frames)/24.0) < .1,
  "automatic_input":true,"simulation_speed":1,"recorded_frames":frames,"simulation_seconds":simulated,
  "admissions":admitted,"plan_instructions":plans,"real_canvas_clicks":click_count,"selected_by_ray":selected_by_ray,
  "followed_patient_id":1,"stable_camera_until_seconds":44,"max_camera_shift":max_shift,"max_zoom_delta":max_zoom_delta,"stage_camera_trace":trace,
  "explicit_detail_view":detail_requested,"overview_restored":overview_restored,
  "observed_states":seen.keys(),"mobile_performance_test":false,"fps":24}
 FileAccess.open(output.path_join("movie-results.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("MOVIE NORMAL: ",JSON.stringify(result))
 quit(0 if result.passed else 1)

func _initialize() -> void:
 run.call_deferred()
