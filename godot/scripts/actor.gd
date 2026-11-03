class_name HospitalActor
extends Node3D
const G = preload("res://scripts/geometry.gd")
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

func build(id: int, staff: bool = false) -> void:
 body = Node3D.new()
 add_child(body)
 var model: Node3D = load("res://assets/models/nurse.glb" if staff else "res://assets/models/patient.glb").instantiate()
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
 glasses.visible = not staff and id in [1,2]
 var shirt: Color = Color("79b4aa") if staff else [Color("d6a38e"),Color("8dabbc"),Color("b3a0bf"),Color("b8b28c")][(id-1)%4]
 var hair: Color = Color("79513c") if staff else [Color("8f877b"),Color("b5b2ac"),Color("725848"),Color("aaa1ab")][(id-1)%4]
 apply_palette(model,shirt,hair,{})
 if not staff:
  pick_area = Area3D.new()
  var collision := CollisionShape3D.new()
  var capsule := CapsuleShape3D.new()
  capsule.radius = 0.45
  capsule.height = 1.8
  collision.shape = capsule
  collision.position.y = 0.9
  pick_area.add_child(collision)
  pick_area.set_meta("patient_id",id)
  add_child(pick_area)
 var ring := TorusMesh.new()
 ring.inner_radius = 0.38
 ring.outer_radius = 0.47
 ring.rings = 24
 ring.ring_segments = 8
 selection = G.shape(self,ring,Vector3(0,0.055,0),Color("d99a45"))
 selection.hide()
 G.shadow(self,Vector3(0,0.015,0),Vector2(1.0,0.7))
 caption = G.label(self,"",Vector3(0,2.2,0),23)
 caption.hide()

func animate_staff(delta: float, reception: bool) -> void:
 clock += delta
 head.rotation.y = sin(clock*0.8)*0.08
 arms[0].rotation.x = -1.3 if reception else -0.75
 arms[1].rotation.x = (-1.3 if reception else -0.8)+sin(clock*1.5)*0.09

func sync(p: Dictionary, selected: bool, delta: float) -> void:
 var before := position
 position = p.position + Vector3(0,0.06,0)
 visible = p.state != "complete"
 clock += delta
 var moving: bool = p.state in ["entering","walk_ct","walk_plan","walk_treatment","leaving"]
 var lying: bool = p.state in ["ct_scan","treatment"]
 seated = p.state in ["waiting","ct_queue"]
 body.rotation.x = -PI/2 if lying else 0.0
 body.position = Vector3(0,1.3,0.45) if lying else (Vector3(0,0.14,-0.45) if seated else Vector3.ZERO)
 head.position.z = 0.14 if lying else 0.0
 head.rotation.y = sin(clock*0.8)*0.045 if seated else 0.0
 if pick_area != null: pick_area.position = body.position if seated else Vector3.ZERO
 if moving and before.distance_to(position) > 0.001:
  var direction := position-before
  body.rotation.y = atan2(direction.x,direction.z)
 elif lying or seated: body.rotation.y = 0
 sitting_legs.visible = seated
 left_leg.visible = not seated
 right_leg.visible = not seated
 book.visible = seated and book.get_meta("reader",false)
 for i in range(arms.size()): arms[i].rotation.x = -0.72 if seated else (sin(clock*10+i*PI)*0.35 if moving else 0.0)
 left_leg.rotation.x = sin(clock*10)*0.3 if moving else 0.0
 right_leg.rotation.x = -left_leg.rotation.x
 selection.visible = selected
 caption.visible = selected or p.state in ["waiting","plan_ready"]
 caption.text = p.name if selected else ("접수" if p.state == "waiting" else "계획")
