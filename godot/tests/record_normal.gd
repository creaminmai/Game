extends SceneTree
# 54 seconds of the real running game at 1x. Only input is automated.
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
 cursor.position = point
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
 var plan_due := {}
 var seen := {}
 while Engine.get_process_frames()-first_frame < 54*24:
  var elapsed: float = game.sim.time-start_time
  for p in game.sim.patients: seen[p.state] = true
  if elapsed >= 7 and not done.has("select1"):
   await select_patient(1,true); done.select1 = true
  elif elapsed >= 9 and not done.has("admit1"):
   await click(game.action_button); admitted += 1; done.admit1 = true
  elif elapsed >= 12 and not done.has("select2"):
   await select_patient(2); done.select2 = true
  elif elapsed >= 14 and not done.has("admit2"):
   await click(game.action_button); admitted += 1; done.admit2 = true
  elif elapsed >= 20 and not done.has("ct"):
   await select_patient(1); done.ct = true
  elif elapsed >= 44 and not done.has("treat"):
   await click(game.overview_button)
   await process_frame
   await select_patient(1,true); done.treat = true
  elif elapsed >= 49 and not done.has("queue"):
   await select_patient(2); done.queue = true
  for id in [1,2]:
   var p: Dictionary = game.sim.get_patient(id)
   if not p.is_empty() and p.state == "plan_ready":
    if not plan_due.has(id):
     await select_patient(id)
     plan_due[id] = elapsed+1.5
    elif elapsed >= plan_due[id]:
     if game.selected_id != id: await select_patient(id)
     await click(game.action_button)
     plans += 1
  await process_frame
 game.set_process(false)
 var simulated: float = game.sim.time-start_time
 var frames := Engine.get_process_frames()-first_frame
 var result := {"passed":admitted == 2 and plans == 2 and selected_by_ray == 2 and seen.has("ct_scan") and seen.has("treatment") and seen.has("treatment_queue") and absf(simulated-float(frames)/24.0) < .1,
  "automatic_input":true,"simulation_speed":1,"recorded_frames":frames,"simulation_seconds":simulated,
  "admissions":admitted,"plan_instructions":plans,"real_canvas_clicks":click_count,"selected_by_ray":selected_by_ray,
  "observed_states":seen.keys(),"mobile_performance_test":false,"fps":24}
 FileAccess.open(output.path_join("movie-results.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("MOVIE NORMAL: ",JSON.stringify(result))
 quit(0 if result.passed else 1)

func _initialize() -> void:
 run.call_deferred()
