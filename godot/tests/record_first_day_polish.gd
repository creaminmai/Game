extends "res://tests/record_normal.gd"
# Only the initial checkpoint uses accelerated normal simulation. All delivered
# frames are uninterrupted 1x engine frames; clicks are automated, not manual.
var segment := "welcome"

func prepare_checkpoint() -> void:
 if segment == "welcome": return
 for step in range(24000):
  game.story.sync(game.sim,1)
  game.story.finish_dialogue()
  for p in game.sim.patients:
   if p.state == "waiting": game.sim.admit(p.id)
   elif p.state == "plan_ready": game.sim.assign_plan(p.id)
  if segment == "journal" and game.sim.expansion_reason().is_empty(): game.sim.purchase_expansion()
  game.sim.tick(1.0/60)
  if segment == "expansion" and game.sim.get_patient(1).paid: break
  if segment == "journal" and game.sim.completed() == 4 and game.sim.count_state("complete") == 3:
   var ready := false
   for p in game.sim.patients:
    if p.state == "leaving" and p.route.size() == 1 and p.position.distance_to(p.route[0]) < 1.8: ready = true
   if ready: break
 if segment == "expansion" and (not game.sim.get_patient(1).paid or game.sim.expanded):
  printerr("ERROR: expansion checkpoint not reached"); quit(1)
 # The preceding story has already been acknowledged at this checkpoint.
 for n in range(12): game.story.sync(game.sim,1); game.story.finish_dialogue()

func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
  if arg.begins_with("--segment="): segment = arg.trim_prefix("--segment=")
 root.size = Vector2i(1280,720)
 game = load("res://main.tscn").instantiate()
 root.add_child(game); game.set_process(false)
 await process_frame
 prepare_checkpoint()
 if segment != "welcome":
  for actor in game.world.actors.values(): actor.free()
  game.world.actors.clear()
 game.refresh()
 game.world.show_overview()
 while game.world.transition_active: await process_frame
 game.recording_caption = "자동 입력 시연 · 정상 1배속"
 cursor = ReviewCursor.new()
 cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
 cursor.z_index = 100; cursor.hide()
 game.hud.add_child(cursor)
 var initial: Dictionary = game.sim.snapshot()
 initial.first_day_story = game.story.snapshot()
 FileAccess.open(output.path_join("checkpoint.json"),FileAccess.WRITE).store_string(JSON.stringify(initial,"  "))
 var start_frame := Engine.get_process_frames()
 var duration: int = {"welcome":24,"expansion":30,"journal":18}[segment]
 var dialogue_key := ""
 var next_line_at := 3.0
 var action_at := 0.0
 var done := {}
 var seen := {}
 var trace: Array = []
 var last := ""
 var one_speed := true
 var dual := false
 var purchase_center := Vector3.ZERO
 var purchase_zoom := 0.0
 var purchase_stable := true
 var first_admission_at := -1.0
 var journal_seen := false
 var second_day_clear := true
 game.set_process(true)
 while Engine.get_process_frames()-start_frame < duration*24:
  var elapsed := float(Engine.get_process_frames()-start_frame)/24.0
  var key: String = game.story.active+":"+str(game.story.line)
  if key != dialogue_key:
   dialogue_key = key
   next_line_at = elapsed+3.0 # Automated reader timing; the game has no deadline.
   action_at = elapsed+.8
  if game.story.active != "": seen[game.story.active] = true
  dual = dual or game.sim.count_state("treatment") == 2
  journal_seen = journal_seen or game.journal.visible
  var p: Dictionary = game.sim.get_patient(1)
  var state: String = "%d:%s:%s:%s:%s:%d:%s" % [game.sim.day,p.state,key,game.outside,game.sim.expanded,game.sim.count_state("treatment"),game.journal.visible]
  if state != last:
   trace.append({"video_seconds":elapsed,"day":game.sim.day,"patient_state":p.state,"dialogue":game.story.active,"line":game.story.line,"money":game.sim.money,"outside":game.outside,"expanded":game.sim.expanded,"treating":game.sim.count_state("treatment"),"journal":game.journal.visible})
   last = state
  if segment == "welcome":
   if game.story_panel.visible and elapsed >= next_line_at:
    await click(game.story_next)
   elif game.story.active == "" and elapsed >= action_at:
    if p.state == "waiting" and game.selected_id != 1:
     await select_patient(1,true); action_at = elapsed+1.0
    elif p.state == "waiting" and game.selected_id == 1:
     await click(game.action_button); admitted += 1; first_admission_at = elapsed
  elif segment == "expansion":
   if elapsed >= 1 and not done.has("outside"):
    await click(game.outside_button); done.outside = true
   elif elapsed >= 4 and not done.has("site"):
    var pixel: Vector2 = game.world.camera.unproject_position(Vector3(7,.08,1.8))
    await click_at(pixel*game.size/Vector2(game.viewport.size)); done.site = true
   elif elapsed >= 8 and not done.has("purchase"):
    purchase_center = game.world.view_center; purchase_zoom = game.world.camera.size
    await click(game.confirmation.get_ok_button()); done.purchase = true
   elif elapsed >= 12 and not done.has("inside"):
    await click(game.outside_button); done.inside = true
   if elapsed >= 8.3 and elapsed < 11.8:
    purchase_stable = purchase_stable and game.world.view_center.distance_to(purchase_center) < .001 and absf(game.world.camera.size-purchase_zoom) < .001
  else:
   if elapsed >= 7 and game.journal.visible and not done.has("next"):
    await click(game.journal.next_button); done.next = true
  if game.sim.day == 2: second_day_clear = second_day_clear and game.story.active == "" and not game.story_panel.visible and not game.journal.visible
  one_speed = one_speed and game.playback_speed == 1.0
  await process_frame
 game.set_process(false)
 var frames := Engine.get_process_frames()-start_frame
 var ok := one_speed
 if segment == "welcome":
  ok = ok and admitted == 1 and selected_by_ray == 1 and seen.has("welcome") and seen.has("arrival") and not seen.has("admission") and first_admission_at < 12
 elif segment == "expansion":
  ok = ok and done.has("inside") and game.sim.expanded and game.world.celebration_count == 1 and dual and purchase_stable and game.sim.ledger.expansion_expense == 600
 else:
  ok = ok and journal_seen and game.sim.day == 2 and second_day_clear and game.sim.money == 1100 and game.sim.ledger.income == 0 and game.sim.ledger.expansion_expense == 0
 var result := {"passed":ok,"segment":segment,"automatic_input":true,"checkpoint_prepared_by_normal_simulation":segment != "welcome","simulation_speed":1,"recorded_frames":frames,"fps":24,"real_canvas_clicks":click_count,"dialogues":seen.keys(),"first_admission_video_seconds":first_admission_at,"trace":trace,"two_rooms_treating":dual,"purchase_camera_stable":purchase_stable,"journal_shown":journal_seen,"day_two_without_first_day_dialogue":second_day_clear and game.sim.day == 2,"final_money":game.sim.money,"daily_ledger":game.sim.ledger.snapshot(),"mobile_performance_test":false}
 FileAccess.open(output.path_join("movie-results.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("MOVIE FIRST DAY POLISH: ",JSON.stringify(result))
 quit(0 if ok else 1)
