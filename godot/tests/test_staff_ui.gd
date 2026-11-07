extends "res://tests/test_mobile_ui.gd"
const Fixture = preload("res://tests/staff_fixture.gd")

func staff_layout(caption: String) -> void:
 mobile_layout(caption)
 var ratio := Vector2(root.size)/root.get_visible_rect().size
 for c in [game.admission_offer,game.admission_accept,game.admission_decline,game.admission_skip,game.admission_toggle]:
  if not c.is_visible_in_tree(): continue
  check(game.safe_ui.grow(.1).encloses(c.get_global_rect()),caption+" new control within safe area "+c.name)
  if c is Button: check(c.size.x*ratio.x >= 43.9 and c.size.y*ratio.y >= 43.9,caption+" new 44px touch "+c.name)
 for pane in [game.story_panel,game.admission_offer,game.guide_panel]:
  if not pane.visible: continue
  for c in [game.selection_panel,game.guide_settings,game.patient_button,game.next_button,game.outside_button,game.zoom_in_button,game.zoom_out_button]:
   if c.is_visible_in_tree(): check(not pane.get_global_rect().intersects(c.get_global_rect()),caption+" panel separated from "+c.name)
 if game.admission_offer.visible:
  check(game.admission_offer_text.get_minimum_size().y <= game.admission_offer_text.size.y,caption+" offer text not clipped")
  check(game.admission_offer_text.get_theme_font_size("font_size")*ratio.y >= 16,caption+" readable offer body")
  check(game.admission_offer_text.get_line_count()*game.admission_offer_text.get_line_height() <= game.admission_offer_text.size.y,caption+" actual offer line heights fit")
 if game.guide_panel.visible:
  check(game.guide_description.get_line_count()*game.guide_description.get_line_height() <= game.guide_description.size.y,caption+" settings description lines fit")
  check(game.guide_panel.get_global_rect().encloses(game.guide_description.get_global_rect()),caption+" settings text inside panel")
 for c in [game.outside_button,game.patient_button,game.overview_button,game.dock]:
  check(not game.guide_settings.get_global_rect().intersects(c.get_global_rect()),caption+" settings separated from dock")

func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
 for dimensions in [Vector2i(844,350),Vector2i(844,390),Vector2i(915,412),Vector2i(1280,720)]:
  root.size = dimensions
  game = load("res://main.tscn").instantiate()
  game.safe_insets_test = Vector4(47,0,47,21) if dimensions.x < 1000 else Vector4.ZERO
  root.add_child(game); game.set_process(false)
  await settle(); game.sim.tick(8); game.select_patient(1); game.perform_action(); game.refresh(); await settle()
  var prefix := "%dx%d" % [dimensions.x,dimensions.y]
  staff_layout(prefix+" day-one dialogue/card")
  await shot(prefix+"-dialogue-card")
  await click(game.guide_settings); staff_layout(prefix+" day-one settings")
  check(game.admission_toggle.disabled,"day-one UI cannot enable duty")
  await click(game.guide_close)
  game.sim.restore(Fixture.day_two(true).snapshot()); game.sim.paused = false; game.user_paused = false
  game.selected_id = -1; game.refresh(); await settle()
  staff_layout(prefix+" proposal"); await shot(prefix+"-offer")
  await click(game.admission_decline)
  check(not game.sim.admission.enabled and game.sim.admission.offer_seen,"actual decline click remains manual")
  game.sim.admission.offer_seen = false; game.refresh(); await settle()
  await click(game.admission_skip)
  check(not game.sim.admission.enabled and not game.admission_offer.visible,"actual skip never consents")
  game.sim.admission.offer_seen = false; game.refresh(); await settle()
  await click(game.admission_accept)
  check(game.sim.admission.enabled,"actual accept click enables duty")
  var selected: int = game.selected_id
  game.sim.tick(14); game.refresh(); await settle()
  check(game.selected_id == selected and not game.selection_panel.visible,"auto admission never opens a card")
  await click(game.patient_button); await click(game.rows[1]); staff_layout(prefix+" delegated card")
  check(game.sim.get_patient(2).state == "ct_queue" and game.action_button.disabled,"busy CT retains queue and reason")
  await shot(prefix+"-queue-card")
  await click(game.guide_settings); staff_layout(prefix+" delegated settings"); await shot(prefix+"-settings")
  await click(game.admission_toggle)
  check(not game.sim.admission.enabled and game.guide_settings.text.contains("직접"),"actual toggle restores manual label")
  await click(game.story_off)
  check(not game.story.enabled and not game.sim.admission.enabled,"guidance is independent")
  await click(game.admission_toggle)
  check(game.sim.admission.enabled and not game.story.enabled,"delegation can operate without guidance")
  await click(game.guide_close)
  game.sim.tick(55); game.refresh(); await settle(); await click(game.next_button)
  check(game.sim.get_patient(game.selected_id).state == "plan_ready","attention button finds manual plan work")
  await click(game.action_button)
  check(game.sim.planner_owner == game.selected_id,"real plan click remains necessary")
  game.queue_free(); await process_frame; await process_frame
 var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"pixel_metrics":pixel_metrics,"platform":"Linux Godot OpenGL llvmpipe; automated mouse input, simulated safe insets","physical_mobile":false}
 FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("STAFF UI: ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
