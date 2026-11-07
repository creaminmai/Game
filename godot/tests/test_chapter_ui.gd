extends "res://tests/test_mobile_ui.gd"
const Fixture = preload("res://tests/chapter_fixture.gd")

func chapter_layout(caption: String) -> void:
 mobile_layout(caption)
 var ratio := Vector2(root.size)/root.get_visible_rect().size
 var c = game.chapter_panel
 for node in [game.goal_ribbon,c,c.close_button,game.journal.chapter_stamp]:
  if not node.is_visible_in_tree(): continue
  check(game.safe_ui.grow(.1).encloses(node.get_global_rect()),caption+" chapter safe area "+node.name)
  if node is Button: check(node.size.x*ratio.x >= 43.9 and node.size.y*ratio.y >= 43.9,caption+" chapter touch target")
 if c.visible:
  for other in [game.selection_panel,game.story_panel,game.guide_panel,game.admission_offer,game.guide_settings,game.dock,game.zoom_in_button,game.zoom_out_button]:
   if other.is_visible_in_tree(): check(not c.get_global_rect().intersects(other.get_global_rect()),caption+" chapter does not overlap "+other.name+(other.text if other is Button else ""))
  for label in c.conditions:
   check(label.get_line_count()*label.get_line_height() <= label.size.y,caption+" condition lines fit")
   check(c.get_global_rect().encloses(label.get_global_rect()),caption+" condition inside panel")
  for i in range(2): check(not c.conditions[i].get_global_rect().intersects(c.conditions[i+1].get_global_rect()),caption+" condition rows separated")
 if game.story_panel.visible:
  check(game.story_text.get_line_count()*game.story_text.get_line_height() <= game.story_text.size.y,caption+" growth dialogue lines fit")
 if game.journal.visible:
  check(game.journal.quote.get_line_count()*game.journal.quote.get_line_height() <= game.journal.quote.size.y,caption+" journal quote lines fit")
  check(not game.journal.chapter_stamp.get_global_rect().intersects(game.journal.date_label.get_global_rect()),caption+" daily date and cumulative stamp separated")

func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
 for dimensions in [Vector2i(844,350),Vector2i(844,390),Vector2i(915,412),Vector2i(1280,720)]:
  root.size = dimensions
  game = load("res://main.tscn").instantiate()
  game.safe_insets_test = Vector4(47,0,47,21) if dimensions.x < 1000 else Vector4.ZERO
  root.add_child(game); game.set_process(false); await settle()
  Fixture.finish_day(game.sim,99); game.story.finish_dialogue(); game.refresh(); await settle()
  var prefix := "%dx%d" % [dimensions.x,dimensions.y]
  chapter_layout(prefix+" first journal"); await shot(prefix+"-first-journal")
  check(game.sim.chapters.chapter_one_day == 1 and game.sim.chapters.total() == 4,"first chapter from real departures, before detail opened")
  await click(game.journal.close_button)
  var camera := camera_snapshot(); var balance: int = game.sim.money
  await click(game.goal_ribbon); chapter_layout(prefix+" initial goals"); await shot(prefix+"-goals")
  check(camera_snapshot() == camera and game.sim.money == balance,"goal review has no camera/economic side effects")
  check(game.chapter_panel.conditions[2].text.contains("4/12"),"first four included immediately")
  await click(game.chapter_panel.close_button); await click(game.next_day_button); await click(game.journal.next_button)
  check(game.admission_offer.visible and not game.story_panel.visible,"staff offer has dialogue priority")
  await click(game.admission_decline)
  game.sim.tick(8); game.refresh(); await settle()
  await click(game.patient_button); await click(game.rows[0]); await click(game.goal_ribbon)
  chapter_layout(prefix+" selected card and goals"); await shot(prefix+"-card-goals")
  await click(game.chapter_panel.close_button)
  await click(game.outside_button); await click(game.expansion_button); await click(game.confirmation.ok_button); await click(game.outside_button)
  check(game.story_panel.visible and game.sim.chapters.active == "annex_ready" and not game.admission_offer.visible,"one growth scene after actual expansion")
  chapter_layout(prefix+" growth dialogue"); await shot(prefix+"-growth")
  await click(game.story_skip); await click(game.goal_ribbon)
  check(game.sim.expanded and not game.sim.chapters.dual_experienced,"building empty annex alone does not tick concurrency")
  chapter_layout(prefix+" built not used")
  for step in range(2000):
   Fixture.step(game.sim,2)
   if HospitalChapterProgress.simultaneous(game.sim): break
  game.refresh(); await settle()
  check(game.sim.chapters.dual_experienced and game.chapter_panel.conditions[1].text.contains("✓"),"live dual use updates an already open goal panel")
  chapter_layout(prefix+" dual goals"); await shot(prefix+"-dual-goals")
  await click(game.chapter_panel.close_button)
  if game.story_panel.visible: await click(game.story_next)
  Fixture.finish_day(game.sim,2); game.sim.chapters.finish_scene(); game.refresh(); await settle()
  await click(game.journal.next_button)
  game.story.disable(); Fixture.finish_day(game.sim,2); game.refresh(); await settle()
  chapter_layout(prefix+" final journal"); await shot(prefix+"-final-journal")
  check(game.sim.money == 2700 and game.sim.chapters.total() == 12 and game.journal.chapter_stamp.text.contains("2장"),"actual third-day receipts and chapter stamp")
  await click(game.journal.next_button); check(game.sim.day == 4,"chapter completion allows next day")
  await click(game.goal_ribbon); chapter_layout(prefix+" completed history")
  check(game.chapter_panel.first.text.contains("완료") and game.chapter_panel.second.text.contains("완료"),"both chapters remain in history without chapter-three controls")
  game.queue_free(); await process_frame; await process_frame
 var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"pixel_metrics":pixel_metrics,"platform":"Linux Godot; automated input + simulated safe insets","physical_mobile":false}
 FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("CHAPTER UI: ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
