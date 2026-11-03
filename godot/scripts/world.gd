class_name HospitalWorld
extends Node3D
const G = preload("res://scripts/geometry.gd")
const F = preload("res://scripts/furnishings.gd")
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
var expansion_sign: Label3D

func _ready() -> void:
 var env := WorldEnvironment.new()
 var config := Environment.new()
 config.background_mode = Environment.BG_COLOR
 config.background_color = Color("d9ddc9")
 config.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 config.ambient_light_color = Color("fff2d6")
 config.ambient_light_energy = 0.28
 config.tonemap_mode = Environment.TONE_MAPPER_LINEAR
 env.environment = config
 add_child(env)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-52,-28,0)
 sun.light_color = Color("fff3df")
 sun.light_energy = 0.22
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
 camera.position = center + Vector3(10,21,27)
 camera.look_at(center)
 camera.size = 25.0 if outside else (19.5 if wing_built else 17.0)

func floor_room(center: Vector3, color: Color, name_text: String) -> void:
 G.rounded_box(interior,center+Vector3(0,-0.16,0),Vector3(6,0.3,5.5),Color("b7b09b"),0.08)
 for x in range(6):
  for z in range(6):
   var tint := color.darkened(0.025*((x+z)%3))
   G.box(interior,center+Vector3(-2.5+x,0.015,-2.3+z*0.91),Vector3(0.985,0.05,0.895),tint)
 G.box(interior,center+Vector3(0,1.05,-2.75),Vector3(6,2.1,0.16),Color("ddd6c4"))
 G.box(interior,center+Vector3(0,0.55,-2.65),Vector3(5.9,1.05,0.08),Color("b79975"))
 for i in range(25):
  G.box(interior,center+Vector3(-2.85+i*0.235,0.55,-2.59),Vector3(0.018,1.05,0.025),Color("9d805e"))
 G.box(interior,center+Vector3(0,1.1,-2.57),Vector3(6,0.09,0.12),Color("c9af87"))
 G.box(interior,center+Vector3(0,2.13,-2.75),Vector3(6.05,0.12,0.22),Color("ece3cf"))
 for x in [-2.1,2.1]: F.wall_light(interior,center+Vector3(x,1.82,-2.55))
 G.label(interior,name_text,center+Vector3(0,2.55,-2.7),30)

func bed(parent: Node3D, at: Vector3) -> void:
 F.bed(parent,at)

func build_interior() -> void:
 G.rounded_box(interior,Vector3(0,-0.34,0.2),Vector3(14.4,0.4,12.5),Color("acac8a"),0.18)
 G.box(interior,Vector3(0,-0.08,0),Vector3(2,0.15,12),Color("d2c5a8"))
 for z in range(12): G.box(interior,Vector3(0,0.025,-5.5+z),Vector3(1.94,0.045,0.97),Color("e2d7bf") if z%2 else Color("d9ccb1"))
 floor_room(Vector3(-4,0,3),Color("d4bf9e"),"대기 · 접수")
 floor_room(Vector3(-4,0,-3),Color("bec9bd"),"CT 촬영")
 floor_room(Vector3(4,0,-3),Color("d4c8ae"),"계획실")
 floor_room(Vector3(4,0,3),Color("c2cfc1"),"치료실")
 # Chairs sit behind the waiting points so standing patient meshes remain unobstructed.
 for id in range(1,5):
  var at := Vector3(-4.5+((id-1)%2)*1.3,0,1.85+floori((id-1)/2.0)*1.5)
  F.chair(interior,at)
 G.cylinder(interior,Vector3(-5.8,0.6,3.1),0.48,0.12,Color("bca078"))
 G.cylinder(interior,Vector3(-5.8,0.3,3.1),0.08,0.6,Color("987953"))
 G.plant(interior,Vector3(-5.8,0.68,3.1))
 # Rounded wood reception counter with vertical slats and the sunshine emblem.
 G.rounded_box(interior,Vector3(-4.8,0.65,5.05),Vector3(3.2,1.2,0.8),Color("b58c60"),0.23)
 for i in range(22): G.box(interior,Vector3(-6.15+i*0.13,0.65,5.46),Vector3(0.04,0.9,0.035),Color("d1b58b"))
 G.rounded_box(interior,Vector3(-4.8,1.28,5.05),Vector3(3.35,0.15,0.94),Color("e8dfcb"),0.07)
 G.logo(interior,Vector3(-4.8,0.75,5.51),0.85)
 F.monitor(interior,Vector3(-5.6,1.36,5.1))
 G.plant(interior,Vector3(-3.5,1.36,5.05))
 var ct := Node3D.new()
 interior.add_child(ct)
 ct.position = Vector3(-4,0,-2.8)
 bed(ct,Vector3.ZERO)
 G.shadow(ct,Vector3(0,0.055,-0.8),Vector2(3,2))
 G.rounded_box(ct,Vector3(0,0.45,-0.85),Vector3(2.5,0.9,0.85),Color("ced6cb"),0.22)
 G.ring(ct,Vector3(0,1.55,-0.85),0.65,1.25,Color("e1e1d3"))
 G.ring(ct,Vector3(0,1.55,-0.52),0.66,0.78,Color("7aa89b"))
 G.ring(ct,Vector3(0,1.55,-0.48),1.13,1.22,Color("b5c6ba"))
 ct_light = G.rounded_box(ct,Vector3(0,2.61,-0.47),Vector3(0.48,0.09,0.08),Color("74bbaa"),0.03)
 for x in [-0.98,0.98]:
  G.rounded_box(ct,Vector3(x,1.32,-0.37),Vector3(0.25,0.32,0.08),Color("b0bdb4"),0.03)
 F.cart(interior,Vector3(-5.7,0,-1.7))
 F.cabinet(interior,Vector3(-2.2,0,-5.15),1.35)
 F.monitor(interior,Vector3(-2.2,1.17,-5.15))
 G.plant(interior,Vector3(-6.1,0,-4.5))
 F.cabinet(interior,Vector3(4.75,0,-4.65),3.3)
 for x in [4.0,5.3]: F.monitor(interior,Vector3(x,1.18,-4.55),x>5)
 F.bookshelf(interior,Vector3(2.05,1.1,-5.3))
 G.plant(interior,Vector3(6.0,1.18,-4.65))
 staff(Vector3(4.8,0.05,-3.4),"박 선생")
 staff(Vector3(-5,0.05,5.85),"민지")
 build_linac(Vector3(4,0,3))
 F.cabinet(interior,Vector3(6.1,0,1),1.35)
 F.cart(interior,Vector3(5.9,0,4.5))
 for at in [Vector3(-6.3,0,0.9),Vector3(6.2,0,-2.4)]: G.plant(interior,at)
 # Back windows, framed in wood; small panes retain warm interior contrast.
 for x in [-5.8,-2.1,4.8]:
  G.rounded_box(interior,Vector3(x,1.5,-5.62),Vector3(1.25,0.94,0.08),Color("a98c68"),0.03)
  G.box(interior,Vector3(x,1.5,-5.56),Vector3(1.08,0.77,0.025),Color("99b9b3"))
  G.box(interior,Vector3(x,1.5,-5.53),Vector3(0.045,0.8,0.03),Color("ddd0b5"))
 # Left glazing catches daylight; the camera-facing edge stays cut away.
 G.box(interior,Vector3(-7,0.22,0.1),Vector3(0.18,0.44,11.8),Color("b69870"))
 G.box(interior,Vector3(-7,2.4,0.1),Vector3(0.2,0.14,11.8),Color("dcd1b8"))
 for i in range(8):
  var z := -5.25+i*1.5
  G.box(interior,Vector3(-7,1.3,z),Vector3(0.18,2.2,0.09),Color("b69870"))
  if i < 7:
   var glass := G.box(interior,Vector3(-7,1.4,z+0.75),Vector3(0.035,1.85,1.4),Color(0.64,0.79,0.76,0.22))
   glass.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
   glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 G.box(interior,Vector3(0,1.15,-5.8),Vector3(1.95,2.3,0.16),Color("b7976c"))
 for x in [-0.48,0.48]:
  G.box(interior,Vector3(x,1.2,-5.69),Vector3(0.83,2,0.04),Color("e0d1b4"))
  G.box(interior,Vector3(x,1.55,-5.66),Vector3(0.52,0.76,0.02),Color("9bb6aa"))
  G.box(interior,Vector3(x*0.45,0.95,-5.62),Vector3(0.04,0.25,0.03),Color("a38c64"))
 for side in [-1,1]:
  for z in [-4.2,0.9]:
   G.box(interior,Vector3(side*1.02,0.4,z),Vector3(0.14,0.8,1.4),Color("d7c8a9"))
   G.rounded_box(interior,Vector3(side*1.02,0.85,z),Vector3(0.18,0.1,1.5),Color("af8a5f"),0.04)
 G.logo(interior,Vector3(-4,1.6,0.45),0.8)
 for z in [-4.5,-2,1,4.5]: G.flowers(interior,Vector3(-7.6,0,z),Color("d395a6"))

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
 G.shadow(node,Vector3(0,0.06,-1.3),Vector2(2.8,2.6))
 G.rounded_box(node,Vector3(0,0.9,-1.75),Vector3(1.6,1.8,0.95),Color("d1d8cb"),0.22)
 G.ring(node,Vector3(0,1.55,-1.55),0.7,1.2,Color("b4c9bf"))
 # Curved overhead arm modeled as a rounded assembly, with a collimator head.
 G.rounded_box(node,Vector3(0,2.25,-1.25),Vector3(0.85,0.85,0.95),Color("dfe1d5"),0.28)
 G.rounded_box(node,Vector3(0,2.62,-0.62),Vector3(0.85,0.55,1.45),Color("dfe1d5"),0.24)
 G.rounded_box(node,Vector3(0,2.35,0.0),Vector3(1.05,0.55,0.85),Color("d6dfd2"),0.18)
 G.rounded_box(node,Vector3(0,2.1,0),Vector3(0.85,0.09,0.65),Color("689c8c"),0.03)
 var beam := G.cylinder(node,Vector3(0,1.66,0),0.055,0.8,Color("7bcbb3"))
 beam.visible = false
 beams.append(beam)

func exterior_window(parent: Node3D, at: Vector3, width: float = 1.1) -> void:
 G.rounded_box(parent,at,Vector3(width+0.16,1.25,0.1),Color("ab8b61"),0.03)
 G.box(parent,at+Vector3(0,0,0.065),Vector3(width,1.08,0.035),Color("92b5ac"))
 for x in [-width*0.25,width*0.25]: G.box(parent,at+Vector3(x,-0.24,0.09),Vector3(width*0.43,0.5,0.012),Color("d8c69a"))
 G.box(parent,at+Vector3(0,0,0.1),Vector3(0.055,1.1,0.04),Color("e4d8bd"))
 G.box(parent,at+Vector3(0,0,0.1),Vector3(width,0.055,0.04),Color("e4d8bd"))

func tree(at: Vector3, flowering: bool = false) -> void:
 G.shadow(exterior,at+Vector3(0,0.055,0),Vector2(3,2.6))
 G.cylinder(exterior,at+Vector3(0,1,0),0.16,2,Color("967c55"))
 for i in range(5):
  var angle := i*2.4
  var color := Color("d5a0b1") if flowering else Color("7e985e")
  G.oval(exterior,at+Vector3(cos(angle)*0.5,2.25+(i%2)*0.45,sin(angle)*0.45),Vector3(1.45,1.5,1.35),color.lightened((i%3)*0.06))

func build_exterior() -> void:
 G.rounded_box(exterior,Vector3(1,-0.3,0),Vector3(22,0.4,17),Color("a7b68a"),0.35)
 G.box(exterior,Vector3(1,-0.06,5.3),Vector3(22,0.12,3.1),Color("c9bea6"))
 G.box(exterior,Vector3(1,0,7.2),Vector3(22,0.08,1.4),Color("919a8f"))
 for x in range(-9,12,2): G.box(exterior,Vector3(x,0.05,7.2),Vector3(0.8,0.012,0.07),Color("eee3c9"))
 for z in range(5): G.box(exterior,Vector3(0,0.06,6.64+z*0.25),Vector3(1.2,0.014,0.12),Color("eee3c9"))
 G.rounded_box(exterior,Vector3(0,2.2,0),Vector3(9,4.4,6),Color("dcd3ba"),0.1)
 G.box(exterior,Vector3(0,2.25,3.08),Vector3(9.1,0.18,0.14),Color("c1a77d"))
 # Wood facade and pitched teal roof.
 for x in [-4.25,-0.95,0.95,4.25]: G.box(exterior,Vector3(x,2.2,3.07),Vector3(0.25,4.5,0.15),Color("a9865c"))
 for side in [-1,1]:
  var roof := G.box(exterior,Vector3(side*2.35,4.83,0),Vector3(4.9,0.2,6.65),Color("578b82"))
  roof.rotation.z = side*-0.19
  for z in range(13):
   var seam := G.box(exterior,Vector3(side*2.35,4.95,-3.1+z*0.52),Vector3(4.9,0.035,0.045),Color("82aaa0"))
   seam.rotation.z = side*-0.19
 for x in [-3.2,-1.8,1.8,3.2]:
  for y in [1.1,3.35]: exterior_window(exterior,Vector3(x,y,3.1))
 G.rounded_box(exterior,Vector3(0,1.1,3.1),Vector3(1.6,2.15,0.16),Color("8aafaa"),0.04)
 G.box(exterior,Vector3(0,1.1,3.22),Vector3(0.05,2.15,0.04),Color("c2b797"))
 G.rounded_box(exterior,Vector3(0,2.4,3.7),Vector3(3,0.24,1.7),Color("578b82"),0.1)
 G.logo(exterior,Vector3(0,3.65,3.2),1.7)
 G.label(exterior,"햇살병원",Vector3(0,5.9,0),42)
 for i in range(3): G.box(exterior,Vector3(0,0.1+i*0.1,4.75-i*0.3),Vector3(2.8,0.2,0.65),Color("ddd0b5"))
 for x in [-1.55,1.55]:
  for z in [4.1,4.9]: G.cylinder(exterior,Vector3(x,0.55,z),0.035,0.85,Color("b0b9aa"))
  G.box(exterior,Vector3(x,1,4.5),Vector3(0.06,0.06,1),Color("b0b9aa"))
 for x in [-7,-4.5,4.5,10]:
  G.cylinder(exterior,Vector3(x,1.1,5.7),0.055,2.2,Color("706c53"))
  G.rounded_box(exterior,Vector3(x,2.25,5.7),Vector3(0.3,0.42,0.3),Color("edd2a0"),0.05)
  G.box(exterior,Vector3(x,2.5,5.7),Vector3(0.4,0.08,0.4),Color("706c53"))
 for at in [Vector3(-7,0,-4),Vector3(-8,0,1),Vector3(10,0,-5),Vector3(11,0,2)]: tree(at,at.x<0)
 for x in [-6,-3,3,6,9]: G.flowers(exterior,Vector3(x,0,4.5))
 expansion_sign = G.label(exterior,"치료별관 예정지",Vector3(7,0.4,1),32)
 exterior_annex = Node3D.new()
 exterior.add_child(exterior_annex)
 exterior_annex.visible = false
 G.rounded_box(exterior_annex,Vector3(7,1.45,0),Vector3(4,2.9,5),Color("dfd6bd"),0.1)
 G.rounded_box(exterior_annex,Vector3(7,3.0,0),Vector3(4.4,0.3,5.4),Color("578b82"),0.08)
 for x in [5.6,6.6,7.6,8.6]: G.box(exterior_annex,Vector3(x,3.18,0),Vector3(0.04,0.035,5.2),Color("82aaa0"))
 G.rounded_box(exterior_annex,Vector3(4.8,1.1,1),Vector3(1.3,2.2,1.8),Color("a2bfb3"),0.06)
 G.box(exterior_annex,Vector3(4.8,2.25,1),Vector3(1.5,0.1,2),Color("578b82"))
 G.label(exterior_annex,"치료별관",Vector3(7,3.7,2.3),30)
 for x in [6,7.5]: exterior_window(exterior_annex,Vector3(x,1.5,2.55))

func add_wing() -> void:
 if wing_built: return
 wing_built = true
 floor_room(Vector3(10,0,3),Color("d7e7e3"),"05  별관 · 2번 치료실")
 G.box(interior,Vector3(7,0,5.2),Vector3(2.5,0.12,1.2),Color("ede5d3"))
 build_linac(Vector3(10,0,3))
 staff(Vector3(11.8,0,1),"별관 치료사")
 G.plant(interior,Vector3(12,0,4.8))
 exterior_annex.visible = true
 expansion_sign.visible = false
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
