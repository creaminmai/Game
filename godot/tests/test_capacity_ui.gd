extends "res://tests/test_research_ui.gd"
const Capacity = preload("res://tests/daily_capacity_fixture.gd")
func capacity_layout(caption: String) -> void:
 var ratio := Vector2(root.size)/root.get_visible_rect().size
 var c: HospitalCapacityDialog = game.capacity_dialog
 check(game.safe_ui.grow(.1).encloses(c.card.get_global_rect()),caption+" capacity inside safe area")
 for b in [c.four,c.six,c.cancel_button,c.start_button]:
  check(b.size.x*ratio.x >= 44 and b.size.y*ratio.y >= 44,caption+" touch area")
  check(b.get_minimum_size().x <= b.size.x+.1,caption+" label width")
  check(c.card.get_global_rect().encloses(b.get_global_rect()),caption+" button inside card")
 for label in [c.heading,c.explanation,c.greeting]:
  check(label.get_theme_font_size("font_size")*ratio.y >= 14,caption+" text readable")
  check(label.get_minimum_size().x <= label.size.x+.1,caption+" text width")
  check(label.get_line_count()*label.get_line_height() <= label.size.y,caption+" text height")
 check(not c.cancel_button.get_global_rect().intersects(c.start_button.get_global_rect()),caption+" cancel distinct from commit")
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
 for dimensions in [Vector2i(844,350),Vector2i(844,390),Vector2i(915,412),Vector2i(1280,720)]:
  root.size = dimensions
  game = load("res://main.tscn").instantiate()
  game.safe_insets_test = Vector4(47,0,47,21) if dimensions.x < 1000 else Vector4.ZERO
  root.add_child(game); game.set_process(false); await settle()
  var prefix := "%dx%d" % [dimensions.x,dimensions.y]
  check(game.sim.restore(Capacity.first_journal().snapshot()),"normal first-day checkpoint")
  game.story.disable(); game.sim.paused = false; game.user_paused = false; game.pause_holds.clear()
  game.refresh(); await settle()
  var before: Dictionary = game.sim.snapshot()
  await click(game.journal.next_button)
  check(game.capacity_dialog.visible and game.capacity_dialog.draft == 4,"journal opens default four selection")
  capacity_layout(prefix)
  await click(game.capacity_dialog.six)
  check(game.sim.snapshot() == before,"six selection changes neither day nor balance nor preference")
  check(not game.capacity_dialog.greeting.text.contains("민지"),"guidance off suppresses first-six line")
  await click(game.capacity_dialog.cancel_button)
  check(game.sim.snapshot() == before and game.journal.visible,"cancel returns unchanged journal")
  game.story.enable_current(game.sim,-1)
  await click(game.journal.next_button); await click(game.capacity_dialog.six)
  check(game.capacity_dialog.greeting.text.contains("민지"),"first six small current-state guidance")
  await shot(prefix+"-booking")
  await click(game.capacity_dialog.start_button)
  game.capacity_dialog.commit()
  check(game.sim.day == 2 and game.sim.schedule.today_count == 6 and game.sim.money == 1100,"explicit confirmation advances once without advance income")
  check(game.day_label.text.contains("0/6"),"actual HUD denominator six")
  game.story.disable(); game.answer_admission_offer(false); game.refresh(); await settle()
  await shot(prefix+"-six-start")
  game.sim.tick(40); game.refresh(); await settle()
  await click(game.patient_button)
  check(game.rows.size() == 6 and game.rows[5].visible and not game.rows[5].disabled,"all six list entries selectable")
  await touch_scroll(game.roster_scroll,prefix+" six list")
  game.roster_scroll.ensure_control_visible(game.rows[5]); await settle()
  await shot(prefix+"-roster")
  var camera := camera_snapshot()
  await click(game.rows[5])
  check(game.selected_id == 6 and game.sim.get_patient(6).state == "waiting","sixth selection is distinct from admission")
  check(game.patient_portrait.texture != null and game.action_button.text.contains("접수"),"sixth portrait and real action")
  await shot(prefix+"-six-card")
  await click(game.action_button)
  check(game.sim.get_patient(6).admission_source == "manual","sixth actual button admission")
  Capacity.finish(game.sim); game.refresh(); await settle()
  check(game.journal.visible and game.journal.values[0].text == "6명" and game.journal.values[1].text == "1200만","six-person journal exact actual figures")
  await shot(prefix+"-six-journal")
  await click(game.journal.next_button)
  check(game.capacity_dialog.draft == 6,"remember committed six")
  await click(game.capacity_dialog.four); await click(game.capacity_dialog.start_button)
  check(game.sim.day == 3 and game.sim.schedule.today_count == 4,"user explicitly returns to four")
  var store := HospitalSaveStore.new(); store.path = "user://capacity-ui-test.json"
  check(store.save(game.sim,game.story),"next-day isolated save")
  var copy := HospitalSimulation.new()
  check(store.load_into(copy) and copy.schedule.today_count == 4 and copy.schedule.closed_counts == [4,6] and copy.money == 2300,"real file restores booking/history/cash")
  game.queue_free(); await process_frame; await process_frame
 var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"platform":"Linux Godot 4.6.3 actual renderer; automated mouse/touch emulation and synthetic safe insets","physical_mobile":false}
 FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("CAPACITY UI: ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
