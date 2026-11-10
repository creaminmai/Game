extends "res://tests/record_normal.gd"
# Checkpoints use normal simulation commands before recording. Delivered frames
# run at 1x; automated mouse input is labeled in the picture and report.
const Fixture = preload("res://tests/chapter_fixture.gd")
var segment := "journal"

func prepare_checkpoint() -> void:
 var target_day := 3 if segment == "completion" else (2 if segment == "annex" else 1)
 var expansion_day := 1 if segment == "completion" else 99
 while game.sim.day < target_day:
  Fixture.finish_day(game.sim,expansion_day)
  game.journal.present(game.sim)
  game.journal.hide()
  assert(game.sim.start_next_day())
 # This checkpoint's first-day story and delegation proposal were declined
 # through their real handlers. Nothing enables automatic plans or admission.
 for n in range(12): game.story.sync(game.sim,1); game.story.finish_dialogue()
 if target_day >= 2: game.answer_admission_offer(false)
 for n in range(10000):
  Fixture.step(game.sim,expansion_day,false,.05)
  game.sim.chapters.sync_story(game.sim,true,true)
  game.sim.chapters.finish_scene()
  if segment == "annex":
   if game.sim.count_state("treatment") == 1 and game.sim.count_state("treatment_queue") > 0: break
  elif game.sim.count_state("complete") == 3 and game.sim.completed() == 4:
   var near_exit := false
   for p in game.sim.patients:
    if p.state == "leaving" and p.route.size() == 1 and p.position.distance_to(p.route[0]) < 4.0: near_exit = true
   if near_exit: break
 for n in range(12): game.story.sync(game.sim,1); game.story.finish_dialogue()
 assert(game.sim.chapters.total() == (11 if segment == "completion" else (4 if segment == "annex" else 3)))

func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
  if arg.begins_with("--segment="): segment = arg.trim_prefix("--segment=")
 var compact := "--mobile-preview" in OS.get_cmdline_user_args()
 root.size = Vector2i(844,390) if compact else Vector2i(1280,720)
 game = load("res://main.tscn").instantiate()
 if compact: game.safe_insets_test = Vector4(47,0,47,21)
 root.add_child(game); game.set_process(false)
 await process_frame
 prepare_checkpoint()
 for actor in game.world.actors.values(): actor.free()
 game.world.actors.clear()
 game.refresh(); game.world.show_overview()
 while game.world.transition_active: await process_frame
 game.recording_caption = "Linux · 자동 입력 · 정상 1배속"
 cursor = ReviewCursor.new(); cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
 cursor.z_index = 100; cursor.hide(); game.hud.add_child(cursor)
 var checkpoint: Dictionary = game.sim.snapshot()
 checkpoint.first_day_story = game.story.snapshot()
 FileAccess.open(output.path_join("checkpoint.json"),FileAccess.WRITE).store_string(JSON.stringify(checkpoint,"  "))
 var first_frame := Engine.get_process_frames()
 var duration: int = {"journal":18,"annex":30,"completion":25}[segment]
 var done := {}
 var trace: Array = []
 var last := ""
 var dual := false
 var journal_seen := false
 var restore_ok := false
 var partial_goal_shown := false
 var completed_goal_shown := false
 game.set_process(true)
 while Engine.get_process_frames()-first_frame < duration*24:
  var seconds := float(Engine.get_process_frames()-first_frame)/24.0
  dual = dual or HospitalChapterProgress.simultaneous(game.sim)
  journal_seen = journal_seen or game.journal.visible
  var state := {"seconds":seconds,"day":game.sim.day,"visits":game.sim.chapters.total(),"money":game.sim.money,"expanded":game.sim.expanded,"treating":game.sim.count_state("treatment"),"dual_condition":game.sim.chapters.dual_experienced,"chapter_one_day":game.sim.chapters.chapter_one_day,"chapter_two_day":game.sim.chapters.chapter_two_day,"journal":game.journal.visible,"goals":game.chapter_panel.visible,"dialogue":game.sim.chapters.active}
  var key := str(state.values().slice(1))
  if key != last: trace.append(state); last = key
  if segment == "journal":
   if seconds >= 8 and game.journal.visible and not done.has("close"):
    await click(game.journal.close_button); done.close = true
   elif seconds >= 10 and not done.has("goals"):
    await click(game.goal_ribbon); done.goals = true
  elif segment == "annex":
   if seconds >= 2 and not done.has("outside"):
    await click(game.outside_button); done.outside = true
   elif seconds >= 4 and not done.has("site"):
    var pixel: Vector2 = game.world.camera.unproject_position(Vector3(7,.08,1.8))
    await click_at(pixel*game.size/Vector2(game.viewport.size)); done.site = true
   elif seconds >= 7 and not done.has("purchase"):
    await click(game.confirmation.ok_button); done.purchase = true
   elif seconds >= 10 and not done.has("inside"):
    await click(game.outside_button); done.inside = true
   elif seconds >= 13 and game.story_panel.visible and not done.has("read"):
    await click(game.story_next); done.read = true
   elif seconds >= 14 and not done.has("goals"):
    await click(game.goal_ribbon); done.goals = true
   elif seconds >= 25 and game.chapter_panel.visible and not done.has("close"):
    await click(game.chapter_panel.close_button); done.close = true
   if game.chapter_panel.visible:
    partial_goal_shown = partial_goal_shown or (game.sim.expanded and not game.sim.chapters.dual_experienced)
    completed_goal_shown = completed_goal_shown or game.sim.chapters.dual_experienced
  else:
   if seconds >= 8 and game.journal.visible and not done.has("close"):
    await click(game.journal.close_button); done.close = true
   elif seconds >= 9 and not done.has("goals"):
    await click(game.goal_ribbon); done.goals = true
   elif seconds >= 12 and not done.has("reviewed"):
    await click(game.chapter_panel.close_button); await click(game.next_day_button); done.reviewed = true
   elif seconds >= 14 and not done.has("next"):
    await click(game.journal.next_button)
    if game.capacity_dialog.visible: await click(game.capacity_dialog.start_button)
    done.next = true
   elif seconds >= 17 and not done.has("save"):
    await click(game.pause_button)
    game.store.path = "user://chapter-video-isolated.json"
    game.store.save(game.sim,game.story)
    game.show_notice("4일차 테스트 저장 · 누적 12회\n같은 파일을 다시 불러옵니다.")
    done.save = true
   elif seconds >= 20 and not done.has("restore"):
    var before: Dictionary = game.sim.snapshot()
    restore_ok = game.store.load_into(game.sim,game.story) and JSON.stringify(game.sim.snapshot()) == JSON.stringify(before)
    game.user_paused = game.sim.paused
    game.show_notice("저장 복원 ✓ · 누적 12회\n보유 자금 2700만 · 4일차")
    game.refresh(); done.restore = true
  await process_frame
 game.set_process(false)
 var ok: bool = game.playback_speed == 1.0
 if segment == "journal":
  ok = ok and journal_seen and game.sim.chapters.chapter_one_day == 1 and game.chapter_panel.visible and game.sim.chapters.total() == 4
 elif segment == "annex":
  ok = ok and dual and partial_goal_shown and completed_goal_shown and game.sim.expanded and game.sim.ledger.expansion_expense == 600 and game.world.celebration_count == 1
 else:
  ok = ok and journal_seen and restore_ok and game.sim.day == 4 and game.sim.chapters.total() == 12 and game.sim.chapters.chapter_two_day == 3 and game.sim.money == 2700 and game.sim.ledger.income == 0
 var result := {"passed":ok,"segment":segment,"automatic_input":true,"platform":"Linux Godot 4.6.3 OpenGL llvmpipe","physical_mobile":false,"simulation_speed":1,"fps":24,"recorded_frames":Engine.get_process_frames()-first_frame,"real_canvas_clicks":click_count,"two_rooms_actually_treating":dual,"built_before_dual_goal_shown":partial_goal_shown,"live_dual_goal_shown":completed_goal_shown,"journal_shown":journal_seen,"real_file_restored":restore_ok,"reload_trigger":"actual SaveStore; separate process restart covered by lifecycle tests","checkpoint_prepared_by_normal_simulation":true,"trace":trace}
 FileAccess.open(output.path_join("movie-results.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("CHAPTER MOVIE: ",JSON.stringify(result))
 quit(0 if ok else 1)
