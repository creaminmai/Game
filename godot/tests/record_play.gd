extends SceneTree
# Engine Movie Maker records the same interactive game; this driver sends real UI input.
var game: Control
var output := ""
var simulation_speed := 4
var hold_scale := 1.0

func hold(seconds: float) -> void:
 for frame in range(int(seconds*24*hold_scale)):
  await process_frame

func click(control: Control) -> void:
 var window_id := control.get_window().get_window_id()
 var point := control.get_global_rect().get_center()
 point *= Vector2(root.size)/root.get_visible_rect().size
 if control.get_window() != root and control.get_window().is_embedded():
  point += Vector2(control.get_window().position)
 var motion := InputEventMouseMotion.new()
 motion.position = point
 motion.window_id = window_id
 Input.parse_input_event(motion)
 for pressed in [true,false]:
  var event := InputEventMouseButton.new()
  event.window_id = window_id
  event.button_index = MOUSE_BUTTON_LEFT
  event.position = point
  event.pressed = pressed
  Input.parse_input_event(event)
  await process_frame
 await process_frame

func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
  if arg == "--brief":
   simulation_speed = 6
   hold_scale = 0.5
 if output.is_empty(): quit(1); return
 root.size = Vector2i(1280,720)
 game = load("res://main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.set_process(false)
 game.recording_caption = "자동 입력 시연 · 진료 %d배속" % simulation_speed
 game.refresh()
 await hold(1)
 if "--input-check" in OS.get_cmdline_user_args():
  game.sim.tick(24)
  game.sim.lifetime_completed = 1
  game.refresh()
  await hold(0.2)
  await click(game.patient_button)
  await click(game.rows[0])
  await click(game.action_button)
  print("INPUT CHECK admission: ",game.sim.get_patient(1).state)
  await click(game.outside_button)
  await click(game.expansion_button)
  print("DIALOG: visible=",game.confirmation.visible," card=",game.confirmation.card.get_global_rect()," button=",game.confirmation.get_ok_button().get_global_rect())
  await click(game.confirmation.get_ok_button())
  print("INPUT CHECK purchase: ",game.sim.expanded)
  await click(game.outside_button)
  var passed: bool = game.sim.expanded and not game.outside and game.sim.get_patient(1).state != "waiting"
  print("INPUT CHECK passed: ",passed)
  quit(0 if passed else 1)
  return
 var bought := false
 var shown_dual := false
 for frame in range(4800):
  game.sim.tick(float(simulation_speed)/24.0)
  game.world.sync(game.sim,game.selected_id,1.0/24.0)
  game.refresh()
  game.scene_caption.text = "자동 플레이 시연 · 진료 %d배속" % simulation_speed
  for p in game.sim.patients:
   if game.sim.needs_action(p):
    await click(game.patient_button)
    await click(game.rows[p.id-1])
    await hold(0.4)
    await click(game.action_button)
    if game.sim.needs_action(p):
     printerr("ERROR: movie admission or plan click failed")
     quit(1)
     return
    await hold(0.3)
  if game.sim.completed() > 0 and not bought:
   await click(game.outside_button)
   await hold(1.5)
   await click(game.expansion_button)
   await hold(1.5)
   await click(game.confirmation.get_ok_button())
   await hold(2)
   await click(game.outside_button)
   bought = game.sim.expanded
   if not bought or game.outside:
    printerr("ERROR: movie purchase or return input failed")
    quit(1)
    return
  if game.sim.count_state("treatment") == 2 and not shown_dual:
   await click(game.dismiss_button)
   await click(game.overview_button)
   await hold(2)
   shown_dual = true
  if game.sim.all_done(): break
  await process_frame
 var result := {"passed":game.sim.all_done() and game.sim.money == 1100 and game.sim.max_treating == 2,
  "completed":game.sim.completed(),"money":game.sim.money,"max_treating":game.sim.max_treating,
  "expanded":game.sim.expanded,"fps":24,"simulation_speed":simulation_speed,"automatic_input":true,"mobile_performance_test":false}
 await hold(2)
 await click(game.next_day_button)
 result["next_day"] = game.sim.day
 result["passed"] = result.passed and game.sim.day == 2
 await hold(2)
 var file := FileAccess.open(output.path_join("movie-results.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(result,"  ")); file.close()
 print("MOVIE: ",JSON.stringify(result))
 quit(0 if result.passed else 1)

func _initialize() -> void:
 run.call_deferred()
