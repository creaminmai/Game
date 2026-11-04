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
 # Preserve the original full-scene comparison camera even if the live HUD
 # camera is adjusted to reserve room for the header.
 world.view_center = Vector3(-0.35,0,-0.5)
 world.camera.position = world.view_center + Vector3(9,25,29)
 world.camera.look_at(world.view_center)
 await capture("interior-art")
 world.view_center = Vector3(-3.5,0,-0.3)
 world.close_size = 9.2
 world.frame_camera()
 world.camera.position = world.view_center + Vector3(9,25,29)
 world.camera.look_at(world.view_center)
 await capture("reception-art")
 # Stable representative framing used on both sides of the art revision.
 # Review isolation only: the live game's patient count and positions are unchanged.
 for id in world.actors:
  var actor = world.actors[id]
  actor.visible = id == 1
  actor.caption.hide()
  actor.selection.hide()
 for label in world.find_children("*", "Label3D", true, false): label.hide()
 world.staff_models[1].hide()
 world.view_center = Vector3(-3.3,0.4,-0.1)
 world.camera.position = world.view_center + Vector3(6,19,28)
 world.camera.look_at(world.view_center)
 world.camera.size = 9.6
 await capture("representative")
 # Detail camera is identical before/after; it reveals face and cushion shading.
 world.view_center = Vector3(-4.55,0.7,3.1)
 world.camera.position = world.view_center + Vector3(6,15,28)
 world.camera.look_at(world.view_center)
 world.camera.size = 5.1
 await capture("reception-detail")
 if "--diagnose" in OS.get_cmdline_user_args():
  for instance in world.find_children("*","MeshInstance3D",true,false):
   for surface in range(instance.mesh.get_surface_count()):
    var material = instance.get_active_material(surface)
    if material is StandardMaterial3D:
     material.ao_enabled = false
     material.vertex_color_use_as_albedo = false
  await capture("diagnose-no-ao")
  for light in world.find_children("*","Light3D",true,false): light.shadow_enabled = false
  await capture("diagnose-no-shadows")
  for instance in world.find_children("*","MeshInstance3D",true,false):
   for surface in range(instance.mesh.get_surface_count()):
    var material = instance.get_active_material(surface)
    if material is StandardMaterial3D: material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
  await capture("diagnose-albedo")
  quit(0)
  return
 world.show_outside(true)
 world.add_wing()
 await capture("exterior-art")
 if "--portraits" in OS.get_cmdline_user_args():
  world.queue_free()
  await process_frame
  var portrait_view := SubViewport.new()
  portrait_view.size = Vector2i(256,256)
  portrait_view.transparent_bg = true
  portrait_view.own_world_3d = true
  portrait_view.msaa_3d = Viewport.MSAA_4X
  portrait_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
  root.add_child(portrait_view)
  var studio := Node3D.new()
  portrait_view.add_child(studio)
  var env := WorldEnvironment.new()
  env.environment = load("res://assets/daylight.tres").duplicate()
  env.environment.background_mode = Environment.BG_CLEAR_COLOR
  studio.add_child(env)
  var light := DirectionalLight3D.new()
  light.rotation_degrees = Vector3(-30,-25,0)
  light.light_color = Color("fff2e2")
  light.light_energy = 0.17
  studio.add_child(light)
  var camera := Camera3D.new()
  camera.projection = Camera3D.PROJECTION_ORTHOGONAL
  camera.size = 1.15
  camera.position = Vector3(0,1.63,4)
  studio.add_child(camera)
  camera.look_at(Vector3(0,1.5,0))
  for id in range(5):
   var actor = load("res://scripts/actor.gd").new()
   studio.add_child(actor)
   actor.build(maxi(1,id),id == 0)
   actor.body.rotation.y = -0.09
   await process_frame
   await process_frame
   await RenderingServer.frame_post_draw
   var portrait_name := "portrait-minji" if id == 0 else "portrait-patient-%d" % id
   if portrait_view.get_texture().get_image().save_png(output.path_join(portrait_name+".png")) != OK:
    printerr("ERROR: portrait capture failed")
    quit(1)
    return
   actor.queue_free()
   await process_frame
 print("ART: five actual-engine captures saved; no functional checks performed in this capture script.")
 quit(0)

func _initialize() -> void:
 run.call_deferred()
