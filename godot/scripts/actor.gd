class_name HospitalActor
extends Node3D
const G = preload("res://scripts/geometry.gd")
const Motion = preload("res://scripts/character_motion.gd")
var body: Node3D
var left_leg: Node3D
var right_leg: Node3D
var selection: MeshInstance3D
var caption: Label3D
var clock := 0.0
var sitting_legs: Node3D
var arms: Array[Node3D] = []
var book: Node3D
var head: Node3D
var seated := false
var pick_area: Area3D
var head_pick: CollisionShape3D
var eye_materials: Array[ShaderMaterial] = []
var phase_seed := 0.0
var stride := 0.0
var gait := 0.0
var initialized := false
var previous_state := ""
var selected_before := false
var selection_time := 0.0
var completion_time := 0.0
var gesture_time := 0.0
var gesture_kind := ""
var gaze_yaw := 0.0
var pose_phase := "idle"
var previous_visual := Vector3.ZERO
var motion_distance := 0.0
var blink_amount := 0.0
var staff_event_count := 0
var seat_blend := 0.0

func install_blink() -> void:
 for mesh in head.find_children("*","MeshInstance3D",true,false):
  for surface in range(mesh.mesh.get_surface_count()):
   var original: Material = mesh.get_active_material(surface)
   if original is StandardMaterial3D and original.resource_name in ["white","iris"]:
    var material := ShaderMaterial.new()
    material.shader = preload("res://assets/shaders/blink.gdshader")
    material.set_shader_parameter("base_color",original.albedo_color)
    material.set_shader_parameter("surface_roughness",original.roughness)
    material.set_shader_parameter("eye_center",mesh.to_local(head.to_global(Vector3(0,.072,0))))
    material.set_shader_parameter("eye_up",(mesh.global_basis.inverse()*head.global_basis.y).normalized())
    mesh.set_surface_override_material(surface,material)
    eye_materials.append(material)

func idle_face(delta: float, strength: float = 1.0) -> void:
 clock += delta
 var blink_phase := fposmod(clock+phase_seed,4.1+phase_seed*.13)
 blink_amount = sin(PI*blink_phase/.18) if blink_phase < .18 else 0.0
 for material in eye_materials: material.set_shader_parameter("blink",blink_amount)
 # Long rests between small glances; different starts for every person.
 var look_phase := fposmod(clock+phase_seed*2.7,9.5)
 var glance := sin((look_phase-6.5)/3.0*TAU)*.13 if look_phase > 6.5 else 0.0
 head.rotation.y = glance*strength
 head.rotation.x = sin((clock+phase_seed)*1.5)*.012*strength

func react(kind: String, target: Vector3) -> void:
 gesture_kind = kind
 gesture_time = 1.25
 gaze_yaw = clampf(atan2(target.x-position.x,target.z-position.z),-.45,.45)
 staff_event_count += 1

func apply_palette(node: Node, shirt: Color, hair: Color, copies: Dictionary) -> void:
 if node is MeshInstance3D:
  for surface in range(node.mesh.get_surface_count()):
   var original: Material = node.get_active_material(surface)
   if original is StandardMaterial3D:
    var name_text := original.resource_name.to_lower()
    if name_text.begins_with("outfit") or name_text.begins_with("hair"):
     var key := original.get_instance_id()
     if not copies.has(key):
      var material: StandardMaterial3D = original.duplicate()
      material.albedo_color = shirt if name_text.begins_with("outfit") else (hair.lightened(0.1) if "highlight" in name_text else hair)
      copies[key] = material
     node.set_surface_override_material(surface,copies[key])
 for child in node.get_children(): apply_palette(child,shirt,hair,copies)

func build(id: int, staff: bool = false, receptionist: bool = true, model_path: String = "") -> void:
 phase_seed = id*1.731 + (2.1 if staff else 0.0)
 body = Node3D.new()
 add_child(body)
 var model: Node3D = load(model_path if model_path != "" else ("res://assets/models/nurse.glb" if staff and receptionist else "res://assets/models/patient.glb")).instantiate()
 body.add_child(model)
 left_leg = model.find_child("Leg_L",true,false)
 right_leg = model.find_child("Leg_R",true,false)
 sitting_legs = model.find_child("SeatedLegs",true,false)
 book = model.find_child("Book",true,false)
 head = model.find_child("Head",true,false)
 arms.assign([model.find_child("Arm_L",true,false),model.find_child("Arm_R",true,false)])
 sitting_legs.hide()
 book.hide()
 book.set_meta("reader",id == 1 and not staff)
 var glasses: Node3D = model.find_child("Glasses",true,false)
 glasses.visible = (not staff and id in [1,2]) or (staff and not receptionist)
 var shirt: Color = Color("55aaa0") if staff else [Color("dca48c"),Color("a2c4d8"),Color("c2a3c8"),Color("b9c69e")][(id-1)%4]
 var hair: Color = Color("79513c") if staff else [Color("aaa09a"),Color("c5c1bd"),Color("795944"),Color("afa6b4")][(id-1)%4]
 if staff and not receptionist: shirt = Color("f1eee5")
 apply_palette(model,shirt,hair,{})
 install_blink()
 if not staff:
  pick_area = Area3D.new()
  var collision := CollisionShape3D.new()
  var capsule := CapsuleShape3D.new()
  capsule.radius = 0.45
  capsule.height = 1.8
  collision.shape = capsule
  collision.position.y = 0.9
  pick_area.add_child(collision)
  head_pick = CollisionShape3D.new()
  var head_sphere := SphereShape3D.new()
  head_sphere.radius = 0.42
  head_pick.shape = head_sphere
  head_pick.position = Vector3(0,1.56,0)
  pick_area.add_child(head_pick)
  pick_area.set_meta("patient_id",id)
  add_child(pick_area)
 var ring := TorusMesh.new()
 ring.inner_radius = 0.38
 ring.outer_radius = 0.47
 ring.rings = 24
 ring.ring_segments = 8
 selection = G.shape(self,ring,Vector3(0,0.055,0),Color("74d6bd"))
 selection.hide()
 G.shadow(self,Vector3(0,0.015,0),Vector2(1.0,0.7))
 caption = G.label(self,"",Vector3(0,2.2,0),23)
 caption.hide()

func animate_staff(delta: float, reception: bool) -> void:
 idle_face(delta)
 body.position.y = sin((clock+phase_seed)*1.7)*.006
 gesture_time = maxf(0.0,gesture_time-delta)
 var response := sin(PI*clampf(1.0-gesture_time/1.25,0.0,1.0)) if gesture_time > 0 else 0.0
 head.rotation.y += gaze_yaw*response
 head.rotation.x += sin(response*PI)*.12 if gesture_kind == "admission" else 0.0
 arms[0].rotation.x = -1.3 if reception else -.75
 arms[1].rotation.x = (-1.3 if reception else -.8)+sin(clock*1.5)*.035
 arms[1].rotation.z = -.32*response
 if gesture_kind == "goodbye": arms[1].rotation.z += sin(clock*8)*.09*response

func sync(p: Dictionary, selected: bool, delta: float) -> void:
 var was_initialized := initialized
 var moving: bool = p.state in ["entering","walk_ct","walk_plan","walk_treatment","leaving"]
 var service: bool = p.state in ["ct_scan","treatment"]
 position = p.position + Vector3(0,.06,0)
 visible = p.state != "complete"
 idle_face(delta,.15 if service else 1.0)
 seated = p.state in ["waiting","ct_queue"]
 if not initialized: seat_blend = 1.0 if seated else 0.0
 elif seated: seat_blend = move_toward(seat_blend,1.0,delta/.45)
 else: seat_blend = 1.0-Motion.seat_rise(p)
 var offset := Motion.walking_offset(p) if moving else Vector3.ZERO
 var visual := position+(Motion.BEDSIDE.rotated(Vector3.UP,Motion.couch_yaw(p.state)) if service else offset)
 var direction := visual-previous_visual if initialized else Vector3.ZERO
 var distance := direction.length()
 # Refresh calls use zero delta. They must not consume movement before the
 # subsequent animated sync, or change a frozen pose while paused.
 if delta > 0:
  motion_distance += distance
  stride += distance*TAU/1.2
  gait = move_toward(gait,1.0 if moving and distance > .0001 else 0.0,delta*7.0)
  previous_visual = visual
 elif not initialized:
  previous_visual = visual
 if moving and distance > .0001 and delta > 0:
  if direction.length() > .0001:
   body.rotation.y = lerp_angle(body.rotation.y,atan2(direction.x,direction.z),1.0-exp(-delta*9.0))
 body.rotation.x = 0.0
 body.position = offset
 if seated:
  body.position = Vector3(0,.14*seat_blend,lerpf(Motion.stand_offset(p.id),Motion.seat_offset(p.id),Motion.smooth_fraction(seat_blend)))
 elif seat_blend > 0:
  body.position += Vector3(0,.14*seat_blend,(Motion.seat_offset(p.id)-Motion.stand_offset(p.id))*Motion.smooth_fraction(seat_blend))
  body.rotation.y = 0.0
  gait = 0.0
 head.position.z = 0.0
 pose_phase = "walk" if moving else "idle"
 if service:
  var pose := Motion.transfer(p)
  body.position = pose.position
  body.rotation.x = pose.pitch
  body.rotation.y = Motion.couch_yaw(p.state)
  head.position.z = .28*pose.recline
  pose_phase = pose.phase
  gait = move_toward(gait,0.0,delta*7.0)
 elif seated:
  body.rotation.y = 0.0
  gait = 0.0
 elif moving and p.state in ["walk_ct","walk_treatment","walk_plan","leaving"] and p.position.distance_to(Motion.bed_position(p)) < 1.6:
  var near_bed := Motion.walking_offset(p).length()/Motion.BEDSIDE.length()
  # End facing the couch's outward direction before the transfer starts.
  body.rotation.y = lerp_angle(body.rotation.y,Motion.couch_yaw(p.state),Motion.smooth_fraction((near_bed-.75)/.25))
 if not service: body.position.y += sin((clock+phase_seed)*1.7)*.006
 sitting_legs.visible = seat_blend > .5
 left_leg.visible = seat_blend <= .5
 right_leg.visible = seat_blend <= .5
 book.visible = seat_blend > .8 and book.get_meta("reader",false)
 for i in range(arms.size()):
  arms[i].rotation.z = (1.0 if i == 0 else -1.0)*.16 if seated or moving else 0.0
  arms[i].rotation.x = lerpf(sin(stride+i*PI)*.20*gait,-.72,seat_blend)
 left_leg.rotation.x = sin(stride)*.48*gait
 right_leg.rotation.x = -left_leg.rotation.x
 if pick_area != null:
  pick_area.transform = body.transform
  head_pick.position.z = head.position.z
 if selected and not selected_before: selection_time = .24
 selection_time = maxf(0.0,selection_time-delta)
 selection.scale = Vector3.ONE*lerpf(.82,1.0,Motion.smooth_fraction(1.0-selection_time/.24))
 selection.visible = selected
 selection.position = Vector3(body.position.x,.055,body.position.z+.45*seat_blend)
 if service: selection.position = Vector3(0,.055,0)
 if was_initialized and previous_state != "leaving" and p.state == "leaving": completion_time = 1.6
 completion_time = maxf(0.0,completion_time-delta)
 caption.visible = completion_time > 0 and p.state == "leaving"
 caption.text = "✓ 오늘 일정 완료" if caption.visible else ""
 caption.font_size = 17
 caption.position = body.position+Vector3(0,2.1,0)
 caption.modulate.a = minf(1.0,completion_time/.3)
 selected_before = selected
 previous_state = p.state
 initialized = true
