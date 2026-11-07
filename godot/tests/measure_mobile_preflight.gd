extends SceneTree
var game: Control
var output := ""
func _initialize() -> void: run.call_deferred()
func prepare_dual() -> void:
 for step in range(20000):
  for p in game.sim.patients:
   if p.state == "waiting": game.sim.admit(p.id)
   elif p.state == "plan_ready": game.sim.assign_plan(p.id)
  if game.sim.expansion_reason().is_empty(): game.sim.purchase_expansion()
  game.sim.tick(.05)
  if game.sim.count_state("treatment") == 2: break
 game.refresh()
func sample() -> Dictionary:
 var times: Array[float] = []
 var dual_frames := 0
 var previous := Time.get_ticks_usec()
 for n in range(40):
  await RenderingServer.frame_post_draw
  var now := Time.get_ticks_usec()
  times.append((now-previous)/1000.0); previous = now
  if game.sim.count_state("treatment") == 2: dual_frames += 1
 var sum := 0.0
 for ms in times: sum += ms
 var sorted := times.duplicate(); sorted.sort()
 return {"frames":times.size(),"frame_ms":times,"mean_ms":sum/times.size(),"median_ms":sorted[20],"p95_ms":sorted[37],"observed_fps":1000.0*times.size()/sum,"actual_dual_treatment_frames":dual_frames}
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
 root.size = Vector2i(915,412)
 game = load("res://main.tscn").instantiate(); root.add_child(game)
 game.story.disable()
 await RenderingServer.frame_post_draw
 var first_draw_ms := Time.get_ticks_usec()/1000.0
 var normal := await sample()
 game.set_process(false); prepare_dual(); game.set_process(true)
 await RenderingServer.frame_post_draw
 var dual := await sample()
 var report := {"platform":OS.get_name(),"os":OS.get_distribution_name()+" "+OS.get_version(),"processor":OS.get_processor_name(),"renderer":RenderingServer.get_video_adapter_name(),"resolution":[915,412],"build":"Godot 4.6.3 Linux source runtime; Compatibility; no Movie Maker/fixed FPS","first_draw_since_engine_start_ms":first_draw_ms,"normal_operation":normal,"dual_treatment":dual,"mobile_fps":null,"heat":null,"battery":null}
 FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("PERFORMANCE: ",JSON.stringify(report))
 quit()
