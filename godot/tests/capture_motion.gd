extends "res://tests/test_scene.gd"
func advance_until(state: String) -> void:
 for i in range(7000):
  var p: Dictionary = game.sim.get_patient(1)
  if p.state == state: return
  if p.state == "waiting": game.sim.admit(1)
  elif p.state == "plan_ready": game.sim.assign_plan(1)
  game.sim.tick(1.0/60); game.world.sync(game.sim,1,1.0/60)
 printerr("ERROR: capture state unreachable"); quit(1)
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
 root.size = Vector2i(1280,720)
 game = load("res://main.tscn").instantiate(); root.add_child(game)
 game.set_process(false); await process_frame
 game.selected_id = 1
 game.recording_caption = "동작 검토 · 실제 엔진"
 for state in ["ct_scan","treatment"]:
  advance_until(state)
  for at in [0.0,.45,.9,1.2,1.6]:
   var p: Dictionary = game.sim.get_patient(1)
   while p.elapsed < at:
    game.sim.tick(1.0/60); game.world.sync(game.sim,1,1.0/60)
   game.refresh(); await settle()
   await shot(state+"-"+str(at))
  game.world.focus_patient(game.sim.get_patient(1)); await settle()
  await shot(state+"-detail")
  game.world.show_overview(); await settle()
 quit(0)
