extends "res://tests/record_normal.gd"
# Only checkpoint setup is accelerated. Every delivered frame runs at normal 1x.
var segment := "welcome"

func prepare_checkpoint() -> void:
 if segment == "welcome": return
 for step in range(24000):
  game.story.sync(game.sim,1)
  game.story.finish_dialogue()
  for p in game.sim.patients:
   if p.state == "waiting": game.sim.admit(p.id)
   elif p.state == "plan_ready": game.sim.assign_plan(p.id)
  if segment == "ending" and game.sim.expansion_reason().is_empty(): game.sim.purchase_expansion()
  game.sim.tick(1.0/60)
  var first: Dictionary = game.sim.get_patient(1)
  if segment == "completion" and first.state == "treatment" and first.elapsed >= 28.4: return
  if segment == "ending" and game.sim.completed() == 4 and game.sim.count_state("complete") == 3:
   for p in game.sim.patients:
    if p.state == "leaving" and p.route.size() == 1 and p.position.distance_to(p.route[0]) < 1.8: return
 printerr("ERROR: story checkpoint not reached")
 quit(1)

func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
  if arg.begins_with("--segment="): segment = arg.trim_prefix("--segment=")
 root.size = Vector2i(1280,720)
 game = load("res://main.tscn").instantiate()
 root.add_child(game)
 game.set_process(false)
 await process_frame
 prepare_checkpoint()
 if segment != "welcome":
  for actor in game.world.actors.values(): actor.free()
  game.world.actors.clear()
  if segment == "completion": game.selected_id = 1
 game.refresh()
 game.world.show_overview()
 while game.world.transition_active: await process_frame
 game.recording_caption = "자동 입력 · 정상 1배속"
 cursor = ReviewCursor.new()
 cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
 cursor.z_index = 100
 cursor.hide()
 game.hud.add_child(cursor)
 var initial: Dictionary = game.sim.snapshot()
 initial.first_day_story = game.story.snapshot()
 FileAccess.open(output.path_join("checkpoint.json"),FileAccess.WRITE).store_string(JSON.stringify(initial,"  "))
 var first_frame := Engine.get_process_frames()
 var duration := {"welcome":46,"completion":29,"ending":20}[segment] as int
 var dialogue_key := ""
 var next_line_at := 2.4
 var action_at := 0.0
 var done := {}
 var seen := {}
 var trace: Array = []
 var last := ""
 var day_two_clear := true
 var one_speed := true
 game.set_process(true)
 while Engine.get_process_frames()-first_frame < duration*24:
  var elapsed := float(Engine.get_process_frames()-first_frame)/24.0
  var key: String = game.story.active+":"+str(game.story.line)
  if key != dialogue_key:
   dialogue_key = key
   next_line_at = elapsed+2.4
   action_at = elapsed+.8
  if game.story.active != "": seen[game.story.active] = true
  var p: Dictionary = game.sim.get_patient(1)
  var state: String = "%d:%s:%s" % [game.sim.day,p.state,key]
  if state != last:
   trace.append({"video_seconds":elapsed,"day":game.sim.day,"patient_state":p.state,"dialogue":game.story.active,"line":game.story.line,"money":game.sim.money,"paused":game.sim.paused})
   last = state
  if game.story_panel.visible and elapsed >= next_line_at:
   await click(game.story_next)
  elif game.story.active == "" and elapsed >= action_at:
   if segment == "welcome":
    if p.state == "waiting" and game.selected_id != 1 and game.story.seen.get("arrival",false):
     await select_patient(1,true)
    elif p.state == "waiting" and game.selected_id == 1:
     await click(game.action_button); admitted += 1
    elif p.state == "plan_ready":
     await click(game.action_button); plans += 1
   elif segment == "completion" and game.story.seen.get("expansion",false):
    if not done.has("outside"):
     await click(game.outside_button); done.outside = true; action_at = elapsed+2.5
    elif not done.has("confirm"):
     await click(game.expansion_button); done.confirm = true; action_at = elapsed+2.5
    elif not done.has("purchase"):
     await click(game.confirmation.get_ok_button()); done.purchase = true; action_at = elapsed+2.5
    elif not done.has("inside"):
     await click(game.outside_button); done.inside = true
   elif segment == "ending" and game.sim.all_done() and game.story.seen.get("day_end",false):
    await click(game.next_day_button)
  if game.sim.day == 2: day_two_clear = day_two_clear and game.story.active == "" and not game.story_panel.visible
  one_speed = one_speed and game.playback_speed == 1.0
  await process_frame
 game.set_process(false)
 var frames := Engine.get_process_frames()-first_frame
 var ok := one_speed
 if segment == "welcome":
  ok = ok and admitted == 1 and plans == 1 and selected_by_ray == 1
  for id in ["welcome","arrival","admission","ct","plan"]: ok = ok and seen.has(id)
 elif segment == "completion":
  ok = ok and seen.has("complete") and seen.has("expansion") and game.sim.expanded and done.has("inside") and game.sim.get_patient(1).paid and game.sim.money == 500
 else:
  ok = ok and seen.has("day_end") and game.sim.day == 2 and day_two_clear and game.sim.money == 1100
 var result := {"passed":ok,"segment":segment,"automatic_input":true,"checkpoint_prepared_by_normal_simulation":segment != "welcome","simulation_speed":1,"recorded_frames":frames,"fps":24,"real_canvas_clicks":click_count,"dialogues":seen.keys(),"trace":trace,"day_two_without_first_day_dialogue":day_two_clear and game.sim.day == 2,"final_money":game.sim.money,"mobile_performance_test":false}
 FileAccess.open(output.path_join("movie-results.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("MOVIE STORY: ",JSON.stringify(result))
 quit(0 if ok else 1)
