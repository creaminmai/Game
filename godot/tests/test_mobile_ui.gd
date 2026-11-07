extends "res://tests/test_story_ui.gd"
# Native Linux renderer + injected screen insets, not a physical phone test.
func mobile_layout(caption: String) -> void:
 check_layout(caption)
 var screen: Rect2 = game.safe_ui
 var scale_to_pixels := Vector2(root.size)/root.get_visible_rect().size
 var controls: Array = [game.story_panel,game.guide_panel,game.selection_panel,game.roster,game.journal.card,game.confirmation.card]
 controls.append_array([game.pause_button,game.speed_button,game.outside_button,game.patient_button,game.zoom_in_button,game.zoom_out_button,game.dismiss_button,game.roster_close,game.action_button,game.patient_view_button,game.patient_list_link,game.guide_settings,game.story_next,game.story_skip,game.story_off,game.guide_close,game.confirmation.ok_button,game.confirmation.cancel_button,game.journal.next_button,game.journal.close_button])
 controls.append_array(game.rows)
 for c in controls:
  if not c.is_visible_in_tree(): continue
  check(screen.grow(.1).encloses(c.get_global_rect()),caption+" safe area: "+c.name)
  if c is Button:
   var pixels: Vector2 = c.size*scale_to_pixels
   check(pixels.x >= 43.9 and pixels.y >= 43.9,caption+" 44px touch: "+c.name)
 if game.story_panel.visible:
  check(not game.story_panel.get_global_rect().intersects(game.selection_panel.get_global_rect()) or not game.selection_panel.visible,caption+" dialogue/card separation")
  check(game.story_text.get_minimum_size().y <= game.story_text.size.y,caption+" dialogue readable without clipping")
 pixel_metrics[caption] = {"window":str(root.size),"safe_ui":str(screen),"story_body_px":game.story_text.get_theme_font_size("font_size")*scale_to_pixels.y,"action_px":str(game.action_button.size*scale_to_pixels)}

func drag_from(point: Vector2) -> void:
 var scale_to_pixels := Vector2(root.size)/root.get_visible_rect().size
 var down := InputEventMouseButton.new()
 down.button_index = MOUSE_BUTTON_LEFT; down.position = point*scale_to_pixels; down.pressed = true
 Input.parse_input_event(down); await process_frame
 for i in range(1,5):
  var motion := InputEventMouseMotion.new()
  motion.position = (point+Vector2(15*i,5*i))*scale_to_pixels
  motion.relative = Vector2(15,5)*scale_to_pixels; motion.button_mask = MOUSE_BUTTON_MASK_LEFT
  Input.parse_input_event(motion); await process_frame
 down = InputEventMouseButton.new()
 down.button_index = MOUSE_BUTTON_LEFT; down.position = (point+Vector2(60,20))*scale_to_pixels
 Input.parse_input_event(down); await settle()

func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
 for dimensions in [Vector2i(844,390),Vector2i(915,412),Vector2i(1280,720)]:
  root.size = dimensions
  game = load("res://main.tscn").instantiate()
  game.safe_insets_test = Vector4(47,0,47,21) if dimensions.x < 1000 else Vector4.ZERO
  root.add_child(game); game.set_process(false)
  await settle(); game.refresh(); await settle()
  var prefix := str(dimensions.x)
  mobile_layout(prefix+" welcome"); await shot(prefix+"-welcome-safe")
  game.sim.tick(8); game.story.finish_dialogue(); game.story.sync(game.sim,1); game.story.finish_dialogue(); game.refresh()
  await click(game.patient_button); mobile_layout(prefix+" roster")
  await click(game.rows[0]); mobile_layout(prefix+" card"); await shot(prefix+"-card-safe")
  check(game.selected_id == 1 and game.sim.get_patient(1).state == "waiting","selection is separate from admission")
  var camera := camera_snapshot()
  await click(game.action_button)
  check(game.selected_id == 1 and game.sim.get_patient(1).state == "walk_ct","UI action does not click through into world")
  await click(game.zoom_in_button); await click(game.zoom_out_button)
  mobile_layout(prefix+" zoom")
  await click(game.guide_settings); mobile_layout(prefix+" settings"); await shot(prefix+"-settings-safe")
  await click(game.guide_close)
  game.story.disable(); game.clear_selection()
  camera = camera_snapshot()
  await drag_from(Vector2(game.size.x*.5,game.size.y*.6))
  check(game.selected_id == -1 and camera != camera_snapshot(),"drag pans without selecting patient")
  await click(game.overview_button)
  # Simulate a browser toolbar reducing the visible height without reloading.
  root.size = Vector2i(dimensions.x,dimensions.y-40)
  await settle(); game.refresh(); await settle()
  mobile_layout(prefix+" toolbar resize")
  root.size = dimensions; await settle(); game.refresh(); await settle()
  game.sim.paused = false
  while not game.sim.get_patient(1).paid:
   if game.sim.get_patient(1).state == "plan_ready": game.sim.assign_plan(1)
   game.sim.tick(.1)
  game.refresh(); await click(game.outside_button); await click(game.expansion_button)
  mobile_layout(prefix+" purchase"); await shot(prefix+"-purchase-safe")
  await click(game.confirmation.cancel_button)
  check(not game.sim.expanded and game.sim.money == 1100,"cancel keeps actual economy")
  await click(game.expansion_button); await click(game.confirmation.ok_button); await click(game.outside_button)
  operate(false); game.refresh(); await settle()
  mobile_layout(prefix+" journal"); await shot(prefix+"-journal-safe")
  check(game.sim.max_treating == 2 and game.journal.values[3].text == "1100만","actual dual treatment and journal preserved")
  await click(game.journal.next_button)
  check(game.sim.day == 2 and game.sim.money == 1100,"next day preserves funds")
  game.queue_free(); await process_frame; await process_frame
 var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"pixel_metrics":pixel_metrics,"platform":"Linux Godot OpenGL llvmpipe; synthetic input/insets","physical_device":false}
 FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("MOBILE UI: ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
