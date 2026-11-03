extends SceneTree
# Actual Godot meshes, materials and camera, without the HUD for visual review.
# This is a rendering capture, not a functional test or a mobile performance test.
var output := ""

func capture(name_text: String) -> void:
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 var result := root.get_texture().get_image().save_png(output.path_join(name_text+".png"))
 if result != OK:
  printerr("ERROR: could not write art capture")
  quit(1)

func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
 if output.is_empty():
  printerr("ERROR: --output-dir is required")
  quit(1)
  return
 root.content_scale_size = Vector2i.ZERO
 root.size = Vector2i(1280,720)
 root.msaa_3d = Viewport.MSAA_2X
 var world = load("res://scripts/world.gd").new()
 root.add_child(world)
 var sim = load("res://scripts/hospital_simulation.gd").new()
 sim.tick(24)
 world.sync(sim,1,0)
 await capture("interior-art")
 world.view_center = Vector3(-3.5,0,-0.3)
 world.close_size = 9.2
 world.frame_camera()
 await capture("reception-art")
 world.show_outside(true)
 world.add_wing()
 await capture("exterior-art")
 print("ART: three actual-engine captures saved; no functional checks performed in this capture script.")
 quit(0)

func _initialize() -> void:
 run.call_deferred()
