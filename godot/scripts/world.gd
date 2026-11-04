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
var expansion_sign: Label3D
var view_center := Vector3(-0.35,0.7,-0.5)
var close_size := 12.7
var overview_mode := false
var auto_frame := true
var play_area := Rect2()
var focus_patient_data: Dictionary = {}
var focus_signature := ""
var framing_bounds := AABB()
var staff_models: Array[HospitalActor] = []

func _ready() -> void:
 var env := WorldEnvironment.new()
 # Compatibility/WebGL uses calibrated linear output. Neutral reflection and
 # ambient are independent from the warm directional daylight and baked AO.
 env.environment = load("res://assets/daylight.tres")
 add_child(env)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-42,-62,0)
 sun.light_color = Color("fff3e6")
 sun.light_energy = 0.14
 sun.shadow_enabled = true
 sun.shadow_bias = 4.0
 sun.shadow_normal_bias = 2.0
 sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
 sun.directional_shadow_max_distance = 75.0
 sun.shadow_blur = 3.0
 sun.shadow_opacity = 0.48
 add_child(sun)
 var fill := DirectionalLight3D.new()
 fill.rotation_degrees = Vector3(-35,140,0)
 fill.light_color = Color("e8f1ff")
 fill.light_energy = 0.055
 add_child(fill)
 camera = Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.far = 100.0
 camera.current = true
 add_child(camera)
 interior = Node3D.new()
 exterior = Node3D.new()
 add_child(interior); add_child(exterior)
 build_interior()
 build_exterior()
 exterior.visible = false
 get_viewport().size_changed.connect(frame_camera)
 frame_camera()

func set_play_area(rect: Rect2) -> void:
 if play_area.is_equal_approx(rect): return
 play_area = rect
 frame_camera()

func subject_bounds() -> AABB:
 if outside: return AABB(Vector3(-9,0,-5.5),Vector3(21,5.8,13.5))
 if not overview_mode and focus_patient_data.is_empty():
  return AABB(Vector3(-6.5,0,-5.55),Vector3(7.1,3.2,11.3))
 if overview_mode:
  return AABB(Vector3(-7.1,0,-5.85),Vector3(20.3 if wing_built else 14.2,3.2,11.9))
 var p := focus_patient_data
 match p.state:
  "waiting", "ct_queue", "walk_ct":
   return AABB(Vector3(-6.5,0,-5.55),Vector3(7.1,3.2,11.3))
  "ct_scan": return AABB(Vector3(-6.4,0,-5.6),Vector3(5.5,3.2,6.2))
  "walk_plan": return AABB(Vector3(-6.2,0,-5.55),Vector3(12.8,3.2,5.7))
  "plan_ready", "plan_queue", "planning":
   return AABB(Vector3(1.0,0,-5.5),Vector3(5.6,3.2,5.2))
  "treatment_queue":
   # Include both the waiting patient and the occupied treatment devices.
   return AABB(Vector3(1.0,0,-5.5),Vector3(11.7 if wing_built else 5.8,3.2,11.3))
  "walk_treatment":
   return AABB(Vector3(0,0,-4.9),Vector3(12.7 if p.room == 1 else 6.8,3.2,10.6))
  "treatment": return AABB(Vector3(1.25+p.room*6,0,0.0),Vector3(5.55,3.2,5.8))
 return AABB(Vector3(-7.1,0,-5.85),Vector3(20.3 if wing_built else 14.2,3.2,12.9))

func frame_camera() -> void:
 if not is_instance_valid(camera): return
 camera.position = view_center+Vector3(8,21,29)
 camera.look_at(view_center)
 if not auto_frame:
  camera.size = close_size
  return
 var pixels := get_viewport().get_visible_rect().size
 var safe := play_area if play_area.has_area() else Rect2(Vector2.ZERO,pixels)
 framing_bounds = subject_bounds()
 var basis_right := camera.global_basis.x
 var basis_up := camera.global_basis.y
 var lo := Vector2(INF,INF)
 var hi := Vector2(-INF,-INF)
 for corner in range(8):
  var point := framing_bounds.get_endpoint(corner)
  var projection := Vector2(point.dot(basis_right),point.dot(basis_up))
  lo = lo.min(projection); hi = hi.max(projection)
 var span := hi-lo
 camera.size = maxf(span.y*pixels.y/safe.size.y,span.x*pixels.y/safe.size.x)*1.04
 var middle := framing_bounds.get_center()
 var displacement := safe.get_center()-pixels*0.5
 view_center = middle-basis_right*displacement.x*camera.size/pixels.y+basis_up*displacement.y*camera.size/pixels.y
 camera.position = view_center+Vector3(8,21,29)
 camera.look_at(view_center)
 close_size = camera.size

func zoom_by(factor: float) -> void:
 auto_frame = false
 overview_mode = false
 close_size = clampf(camera.size*factor,8.0,50.0)
 frame_camera()

func show_overview() -> void:
 overview_mode = true
 auto_frame = true
 frame_camera()

func focus_patient(p: Dictionary) -> void:
 overview_mode = false
 auto_frame = true
 focus_patient_data = p
 focus_signature = "%d:%s:%d" % [p.id,p.state,p.room]
 frame_camera()

func ground_point(pixel: Vector2) -> Vector3:
 var origin := camera.project_ray_origin(pixel)
 var direction := camera.project_ray_normal(pixel)
 return origin+direction*(-origin.y/direction.y)

func pan_by(delta: Vector2) -> void:
 var center := get_viewport().get_visible_rect().size*0.5
 var movement := ground_point(center)-ground_point(center+delta)
 auto_frame = false
 close_size = camera.size
 overview_mode = false
 view_center += movement
 view_center.x = clampf(view_center.x,-6.0,11.0 if wing_built else 6.0)
 view_center.z = clampf(view_center.z,-4.0,5.0)
 frame_camera()

func build_interior() -> void:
 var model: Node3D = load("res://assets/models/hospital-interior.glb").instantiate()
 interior.add_child(model)
 model.set_meta("hospital_static",true)
 staff(Vector3(-4.65,0.05,4.25),"민지")
 staff(Vector3(4.8,0.05,-3.4),"박 선생")
 ct_light = G.rounded_box(interior,Vector3(-4,2.7,-3.17),Vector3(0.36,0.055,0.025),Color("74bbaa"),0.015)
 add_treatment_beam(Vector3(4,0,3))
 # These small local lights complement the baked contact shading in the GLB.
 for at in [Vector3(-6.1,1.8,0.5),Vector3(-1.9,2.6,-5.4),Vector3(1.9,2.6,-5.4),Vector3(6.1,1.8,0.5)]:
  var light := OmniLight3D.new()
  light.position = at
  light.light_color = Color("ffe6bb")
  light.light_energy = 0.08
  light.omni_range = 2.5
  interior.add_child(light)

func add_treatment_beam(at: Vector3) -> void:
 var beam := G.cylinder(interior,at+Vector3(0,1.59,-0.09).rotated(Vector3.UP,deg_to_rad(-35)),0.025,0.18,Color("7bcbb3"))
 beam.visible = false
 beams.append(beam)

func staff(at: Vector3, caption_text: String) -> void:
 var a := Actor.new()
 interior.add_child(a)
 a.position = at
 a.build(1,true,caption_text == "민지")
 a.caption.visible = false
 a.caption.text = caption_text
 if caption_text == "박 선생": a.body.rotation.y = PI*0.9
 if caption_text == "민지": a.scale = Vector3.ONE*1.16
 a.set_meta("reception",caption_text == "민지")
 staff_models.append(a)

func exterior_window(parent: Node3D, at: Vector3, width: float = 1.1) -> void:
 G.rounded_box(parent,at,Vector3(width+0.16,1.25,0.1),Color("ab8b61"),0.03)
 G.box(parent,at+Vector3(0,0,0.065),Vector3(width,1.08,0.035),Color("92b5ac"))
 for x in [-width*0.25,width*0.25]: G.box(parent,at+Vector3(x,-0.24,0.09),Vector3(width*0.43,0.5,0.012),Color("d8c69a"))
 G.box(parent,at+Vector3(0,0,0.1),Vector3(0.055,1.1,0.04),Color("e4d8bd"))
 G.box(parent,at+Vector3(0,0,0.1),Vector3(width,0.055,0.04),Color("e4d8bd"))

func tree(at: Vector3, flowering: bool = false, parent: Node3D = null) -> void:
 if parent == null: parent = exterior
 G.shadow(parent,at+Vector3(0,0.055,0),Vector2(3,2.6))
 G.cylinder(parent,at+Vector3(0,1,0),0.16,2,Color("967c55"))
 for i in range(5):
  var angle := i*2.4
  var color := Color("d5a0b1") if flowering else Color("7e985e")
  G.oval(parent,at+Vector3(cos(angle)*0.5,2.25+(i%2)*0.45,sin(angle)*0.45),Vector3(1.45,1.5,1.35),color.lightened((i%3)*0.06))

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
 var annex: Node3D = load("res://assets/models/treatment-annex.glb").instantiate()
 interior.add_child(annex)
 annex.set_meta("hospital_static",true)
 add_treatment_beam(Vector3(10,0,3))
 staff(Vector3(11.8,0,1),"별관 치료사")
 exterior_annex.visible = true
 expansion_sign.visible = false
 frame_camera()

func show_outside(value: bool) -> void:
 outside = value
 overview_mode = true
 auto_frame = true
 if not value:
  view_center = Vector3(-0.35,0,-0.5)
  close_size = 12.7
 interior.visible = not value
 exterior.visible = value
 frame_camera()

func sync(sim: HospitalSimulation, selected: int, delta: float) -> void:
 if sim.expanded: add_wing()
 var selected_patient := sim.get_patient(selected)
 if auto_frame and not overview_mode and not selected_patient.is_empty():
  var signature := "%d:%s:%d" % [selected,selected_patient.state,selected_patient.room]
  if focus_signature != signature: focus_patient(selected_patient)
 for model in staff_models: model.animate_staff(delta,model.get_meta("reception",false))
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
