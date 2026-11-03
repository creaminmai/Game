class_name HospitalActor
extends Node3D
const G = preload("res://scripts/geometry.gd")
var body: Node3D
var left_leg: MeshInstance3D
var right_leg: MeshInstance3D
var selection: MeshInstance3D
var caption: Label3D
var clock := 0.0

func build(id: int, staff: bool = false) -> void:
 body = Node3D.new()
 add_child(body)
 var shirt: Color = Color("f3fcf7") if staff else [Color("e4a58e"),Color("8cb6cd"),Color("b9a9d2"),Color("dfbc74")][(id-1)%4]
 G.sphere(body,Vector3(0,1.02,0),0.29,Color("f1c7a3"))
 var hair := G.sphere(body,Vector3(0,1.15,0.015),0.29,Color("53504b"))
 hair.scale.y = 0.55
 G.cylinder(body,Vector3(0,0.58,0),0.24,0.55,shirt)
 for x in [-0.09,0.09]:
  G.sphere(body,Vector3(x,1.04,0.267),0.025,Color("35423c"))
  G.sphere(body,Vector3(x*1.7,0.94,0.25),0.035,Color("dfaa96"))
 G.box(body,Vector3(-0.29,0.6,0),Vector3(0.14,0.44,0.16),shirt)
 G.box(body,Vector3(0.29,0.6,0),Vector3(0.14,0.44,0.16),shirt)
 left_leg = G.box(body,Vector3(-0.12,0.18,0),Vector3(0.16,0.35,0.18),Color("4d686b"))
 right_leg = G.box(body,Vector3(0.12,0.18,0),Vector3(0.16,0.35,0.18),Color("4d686b"))
 if staff:
  G.box(body,Vector3(0.1,0.7,0.245),Vector3(0.1,0.14,0.02),Color("60b9ac"))
 else:
  var area := Area3D.new()
  var collision := CollisionShape3D.new()
  var capsule := CapsuleShape3D.new()
  capsule.radius = 0.42
  capsule.height = 1.5
  collision.shape = capsule
  collision.position.y = 0.7
  area.add_child(collision)
  area.set_meta("patient_id",id)
  add_child(area)
 var ring := TorusMesh.new()
 ring.inner_radius = 0.38
 ring.outer_radius = 0.47
 ring.rings = 20
 ring.ring_segments = 8
 selection = G.shape(self,ring,Vector3(0,0.055,0),Color("d99a45"))
 selection.visible = false
 caption = G.label(self,"",Vector3(0,1.85,0),25)
 caption.visible = false

func sync(p: Dictionary, selected: bool, delta: float) -> void:
 var before := position
 position = p.position + Vector3(0,0.06,0)
 visible = p.state != "complete"
 clock += delta
 var moving: bool = p.state in ["entering","walk_ct","walk_plan","walk_treatment","leaving"]
 var lying: bool = p.state in ["ct_scan","treatment"]
 body.rotation.x = -PI/2 if lying else 0.0
 body.position.y = 0.87 if lying else 0.0
 if moving and before.distance_to(position) > 0.001:
  var direction := position-before
  body.rotation.y = atan2(direction.x,direction.z)
 elif lying: body.rotation.y = 0
 left_leg.rotation.x = sin(clock*10)*0.35 if moving else 0.0
 right_leg.rotation.x = -left_leg.rotation.x
 selection.visible = selected
 caption.visible = selected
 caption.text = p.name
