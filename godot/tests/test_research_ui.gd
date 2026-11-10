extends "res://tests/test_chapter_ui.gd"
const ResearchFixture = preload("res://tests/research_fixture.gd")
func research_layout(caption: String) -> void:
 var ratio := Vector2(root.size)/root.get_visible_rect().size
 var panel: HospitalResearchPanel = game.research_panel
 for control in [panel.card,panel.close_button,panel.return_button,panel.scroll]:
  if not control.is_visible_in_tree(): continue
  check(game.safe_ui.grow(.1).encloses(control.get_global_rect()),caption+" research safe area "+control.name)
 for b in [panel.close_button,panel.return_button,panel.build_button]+panel.project_buttons.values():
  if not b.is_visible_in_tree(): continue
  check(b.size.x*ratio.x >= 44 and b.size.y*ratio.y >= 44,caption+" research touch size")
  check(b.get_minimum_size().x <= b.size.x+.01,caption+" research button label fits")
 if panel.confirmation.visible:
  check(game.safe_ui.grow(.1).encloses(panel.confirmation.card.get_global_rect()),caption+" confirmation fits safe area")
  for b in [panel.confirmation.ok_button,panel.confirmation.cancel_button]: check(b.size.y*ratio.y >= 44,caption+" confirm touch size")
  check(not panel.confirmation.ok_button.get_global_rect().intersects(panel.confirmation.cancel_button.get_global_rect()),caption+" distinct cancel and buy")
 for label in panel.texts:
  if not label.is_visible_in_tree(): continue
  check(label.get_theme_font_size("font_size")*ratio.y >= 14,caption+" research text readable")
  check(label.get_minimum_size().x <= label.size.x+.1,caption+" research text wraps")
 if game.journal.visible:
  check(game.safe_ui.grow(.1).encloses(game.journal.card.get_global_rect()),caption+" journal safe area")
  check(not game.journal.financial_scroll.get_global_rect().intersects(game.journal.next_button.get_global_rect()),caption+" scroll separate from next day")
func reveal(b: Control) -> void:
 game.research_panel.scroll.ensure_control_visible(b)
 await settle()
func touch_scroll(container: ScrollContainer, caption: String) -> void:
 # Exercise real GUI propagation through card/content children, not an assigned
 # scroll offset. Desktop Xorg emulates a touchscreen only for this gesture.
 var original := Input.is_emulating_touch_from_mouse()
 Input.emulate_touch_from_mouse = true
 var rect := container.get_global_rect()
 var pixels := Vector2(root.size)/root.get_visible_rect().size
 var start := (rect.get_center()+Vector2(0,rect.size.y*.3))*pixels
 var initial := container.scroll_vertical
 var before: Dictionary = game.sim.snapshot()
 var move := InputEventMouseMotion.new()
 move.position = start; Input.parse_input_event(move)
 var press := InputEventMouseButton.new()
 press.position = start; press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true
 Input.parse_input_event(press); await settle()
 var previous := start
 for n in range(1,9):
  var motion := InputEventMouseMotion.new()
  motion.position = start-Vector2(0,rect.size.y*pixels.y*.6*n/8)
  motion.relative = motion.position-previous; motion.button_mask = MOUSE_BUTTON_MASK_LEFT
  Input.parse_input_event(motion); previous = motion.position; await settle()
 press = InputEventMouseButton.new()
 press.position = previous; press.button_index = MOUSE_BUTTON_LEFT; press.pressed = false
 Input.parse_input_event(press); await settle()
 Input.emulate_touch_from_mouse = original
 check(container.scroll_vertical > initial,caption+" actual touch drag scrolls content")
 check(game.sim.snapshot() == before,caption+" drag does not execute an operation")
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
 for dimensions in [Vector2i(844,350),Vector2i(844,390),Vector2i(915,412),Vector2i(1280,720)]:
  root.size = dimensions
  game = load("res://main.tscn").instantiate()
  game.safe_insets_test = Vector4(47,0,47,21) if dimensions.x < 1000 else Vector4.ZERO
  root.add_child(game); game.set_process(false); await settle()
  var prefix := "%dx%d" % [dimensions.x,dimensions.y]
  game.story.disable(); game.open_research(); await settle()
  check(game.research_panel.build_button.disabled and game.research_panel.summary.text.contains("3장"),"locked lab reason visible")
  research_layout(prefix+" locked")
  await click(game.research_panel.return_button)
  var checkpoint: HospitalSimulation = ResearchFixture.prepare()
  check(game.sim.restore(checkpoint.snapshot()),"real four-day checkpoint restored")
  game.sim.paused = false; game.user_paused = false; game.pause_holds.clear()
  game.story.enable_current(game.sim,-1); game.sim.chapters.guidance_changed(true,game.sim); game.sim.operations.guidance_changed(true,game.sim)
  game.refresh(); await settle()
  var interior_camera := camera_snapshot()
  await click(game.outside_button)
  var time_before: float = game.sim.time
  game.sim.tick(30)
  check(game.sim.time == time_before and game.sim.paused,"outside freezes existing simulation and research has no wall-clock timer")
  await shot(prefix+"-site")
  var lab_point: Vector2 = game.world.camera.unproject_position(game.world.LAB_POSITION)*game.scene_container.size/Vector2(game.viewport.size)
  var mouse := InputEventMouseButton.new(); mouse.button_index = MOUSE_BUTTON_LEFT; mouse.position = lab_point
  game.scene_input(mouse); await settle()
  check(game.research_panel.visible and game.world.lab_border.visible,"actual projected 3D plot opens research")
  research_layout(prefix+" offer"); await shot(prefix+"-offer")
  await reveal(game.research_panel.build_button); await click(game.research_panel.build_button)
  research_layout(prefix+" construction confirm"); await shot(prefix+"-confirm")
  var before: Dictionary = game.sim.snapshot()
  await click(game.research_panel.confirmation.cancel_button)
  check(game.sim.snapshot() == before,"cancel has no point or cash transaction")
  await click(game.research_panel.build_button); await click(game.research_panel.confirmation.ok_button)
  check(game.sim.research.built_day == 5 and game.sim.money == 1200 and game.sim.research.points == 6,"actual build button grants once")
  check(game.world.lab_model.visible and game.world.researcher.visible and not game.world.lab_site.visible,"real GLB and researcher replace site immediately")
  check(game.world.pick_lab_site(game.world.camera.unproject_position(game.world.LAB_POSITION+Vector3(0,3.35,-1))),"roof click selects building above ground footprint")
  research_layout(prefix+" built")
  await touch_scroll(game.research_panel.scroll,prefix+" research")
  await click(game.research_panel.close_button)
  check(game.story_panel.visible and game.story_heading.text.contains("윤서진"),"researcher uses one shared dialogue channel")
  await shot(prefix+"-researcher")
  await click(game.story_next); await click(game.story_skip)
  check(game.sim.research.projects.is_empty(),"skip never starts research")
  game.hud.hide(); await shot(prefix+"-exterior-clean"); game.hud.show()
  await click(game.expansion_button)
  await reveal(game.research_panel.project_buttons.ct)
  await click(game.research_panel.project_buttons.ct)
  check(game.research_panel.confirm_body.text.contains("6일차 마감 예정 / 7일차부터 적용"),"actual dates on research confirmation")
  research_layout(prefix+" start confirm"); await shot(prefix+"-research-confirm")
  await click(game.research_panel.confirmation.ok_button)
  check(game.sim.money == 700 and game.sim.research.points == 0 and game.research_panel.project_buttons.plan.disabled,"start deducts once and locks second slot")
  await click(game.research_panel.return_button)
  check(not game.outside and not game.sim.paused,"return releases only exterior hold")
  game.sim.paused = true; game.user_paused = true
  await click(game.expansion_button); await click(game.research_panel.return_button)
  check(game.sim.paused and game.user_paused,"research visit preserves user pause")
  game.sim.paused = false; game.user_paused = false
  ResearchFixture.finish(game.sim); game.refresh(); await settle()
  check(game.journal.visible and game.journal.values[3].text == "1500만","real day-five journal money")
  research_layout(prefix+" journal"); await shot(prefix+"-journal")
  await touch_scroll(game.journal.financial_scroll,prefix+" journal")
  game.journal.financial_scroll.scroll_vertical = 250; await settle()
  check(game.journal.lab_value.text == "1800만" and game.journal.research_value.text == "500만","separate lab and project expenses")
  await shot(prefix+"-journal-research")
  await click(game.journal.next_button)
  if game.capacity_dialog.visible: await click(game.capacity_dialog.start_button)
  ResearchFixture.finish(game.sim); game.refresh(); await settle()
  check(game.sim.research.projects.ct.completed_day == 6 and not game.sim.research.applied("ct"),"research complete pending application")
  await click(game.journal.next_button)
  if game.capacity_dialog.visible: await click(game.capacity_dialog.start_button)
  check(game.sim.research.applied("ct") and game.sim.research.chapter_four_day == 7,"next-day activation")
  if game.story_panel.visible: await click(game.story_next)
  await click(game.goal_ribbon); await settle()
  check(game.chapter_panel.second.text.contains("4장") and game.chapter_panel.conditions[1].text.contains("✓"),"chapter actual effect condition shown")
  chapter_layout(prefix+" chapter four"); await shot(prefix+"-chapter")
  await click(game.chapter_panel.close_button)
  game.story.disable(); ResearchFixture.finish(game.sim); game.refresh(); await settle()
  check(game.journal.chapter_stamp.text.contains("4장"),"chapter four journal stamp")
  game.queue_free(); await process_frame; await process_frame
 var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"pixel_metrics":pixel_metrics,"platform":"Linux Godot actual renderer; automated input and synthetic safe insets","physical_mobile":false}
 FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("RESEARCH UI: ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
