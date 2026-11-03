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
 var shirt: Color = Color("609c94") if staff else [Color("d99c88"),Color("89a7bf"),Color("ad9ebc"),Color("bfaf7e")][(id-1)%4]
 var skin := Color("edbc97")
 var hair_color: Color = Color("644736") if staff else [Color("83766b"),Color("a09d98"),Color("73604e"),Color("a8a2ad")][(id-1)%4]
 G.oval(body,Vector3(0,0.72,0),Vector3(0.57,0.67,0.4),shirt)
 G.oval(body,Vector3(0,1.3,0.02),Vector3(0.77,0.77,0.66),skin)
 for side in [-1,1]:
  G.sphere(body,Vector3(side*0.38,1.28,0.02),0.09,skin)
  G.oval(body,Vector3(side*0.13,1.31,0.335),Vector3(0.085,0.115,0.04),Color("443a31"))
  G.sphere(body,Vector3(side*0.13-0.016,1.335,0.36),0.018,Color("fff5df"))
  G.oval(body,Vector3(side*0.23,1.19,0.29),Vector3(0.12,0.055,0.025),Color("d99586"))
  G.rounded_box(body,Vector3(side*0.13,1.42,0.32),Vector3(0.11,0.025,0.035),hair_color,0.01)
 G.sphere(body,Vector3(0,1.23,0.36),0.052,skin)
 G.oval(body,Vector3(0,1.13,0.323),Vector3(0.085,0.036,0.025),Color("aa7161"))
 G.oval(body,Vector3(0,1.57,-0.06),Vector3(0.8,0.35,0.66),hair_color)
 for i in range(5):
  var fringe := G.oval(body,Vector3(-0.29+i*0.13,1.53-0.025*(i%2),0.23),Vector3(0.25,0.25,0.19),hair_color)
  fringe.rotation.z = -0.25
 if staff:
  G.sphere(body,Vector3(0.28,1.46,-0.33),0.22,hair_color)
 for side in [-1,1]:
  var arm := G.oval(body,Vector3(side*0.34,0.76,0),Vector3(0.18,0.41,0.2),shirt)
  arm.rotation.z = side*0.15
  G.oval(body,Vector3(side*0.36,0.49,0.015),Vector3(0.15,0.23,0.16),skin)
  G.rounded_box(body,Vector3(side*0.14,0.09,0.09),Vector3(0.22,0.16,0.36),Color("ece2ce") if staff else Color("5b554c"),0.07)
 left_leg = G.rounded_box(body,Vector3(-0.14,0.3,0),Vector3(0.19,0.44,0.23),shirt.darkened(0.15),0.07)
 right_leg = G.rounded_box(body,Vector3(0.14,0.3,0),Vector3(0.19,0.44,0.23),shirt.darkened(0.15),0.07)
 for side in [-1,1]:
  var collar := G.rounded_box(body,Vector3(side*0.09,0.98,0.2),Vector3(0.14,0.12,0.025),Color("e9e2d0"),0.02)
  collar.rotation.z = side*-0.4
 if staff:
  G.rounded_box(body,Vector3(0.15,0.77,0.205),Vector3(0.1,0.16,0.03),Color("f0e5cf"),0.015)
  G.box(body,Vector3(0.15,0.82,0.23),Vector3(0.085,0.035,0.01),Color("d8af64"))
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
 G.shadow(self,Vector3(0,0.015,0),Vector2(0.95,0.65))
 caption = G.label(self,"",Vector3(0,2.05,0),25)
 caption.visible = false

func sync(p: Dictionary, selected: bool, delta: float) -> void:
 var before := position
 position = p.position + Vector3(0,0.06,0)
 visible = p.state != "complete"
 clock += delta
 var moving: bool = p.state in ["entering","walk_ct","walk_plan","walk_treatment","leaving"]
 var lying: bool = p.state in ["ct_scan","treatment"]
 body.rotation.x = -PI/2 if lying else 0.0
 body.position = Vector3(0,1.25,0.45) if lying else Vector3.ZERO
 if moving and before.distance_to(position) > 0.001:
  var direction := position-before
  body.rotation.y = atan2(direction.x,direction.z)
 elif lying: body.rotation.y = 0
 left_leg.rotation.x = sin(clock*10)*0.35 if moving else 0.0
 right_leg.rotation.x = -left_leg.rotation.x
 selection.visible = selected
 caption.visible = selected or p.state in ["waiting","plan_ready"]
 caption.text = p.name if selected else ("접수" if p.state == "waiting" else "계획")
