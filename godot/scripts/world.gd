class_name HospitalWorld
extends Node3D
const G = preload("res://scripts/geometry.gd")
const Actor = preload("res://scripts/actor.gd")
var interior: Node3D
var exterior: Node3D
var camera: Camera3D
var actors := {}
var beams: Array[MeshInstance3D] = []
var wing_built := false
var outside := false
var ct_light: MeshInstance3D
var exterior_annex: Node3D

func _ready() -> void:
 var env := WorldEnvironment.new()
 var config := Environment.new()
 config.background_mode = Environment.BG_COLOR
 config.background_color = Color("e9e9d9")
 config.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 config.ambient_light_color = Color("fff2d6")
 config.ambient_light_energy = 0.25
 config.tonemap_mode = Environment.TONE_MAPPER_FILMIC
 env.environment = config
 add_child(env)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-52,-28,0)
 sun.light_color = Color("fff0d8")
 sun.light_energy = 0.4
 sun.shadow_enabled = true
 sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
 add_child(sun)
 camera = Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.current = true
 add_child(camera)
 interior = Node3D.new()
 exterior = Node3D.new()
 add_child(interior); add_child(exterior)
 build_interior()
 build_exterior()
 exterior.visible = false
 frame_camera()

func frame_camera() -> void:
 var center := Vector3(2.5 if wing_built else 0,0,0.3)
 if outside: center = Vector3(2 if wing_built else 0,0,0)
 camera.position = center + Vector3(15,22,24)
 camera.look_at(center)
 camera.size = 19.5 if wing_built else 17.0

func floor_room(center: Vector3, color: Color, name_text: String) -> void:
 G.box(interior,center+Vector3(0,-0.15,0),Vector3(6,0.3,5.5),Color("e6dcc4"))
 G.box(interior,center+Vector3(0,0.015,0),Vector3(5.86,0.035,5.36),color)
 for x in range(-2,3):
  G.box(interior,center+Vector3(x,0.04,0),Vector3(0.016,0.014,5.3),Color("dfdfd1"))
 for z in range(-2,3):
  G.box(interior,center+Vector3(0,0.04,z),Vector3(5.8,0.014,0.016),Color("dfdfd1"))
 # Cutaway walls leave the front open and preserve the central corridor doors.
 G.box(interior,center+Vector3(0,0.75,-2.75),Vector3(6,1.5,0.15),Color("e6ebdb"))
 G.box(interior,center+Vector3(0,1.5,-2.75),Vector3(6,0.12,0.2),Color("8bbaae"))
 G.label(interior,name_text,center+Vector3(0,2.25,-2.7),34)

func bed(parent: Node3D, at: Vector3) -> void:
 G.box(parent,at+Vector3(0,0.42,0),Vector3(0.62,0.8,0.7),Color("96b5b0"))
 G.box(parent,at+Vector3(0,0.88,0),Vector3(0.95,0.17,2.5),Color("f8f3e8"))
 G.box(parent,at+Vector3(0,1,0.8),Vector3(0.7,0.1,0.5),Color("c6dbd5"))

func build_interior() -> void:
 G.box(interior,Vector3(0,-0.3,0.2),Vector3(14,0.35,12.4),Color("b8c7b3"))
 G.box(interior,Vector3(0,-0.08,0),Vector3(2,0.15,12),Color("ede5d3"))
 floor_room(Vector3(-4,0,3),Color("f5e8d5"),"01  대기 · 접수")
 floor_room(Vector3(-4,0,-3),Color("dceae5"),"02  CT 촬영")
 floor_room(Vector3(4,0,-3),Color("e8e6d8"),"03  계획실")
 floor_room(Vector3(4,0,3),Color("d7e7e3"),"04  치료실")
 for id in range(1,5):
  var at := Vector3(-4.5+((id-1)%2)*1.3,0,2.3+floori((id-1)/2.0)*1.5)
  G.box(interior,at+Vector3(0,0.3,0),Vector3(0.85,0.55,0.8),Color("79ada5"))
  G.box(interior,at+Vector3(0,0.65,-0.35),Vector3(0.85,0.55,0.14),Color("79ada5"))
 G.box(interior,Vector3(-5,0.65,5.1),Vector3(2.7,1.2,0.65),Color("c9a786"))
 G.label(interior,"햇살 안내",Vector3(-5,1.2,5.2),23)
 var ct := Node3D.new()
 interior.add_child(ct)
 ct.position = Vector3(-4,0,-2.8)
 bed(ct,Vector3.ZERO)
 var torus := TorusMesh.new()
 torus.inner_radius = 0.63
 torus.outer_radius = 1.05
 var gantry := G.shape(ct,torus,Vector3(0,1.45,-0.65),Color("faf8ef"))
 gantry.rotation_degrees.x = 90
 G.box(ct,Vector3(0,0.55,-0.7),Vector3(2.25,1,0.7),Color("f6f2e8"))
 ct_light = G.box(ct,Vector3(0,2.18,-0.65),Vector3(0.8,0.08,0.12),Color("74bbaa"))
 G.box(interior,Vector3(4.8,0.6,-4),Vector3(2.8,1.1,1.15),Color("c7ac8e"))
 for x in [4.2,5.2]:
  G.box(interior,Vector3(x,1.55,-4.1),Vector3(0.8,0.65,0.1),Color("617f7d"))
  G.box(interior,Vector3(x,1.55,-4.03),Vector3(0.68,0.5,0.015),Color("98c4bd"))
 staff(Vector3(4.6,0.05,-3.1),"박 선생")
 staff(Vector3(-5,0.05,5.8),"민지")
 build_linac(Vector3(4,0,3))
 for at in [Vector3(-6,0,-4.8),Vector3(-6,0,0.8),Vector3(6.1,0,-4.8)]: G.plant(interior,at)
 # Window panels on the rear wall, rendered as solid blue glass for reliable mobile compatibility.
 for x in [-5.5,-3.8,3,5]:
  G.box(interior,Vector3(x,1.0,-5.64),Vector3(1.15,0.8,0.04),Color("b0d6d7"))

func staff(at: Vector3, caption_text: String) -> void:
 var a := Actor.new()
 interior.add_child(a)
 a.position = at
 a.build(1,true)
 a.caption.visible = true
 a.caption.text = caption_text

func build_linac(at: Vector3) -> void:
 var node := Node3D.new()
 interior.add_child(node)
 node.position = at
 bed(node,Vector3.ZERO)
 G.box(node,Vector3(0,1,-1.75),Vector3(1.3,1.9,0.8),Color("f5f5e9"))
 var wheel := G.cylinder(node,Vector3(0,1.65,-1.65),0.92,0.35,Color("8dbdb4"))
 wheel.rotation_degrees.x = 90
 G.box(node,Vector3(0,2.25,-0.85),Vector3(0.62,0.55,1.7),Color("f7f4e9"))
 G.box(node,Vector3(0,2.0,-0.12),Vector3(0.8,0.4,0.65),Color("9bc7bd"))
 var beam := G.cylinder(node,Vector3(0,1.47,-0.12),0.08,0.7,Color("72ddc3"))
 beam.visible = false
 beams.append(beam)

func build_exterior() -> void:
 G.box(exterior,Vector3(1,-0.3,0),Vector3(22,0.4,17),Color("a9bf94"))
 G.box(exterior,Vector3(0,-0.02,6),Vector3(22,0.1,2.4),Color("d3c8b3"))
 G.box(exterior,Vector3(0,1.5,0),Vector3(9,3,6),Color("f3e8d2"))
 G.box(exterior,Vector3(0,3.1,0),Vector3(9.6,0.35,6.6),Color("579b91"))
 G.box(exterior,Vector3(0,1,3.06),Vector3(1.5,2,0.12),Color("91bdbb"))
 for x in [-3,-1.5,1.5,3]:
  G.box(exterior,Vector3(x,1.9,3.05),Vector3(0.9,1,0.1),Color("9cc8cb"))
 G.label(exterior,"햇살병원  +",Vector3(0,3.9,2.5),48)
 G.label(exterior,"치료별관 예정지",Vector3(7,0.4,1),32)
 for x in [-6, -4, 5, 9]: G.plant(exterior,Vector3(x,0,4.4))
 exterior_annex = Node3D.new()
 exterior.add_child(exterior_annex)
 exterior_annex.visible = false
 G.box(exterior_annex,Vector3(7,1.3,0),Vector3(4,2.6,5),Color("f4e6cd"))
 G.box(exterior_annex,Vector3(7,2.8,0),Vector3(4.4,0.35,5.4),Color("579b91"))
 G.box(exterior_annex,Vector3(4.8,1.0,1),Vector3(1,2,1.8),Color("d2e5dc"))
 G.label(exterior_annex,"치료별관",Vector3(7,3.3,2.3),34)
 for x in [6,7.5]: G.box(exterior_annex,Vector3(x,1.5,2.55),Vector3(0.8,1,0.1),Color("9cc8cb"))

func add_wing() -> void:
 if wing_built: return
 wing_built = true
 floor_room(Vector3(10,0,3),Color("d7e7e3"),"05  별관 · 2번 치료실")
 G.box(interior,Vector3(7,0,5.2),Vector3(2.5,0.12,1.2),Color("ede5d3"))
 build_linac(Vector3(10,0,3))
 staff(Vector3(11.8,0,1),"별관 치료사")
 G.plant(interior,Vector3(12,0,4.8))
 exterior_annex.visible = true
 frame_camera()

func show_outside(value: bool) -> void:
 outside = value
 interior.visible = not value
 exterior.visible = value
 frame_camera()

func sync(sim: HospitalSimulation, selected: int, delta: float) -> void:
 if sim.expanded: add_wing()
 for id in actors.keys():
  if sim.get_patient(id).is_empty():
   actors[id].queue_free()
   actors.erase(id)
 for p in sim.patients:
  if not actors.has(p.id):
   var a := Actor.new()
   interior.add_child(a)
   a.build(p.id)
   actors[p.id] = a
  actors[p.id].sync(p, p.id == selected, delta)
 ct_light.material_override.albedo_color = Color("75e0c0") if sim.ct_owner != -1 else Color("74bbaa")
 for i in range(beams.size()):
  var p := sim.get_patient(sim.treatment_owners[i])
  beams[i].visible = not p.is_empty() and p.state == "treatment"

func pick(point: Vector2) -> int:
 var origin := camera.project_ray_origin(point)
 var direction := camera.project_ray_normal(point)
 var query := PhysicsRayQueryParameters3D.create(origin,origin+direction*100)
 query.collide_with_areas = true
 query.collide_with_bodies = false
 var hit := get_world_3d().direct_space_state.intersect_ray(query)
 if hit.is_empty(): return -1
 return int(hit.collider.get_meta("patient_id",-1))
