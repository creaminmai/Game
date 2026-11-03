extends SceneTree
var game: Control
var checks := 0
var failures: Array[String] = []
var output := ""
var selected_by_input := 0

func check(condition: bool, caption: String) -> void:
 checks += 1
 if not condition:
  failures.append(caption)
  printerr("FAIL: ",caption)

func settle() -> void:
 await process_frame
 await process_frame

func click(control: Control) -> void:
 var point := control.get_global_rect().get_center()
 point *= Vector2(root.size)/root.get_visible_rect().size
 var move := InputEventMouseMotion.new()
 move.position = point
 Input.parse_input_event(move)
 var down := InputEventMouseButton.new()
 down.button_index = MOUSE_BUTTON_LEFT
 down.pressed = true
 down.position = point
 Input.parse_input_event(down)
 await process_frame
 down = InputEventMouseButton.new()
 down.button_index = MOUSE_BUTTON_LEFT
 down.position = point
 down.pressed = false
 Input.parse_input_event(down)
 await settle()

func shot(name_text: String) -> void:
 await RenderingServer.frame_post_draw
 var image := root.get_texture().get_image()
 check(image.save_png(output.path_join(name_text+".png")) == OK,"capture " + name_text)

func check_layout(caption: String) -> void:
 var screen := Rect2(Vector2.ZERO,root.get_visible_rect().size)
 var good := true
 var controls: Array[Control] = []
 for row in game.rows: controls.append(row)
 controls.append_array([game.pause_button,game.outside_button,game.expansion_button,game.action_button,game.next_button,game.notice,
  game.patient_button,game.zoom_in_button,game.zoom_out_button,game.overview_button,game.selection_panel,game.detail,game.dismiss_button,
  game.money_panel,game.goal,game.next_day_button,game.roster_close])
 for control in controls:
  if control.is_visible_in_tree() and not screen.encloses(control.get_global_rect()):
   printerr("Outside viewport: ",control.name," ",control.get_global_rect()," screen ",screen)
   good = false
 check(good,caption + " controls fit viewport")
 check(game.scene_container.get_global_rect() == screen,caption + " 3D fills the whole viewport")
 check(absf(screen.size.aspect()-Vector2(root.size).aspect()) < 0.01,caption + " viewport expands without letterboxing")

func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
 if output.is_empty(): output = ProjectSettings.globalize_path("res://../artifacts/validation")
 DirAccess.make_dir_recursive_absolute(output)
 root.size = Vector2i(720,1280)
 game = load("res://main.tscn").instantiate()
 root.add_child(game)
 await settle()
 game.set_process(false)
 check(game.no_save,"QA never reads or writes user save")
 check(game.rows.size() == 4 and game.rows[1].disabled,"future arrivals visible but not selectable")
 check(not game.roster.visible and not game.selection_panel.visible,"HUD starts without list or patient card")
 await click(game.patient_button)
 check(game.roster.visible,"patient roster opens on request")
 await click(game.rows[2])
 check(game.selected_id == -1,"future arrival click preserves selection")
 await click(game.roster_close)
 game.sim.tick(24)
 game.refresh()
 await settle()
 check_layout("720x1280")
 await shot("01-fullscreen-game")
 var initial_zoom: float = game.world.camera.size
 await click(game.zoom_in_button)
 check(game.world.camera.size < initial_zoom,"zoom button enlarges actual 3D")
 await click(game.overview_button)
 check(game.world.overview_mode,"overview returns to full hospital")
 await click(game.patient_button)
 await shot("02-patient-roster")
 await click(game.rows[2])
 check(game.selected_id == 3,"patient list selection via real input")
 check(not game.roster.visible and game.selection_panel.visible,"selection closes roster and shows contextual action")
 selected_by_input += 1
 game.sim.tick(0.5); game.refresh()
 check(game.selected_id == 3,"refresh never steals selection")
 await click(game.action_button)
 check(game.sim.ct_owner == 3,"selected patient admitted via real input")
 await click(game.next_button)
 check(game.selected_id == 4,"explicit helper cycles patients needing action")
 await click(game.action_button)
 check(game.sim.queue_rank(4) == 1 and game.rows[3].text.contains("1번째"),"queue ordinal displayed after input")
 await shot("02-ct-queue")
 # Clicking actual patient geometry uses the same viewport ray query as mouse/touch input.
 var actor: Node3D = game.world.actors[1]
 var local: Vector2 = game.world.camera.unproject_position(actor.position+Vector3(0,0.8,0))
 var event := InputEventMouseButton.new()
 event.button_index = MOUSE_BUTTON_LEFT
 event.pressed = true
 event.position = game.scene_container.global_position+local
 Input.parse_input_event(event)
 await settle()
 event = InputEventMouseButton.new()
 event.button_index = MOUSE_BUTTON_LEFT
 event.position = game.scene_container.global_position+local
 Input.parse_input_event(event)
 await settle()
 check(game.selected_id == 1,"3D patient selection via real input ray")
 # Dragging moves the camera, without treating the gesture as a patient tap.
 var old_center: Vector3 = game.world.view_center
 var old_selection: int = game.selected_id
 var press := InputEventMouseButton.new()
 press.button_index = MOUSE_BUTTON_LEFT
 press.pressed = true
 press.position = Vector2(200,500)
 Input.parse_input_event(press)
 await settle()
 var drag := InputEventMouseMotion.new()
 drag.position = Vector2(270,530)
 drag.relative = Vector2(70,30)
 drag.button_mask = MOUSE_BUTTON_MASK_LEFT
 Input.parse_input_event(drag)
 await settle()
 press = InputEventMouseButton.new()
 press.button_index = MOUSE_BUTTON_LEFT
 press.position = Vector2(270,530)
 Input.parse_input_event(press)
 await settle()
 check(game.world.view_center != old_center and game.selected_id == old_selection,"world drag pans without selecting")
 await click(game.pause_button)
 var frozen: Dictionary = game.sim.snapshot()
 game.sim.tick(3)
 check(game.sim.snapshot() == frozen,"pause button stops simulation")
 await click(game.outside_button)
 check(game.outside and game.sim.paused,"outside pauses treatment")
 await click(game.outside_button)
 check(game.sim.paused,"return preserves previous paused state")
 await click(game.pause_button)
 await click(game.outside_button)
 await click(game.outside_button)
 check(not game.sim.paused,"return restores running state")
 var expanded := false
 var dual_seen := false
 var restore_checked := false
 for iteration in range(600):
  for p in game.sim.patients:
   if game.sim.needs_action(p):
    await click(game.patient_button)
    await click(game.rows[p.id-1])
    selected_by_input += 1
    await click(game.action_button)
  game.sim.tick(0.5)
  game.refresh()
  if game.sim.completed() > 0 and not expanded:
   await click(game.outside_button)
   var money: int = game.sim.money
   await click(game.expansion_button)
   check(game.confirmation.visible,"purchase dialog opens via input")
   await click(game.confirmation.get_cancel_button())
   check(game.sim.money == money and not game.sim.expanded,"cancel costs nothing")
   await click(game.expansion_button)
   await shot("03-expansion-confirmation")
   await click(game.confirmation.get_ok_button())
   check(game.sim.expanded and game.sim.money == money-600,"confirm button buys actual annex")
   check(game.world.wing_built and game.world.beams.size() == 2,"annex creates second physical device")
   await shot("04-exterior-expanded")
   await click(game.outside_button)
   expanded = true
  if game.sim.count_state("treatment") == 2 and not dual_seen:
   await click(game.dismiss_button)
   await click(game.overview_button)
   await settle()
   await shot("05-two-treatments")
   dual_seen = true
   var copy = load("res://scripts/hospital_simulation.gd").new()
   restore_checked = copy.restore(game.sim.snapshot()) and copy.paused
  if game.sim.all_done(): break
 check(game.sim.all_done() and game.sim.completed() == 4,"four patients complete and leave")
 check(game.sim.money == 1100 and expanded,"day one economy after annex")
 check(dual_seen and restore_checked,"concurrent treatment captured and restorable")
 check(game.next_day_button.visible,"next-day button appears after departure")
 await shot("06-day-complete")
 await click(game.next_day_button)
 check(game.sim.day == 2 and game.sim.patients.size() == 1,"next day through real input")
 game.refresh(); await settle()
 check(game.world.actors.size() == 1,"previous day actors removed")
 for dimensions in [Vector2i(360,640),Vector2i(720,1560),Vector2i(720,1080),Vector2i(1280,800)]:
  root.size = dimensions
  await settle()
  game.refresh()
  await settle()
  check_layout(str(dimensions))
  game.select_patient(1)
  await settle()
  check_layout(str(dimensions)+" patient action")
  await click(game.patient_button)
  check(game.roster.visible,str(dimensions)+" roster opens after resize")
  check_layout(str(dimensions)+" roster")
  await click(game.roster_close)
  await click(game.dismiss_button)
  check(not game.selection_panel.visible,str(dimensions)+" patient action closes after resize")
  await shot("layout-%dx%d" % [dimensions.x,dimensions.y])
 var report := {"checks": checks,"failures": failures,"passed": failures.is_empty(),"selected_by_real_input": selected_by_input,
  "completed":4,"money_after_day_one":1100,"dual_treatment_captured":dual_seen,"android_ios_tested":false,
  "note":"Desktop Godot automatic input QA, not manual playtest or mobile performance measurement."}
 var file := FileAccess.open(output.path_join("results.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  ")); file.close()
 print("SCENE: %d checks, %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
 run.call_deferred()
