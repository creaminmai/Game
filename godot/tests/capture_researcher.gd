extends SceneTree
func run() -> void:
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
 var actor = load("res://scripts/actor.gd").new()
 studio.add_child(actor)
 actor.build(5,true,true,"res://assets/models/researcher.glb")
 actor.apply_palette(actor.body,Color("eee6da"),Color("604c43"),{})
 actor.body.rotation.y = -0.09
 for i in range(4): await process_frame
 await RenderingServer.frame_post_draw
 var error := portrait_view.get_texture().get_image().save_png("res://assets/ui/portrait-researcher.png")
 print("RESEARCHER PORTRAIT: ",error)
 quit(error)
func _initialize() -> void: run.call_deferred()
