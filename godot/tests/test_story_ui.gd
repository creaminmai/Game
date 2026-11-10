extends "res://tests/test_scene.gd"
var pixel_metrics: Dictionary = {}

func story_layout(caption: String) -> void:
 check_layout(caption)
 var screen := Rect2(Vector2.ZERO,root.get_visible_rect().size)
 var scale_to_pixels := Vector2(root.size)/screen.size
 var controls: Array = [game.story_panel,game.story_next,game.story_skip,game.guide_settings,game.guide_panel,game.story_off,game.guide_close,game.story_highlight]
 for control in controls:
  if control.is_visible_in_tree(): check(screen.encloses(control.get_global_rect()),caption+" visible control fits "+control.name)
 for b in [game.story_next,game.story_skip,game.guide_settings,game.story_off,game.guide_close,game.action_button,game.patient_button,game.pause_button]:
  if b.is_visible_in_tree():
   var pixels: Vector2 = b.size*scale_to_pixels
   check(pixels.x >= 43.9 and pixels.y >= 43.9,caption+" actual touch target at least 44 pixels "+b.name)
 if game.story_panel.visible:
  for control in [game.action_button,game.selection_panel,game.patient_button,game.outside_button,game.pause_button,game.guide_settings]:
   if control.is_visible_in_tree(): check(not game.story_panel.get_global_rect().intersects(control.get_global_rect()),caption+" dialogue does not overlap "+control.name)
  check(not game.story_next.get_global_rect().intersects(game.story_skip.get_global_rect()),caption+" primary and secondary touch targets are separate")
  var body_px: float = game.story_text.get_theme_font_size("font_size")*scale_to_pixels.y
  var name_px: float = game.story_heading.get_theme_font_size("font_size")*scale_to_pixels.y
  check(body_px >= 16 and name_px >= 17,caption+" actual body/name type size")
  check(game.story_text.get_line_count() <= 4 and game.story_text.get_minimum_size().y <= game.story_text.size.y,caption+" spoken line fits without clipping")
  pixel_metrics[caption] = {"body_px":body_px,"name_px":name_px,"next_button_px":str(game.story_next.size*scale_to_pixels),"panel_px":str(game.story_panel.size*scale_to_pixels)}
  for p in game.sim.patients:
   if p.state in ["waiting","plan_ready","ct_scan"]:
    var actor: HospitalActor = game.world.actors[p.id]
    var point: Vector2 = game.world.camera.unproject_position(actor.head.global_position)*game.size/Vector2(game.viewport.size)
    check(not game.story_panel.get_global_rect().grow(3).has_point(point),caption+" patient face remains visible "+str(p.id))

func dismiss_dialogue() -> void:
 if game.story_panel.visible: await click(game.story_skip)

func operate(expand: bool) -> void:
 for step in range(5000):
  game.story.finish_dialogue()
  for p in game.sim.patients:
   if p.state == "waiting": game.sim.admit(p.id)
   elif p.state == "plan_ready": game.sim.assign_plan(p.id)
  if expand and game.sim.expansion_reason().is_empty(): game.sim.purchase_expansion()
  game.sim.tick(.1)
  game.story.sync(game.sim,game.selected_id)
  if game.sim.all_done(): return

func click_site() -> void:
 var pixel: Vector2 = game.world.camera.unproject_position(Vector3(7,.08,1.8))
 check(game.world.pick_expansion_site(pixel),"actual projected exterior footprint is selectable")
 var point := pixel*Vector2(root.size)/Vector2(game.viewport.size)
 for pressed in [true,false]:
  var event := InputEventMouseButton.new()
  event.button_index = MOUSE_BUTTON_LEFT; event.position = point; event.pressed = pressed
  Input.parse_input_event(event)
  await process_frame
 await settle()

func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
 for dimensions in [Vector2i(1280,720),Vector2i(844,390)]:
  root.size = dimensions
  game = load("res://main.tscn").instantiate()
  root.add_child(game); game.set_process(false)
  await settle(); game.refresh(); await settle()
  var prefix := "desktop" if dimensions.x == 1280 else "compact"
  var camera := camera_snapshot()
  check(game.story.active == "welcome","one-line welcome in real engine")
  story_layout(prefix+" welcome")
  await shot(prefix+"-01-welcome")
  game.sim.tick(8); game.refresh()
  check(game.story.active == "welcome","passive arrival never replaces a line being read")
  await click(game.story_next)
  check(game.story.active == "arrival","one next action reaches Kim's story")
  story_layout(prefix+" arrival")
  await shot(prefix+"-02-arrival")
  await click(game.story_next)
  check(not game.story_panel.visible,"two short lines reach actual player action")
  await click(game.patient_button)
  await click(game.rows[0])
  check(game.selected_id == 1 and game.sim.get_patient(1).state == "waiting" and not game.story_panel.visible,"selection and admission remain separate, without another dialogue")
  story_layout(prefix+" selected")
  check(game.reason_label.text.contains("접수하기") and game.story_highlight.visible,"actual action button carries the instruction and border")
  await shot(prefix+"-03-admission")
  await click(game.action_button)
  check(game.sim.get_patient(1).state == "walk_ct","actual button starts admission once")
  check(game.story.active == "ct","CT line is linked to actual admission")
  story_layout(prefix+" CT")
  await shot(prefix+"-04-ct")
  await click(game.guide_settings)
  check(game.guide_panel.visible and not game.story_panel.visible,"guide setting is a separate destination")
  story_layout(prefix+" settings")
  await click(game.story_off)
  check(not game.story.enabled,"guide off works through separate setting")
  var store := HospitalSaveStore.new(); store.path = "user://polish-ui-save.json"
  check(store.save(game.sim,game.story),"save disabled guide through actual file")
  check(store.load_into(game.sim,game.story) and not game.story.enabled,"disabled guide survives file reload")
  game.sim.paused = false; game.sim.tick(30); game.refresh()
  await click(game.story_off)
  check(game.story.enabled and game.story.active == "","re-enable at current stage without old dialogue backlog")
  await shot(prefix+"-05-settings")
  await click(game.guide_close)
  check(game.story.hint(game.sim,1,false).contains("계획"),"re-enable points to the current plan action")
  await click(game.action_button)
  while not game.sim.get_patient(1).paid: game.sim.tick(.1)
  game.refresh(); await settle()
  await click(game.outside_button)
  var exterior_camera := camera_snapshot()
  await click_site()
  check(game.confirmation.visible and game.world.plot_selected,"actual footprint click selects the purchase site")
  var physical_scale := Vector2(root.size)/root.get_visible_rect().size
  for b in [game.confirmation.ok_button,game.confirmation.cancel_button]:
   check(b.size.y*physical_scale.y >= 43.9,"purchase dialog actual touch height at least 44 pixels")
  check(not game.confirmation.ok_button.get_global_rect().intersects(game.confirmation.cancel_button.get_global_rect()),"purchase and cancel touch regions never overlap")
  check(not game.confirmation.card.get_global_rect().intersects(game.facility_callout.get_global_rect()),"purchase card leaves the actual site label visible")
  var funds: int = game.sim.money
  await shot(prefix+"-06-purchase")
  await click(game.confirmation.get_cancel_button())
  check(game.sim.money == funds and not game.sim.expanded and not game.world.plot_selected,"cancel does not charge or build")
  await click_site()
  await click(game.confirmation.get_ok_button())
  check(game.sim.money == funds-600 and game.sim.expanded and game.world.wing_built,"purchase builds the actual second room once")
  check(game.world.celebration_count == 1,"only the actual purchase triggers completion feedback")
  check(camera_snapshot() == exterior_camera,"purchase animation does not move or zoom the camera")
  await shot(prefix+"-07-built")
  check(store.save(game.sim,game.story),"save immediately after purchase")
  check(store.load_into(game.sim,game.story) and game.sim.expanded and game.sim.money == funds-600,"purchase save restores consistent completed facility and funds")
  game.sim.paused = true
  await click(game.outside_button)
  check(game.world.inside_marker.visible,"return briefly marks the new real treatment room")
  await shot(prefix+"-08-new-room")
  game.sim.paused = false
  operate(false); game.refresh(); await settle()
  if game.story_panel.visible: await click(game.story_skip)
  game.refresh(); await settle()
  check(game.journal.visible and game.sim.all_done(),"journal appears after actual departures")
  check(game.journal.values[1].text == "800만" and game.journal.values[2].text == "600만" and game.journal.values[3].text == "1100만","journal separates income, expense and cash")
  check(game.sim.max_treating == 2,"two room operation remains possible")
  check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(game.journal.card.get_global_rect()),"journal fits actual viewport")
  for b in [game.journal.next_button,game.journal.close_button]:
   check(b.size.y*physical_scale.y >= 43.9,"journal actual touch height at least 44 pixels")
  check(not game.journal.next_button.get_global_rect().intersects(game.journal.close_button.get_global_rect()),"journal buttons are separate")
  await shot(prefix+"-09-journal")
  check(store.save(game.sim,game.story) and store.load_into(game.sim,game.story),"journal-state save and reload")
  check(game.sim.money == 1100 and game.sim.ledger.income == 800,"journal reload cannot pay twice")
  await click(game.journal.next_button)
  if game.capacity_dialog.visible: await click(game.capacity_dialog.start_button)
  game.start_day() # An immediate second request must be harmless.
  check(game.sim.day == 2 and not game.journal.visible and game.story.active == "","next-day double request advances once, with no first-day dialogue")
  check(game.sim.ledger.income == 0 and game.sim.ledger.expansion_expense == 0 and game.sim.money == 1100,"new day clears only the daily aggregates")
  await shot(prefix+"-10-day-two")
  DirAccess.remove_absolute(store.path)
  game.free()
 # Deferred expansion and legacy records have their own actual journal views.
 game = load("res://main.tscn").instantiate()
 root.add_child(game); game.set_process(false)
 await settle()
 game.story.disable(); operate(false); game.refresh(); await settle()
 check(game.journal.visible and game.journal.values[2].text == "0만" and game.journal.values[3].text == "1700만","journal without expansion reports actual zero expense and 1700 cash")
 await shot("compact-11-journal-no-expansion")
 await click(game.journal.close_button)
 check(not game.journal.visible and game.next_day_button.visible,"journal can close without advancing or blocking the hospital")
 await click(game.next_day_button)
 check(game.journal.visible,"existing day-end affordance reopens the journal")
 var legacy: Dictionary = game.sim.snapshot(); legacy.erase("daily_ledger")
 check(game.sim.restore(legacy),"legacy day-end save restores")
 game.journal.present(game.sim)
 check(game.journal.values[2].text.contains("기록 없음"),"legacy expense is not guessed")
 await shot("compact-12-journal-legacy")
 game.free()
 var result := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"automatic_input":true,"renderer":"Godot Compatibility / Linux llvmpipe","mobile_hardware_test":false,"actual_pixel_metrics":pixel_metrics}
 FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("STORY UI: ",JSON.stringify(result))
 quit(0 if failures.is_empty() else 1)
