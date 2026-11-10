extends "res://tests/test_chapter_ui.gd"
const OperationsFixture = preload("res://tests/operations_fixture.gd")
func operations_layout(caption: String) -> void:
 chapter_layout(caption)
 var ratio := Vector2(root.size)/root.get_visible_rect().size
 var controls := [game.training_button,game.planning_toggle,game.admission_toggle,game.training_dialog.card,game.training_dialog.ok_button,game.training_dialog.cancel_button,game.chapter_panel.history_button]
 for node in controls:
  if not node.is_visible_in_tree(): continue
  check(game.safe_ui.grow(.1).encloses(node.get_global_rect()),caption+" safe area "+node.name)
  if node is Button:
   check(node.size.x*ratio.x >= 43.9 and node.size.y*ratio.y >= 43.9,caption+" 44px new touch target")
   check(node.get_minimum_size().x <= node.size.x,caption+" button label fits")
 if game.guide_panel.visible:
  var buttons := [game.guide_close,game.admission_toggle,game.training_button,game.planning_toggle,game.story_off]
  for a in range(buttons.size()):
   for b in range(a+1,buttons.size()): check(not buttons[a].get_global_rect().intersects(buttons[b].get_global_rect()),caption+" settings buttons separated")
  check(not game.dock.visible and not game.outside_button.visible and not game.guide_settings.visible,"settings owns its column without shrinking dock buttons")
  check(game.guide_panel.get_global_rect().encloses(game.guide_description.get_global_rect()),caption+" staff role text inside settings")
  check(not game.guide_panel.get_global_rect().intersects(game.selection_panel.get_global_rect()) or not game.selection_panel.visible,caption+" settings/card separated")
 if game.journal.visible:
  check(game.journal.training_value.text == "500만","journal training receipt separate")
  check(game.journal.values[2].text == "0만" and game.journal.values[3].text == "3000만","annex expense not polluted by training")
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
 for dimensions in [Vector2i(844,350),Vector2i(844,390),Vector2i(915,412),Vector2i(1280,720)]:
  root.size = dimensions
  game = load("res://main.tscn").instantiate()
  game.safe_insets_test = Vector4(47,0,47,21) if dimensions.x < 1000 else Vector4.ZERO
  root.add_child(game); game.set_process(false); await settle()
  var prefix := "%dx%d" % [dimensions.x,dimensions.y]
  await click(game.guide_settings); await click(game.training_button)
  check(game.training_dialog.visible and game.training_dialog.ok_button.disabled,"locked education detail readable without purchase")
  operations_layout(prefix+" locked"); await click(game.training_dialog.cancel_button); await click(game.guide_close)
  var checkpoint: HospitalSimulation = Fixture.prepare(4)
  checkpoint.set_admission_delegated(false)
  check(game.sim.restore(checkpoint.snapshot()),"normal three-day checkpoint restores")
  game.sim.paused = false
  game.story.enable_current(game.sim,-1)
  game.sim.chapters.guidance_changed(true,game.sim)
  game.refresh(); await settle()
  check(game.story_panel.visible and game.sim.operations.active == "introduction","one chapter-three scene in shared dialogue")
  operations_layout(prefix+" introduction"); await shot(prefix+"-introduction")
  await click(game.story_next)
  check(game.story_heading.text.contains("박 선생"),"existing planner distinct from director")
  operations_layout(prefix+" planner"); await shot(prefix+"-planner")
  await click(game.story_skip)
  check(not game.sim.operations.trained and not game.sim.operations.enabled,"story skip never purchases or enables")
  game.sim.tick(8); game.refresh()
  await click(game.patient_button); await click(game.rows[0]); await click(game.guide_settings)
  var camera := camera_snapshot()
  operations_layout(prefix+" settings and card"); await shot(prefix+"-settings")
  var before: Dictionary = game.sim.snapshot()
  await click(game.training_button); operations_layout(prefix+" purchase"); await shot(prefix+"-purchase")
  await click(game.training_dialog.cancel_button)
  check(before == game.sim.snapshot(),"cancel changes neither facility nor expense")
  await click(game.training_button); await click(game.training_dialog.ok_button)
  check(game.sim.operations.trained and not game.sim.operations.enabled and game.sim.money == 2200,"purchase distinct from activation")
  await click(game.planning_toggle); await click(game.admission_toggle)
  check(game.sim.operations.enabled and game.sim.admission.enabled and camera == camera_snapshot() and game.selected_id == 1,"duties do not select or move camera")
  operations_layout(prefix+" enabled"); await shot(prefix+"-enabled")
  await click(game.guide_close)
  if game.story_panel.visible: await click(game.story_next)
  for n in range(1000):
   game.sim.tick(.1)
   if game.sim.operations.candidate_id == 1: break
  game.refresh(); await settle()
  check(game.reason_label.text.contains("준비") and game.sim.get_patient(1).state == "plan_ready","selected card reflects actual preparation")
  operations_layout(prefix+" preparing"); await shot(prefix+"-preparing")
  var response_count: int = game.world.staff_models[1].staff_event_count
  game.sim.tick(3); game.refresh(); await settle()
  check(game.world.staff_models[1].staff_event_count == response_count+1,"normal successful plan command reuses planner response")
  OperationsFixture.finish(game.sim); game.refresh(); await settle()
  check(game.journal.visible and game.journal.chapter_stamp.text.contains("3장"),"four real delegated departures present chapter stamp")
  operations_layout(prefix+" journal"); await shot(prefix+"-journal")
  await click(game.journal.close_button); await click(game.goal_ribbon)
  check(game.chapter_panel.second.text.contains("4장"),"completed chapter three exposes new current goal")
  await click(game.chapter_panel.history_button)
  check(game.chapter_panel.conditions[1].text.contains("4/4"),"growth record shows actual delegated total")
  operations_layout(prefix+" growth"); await shot(prefix+"-growth")
  await click(game.chapter_panel.history_button)
  check(game.chapter_panel.first.text.contains("완료") and game.chapter_panel.second.text.contains("완료"),"previous completed chapters remain reviewable")
  operations_layout(prefix+" history")
  await click(game.chapter_panel.close_button); await click(game.next_day_button); await click(game.journal.next_button)
  if game.capacity_dialog.visible: await click(game.capacity_dialog.start_button)
  check(game.sim.day == 5 and game.sim.operations.total() == 4 and game.sim.ledger.training_expense == 0,"next day preserves chapter and resets expense")
  await click(game.guide_settings); await click(game.story_off)
  var store := HospitalSaveStore.new(); store.path = "user://operations-ui.json"
  store.save(game.sim,game.story); check(store.load_into(game.sim,game.story),"actual settings file roundtrip")
  check(not game.story.enabled and game.sim.operations.enabled,"guidance and duty independent after reload")
  await click(game.story_off); await click(game.guide_close)
  check(game.sim.operations.active == "" and not game.story_panel.visible,"re-enable does not replay completed stories")
  game.queue_free(); await process_frame; await process_frame
 var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"pixel_metrics":pixel_metrics,"platform":"Linux Godot OpenGL llvmpipe; automatic mouse input and synthetic safe insets","physical_mobile":false}
 FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("OPERATIONS UI: ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
