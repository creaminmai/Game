class_name HospitalFurnishings
extends RefCounted
const G = preload("res://scripts/geometry.gd")
const WOOD := Color("b2916e")
const CREAM := Color("e5ddc9")
const TEAL := Color("62968c")

static func chair(parent: Node3D, at: Vector3, color: Color = Color("cc9380")) -> void:
 G.shadow(parent,at+Vector3(0,0.055,0),Vector2(1.2,1.1))
 for x in [-0.36,0.36]:
  for z in [-0.3,0.3]: G.cylinder(parent,at+Vector3(x,0.18,z),0.055,0.35,WOOD)
 G.rounded_box(parent,at+Vector3(0,0.49,0),Vector3(0.95,0.22,0.88),color,0.1)
 G.rounded_box(parent,at+Vector3(0,0.89,-0.34),Vector3(1,0.8,0.25),color,0.12)
 for x in [-0.48,0.48]: G.rounded_box(parent,at+Vector3(x,0.66,0),Vector3(0.2,0.45,0.9),color,0.09)

static func cabinet(parent: Node3D, at: Vector3, width: float = 1.8) -> void:
 G.rounded_box(parent,at+Vector3(0,0.55,0),Vector3(width,1.1,0.65),CREAM,0.04)
 G.box(parent,at+Vector3(0,1.13,0),Vector3(width+0.08,0.08,0.72),WOOD)
 for x in [-width*0.25,width*0.25]:
  G.box(parent,at+Vector3(x,0.52,0.335),Vector3(width*0.48,0.92,0.025),Color("d2c9b5"))
  G.box(parent,at+Vector3(x+0.15,0.7,0.365),Vector3(0.04,0.2,0.03),Color("8c958a"))

static func monitor(parent: Node3D, at: Vector3, heatmap: bool = false) -> void:
 G.rounded_box(parent,at+Vector3(0,0.03,0),Vector3(0.45,0.06,0.32),Color("56625d"),0.03)
 G.box(parent,at+Vector3(0,0.23,0),Vector3(0.09,0.38,0.08),Color("65756e"))
 G.rounded_box(parent,at+Vector3(0,0.6,0),Vector3(1.05,0.73,0.1),Color("465d5c"),0.05)
 G.box(parent,at+Vector3(0,0.6,0.06),Vector3(0.93,0.61,0.025),Color("243f4d"))
 for i in range(3): G.box(parent,at+Vector3(-0.33,0.75-i*0.12,0.08),Vector3(0.15,0.035,0.015),Color("8cb6b3"))
 G.oval(parent,at+Vector3(0.13,0.6,0.09),Vector3(0.43,0.49,0.025),Color("819b9d"))
 for side in [-1,1]: G.oval(parent,at+Vector3(0.13+side*0.09,0.62,0.11),Vector3(0.14,0.26,0.015),Color("3c5964"))
 if heatmap:
  for i in range(3): G.oval(parent,at+Vector3(0.19,0.58,0.12+i*0.015),Vector3(0.25-i*0.06,0.25-i*0.06,0.018),[Color("649b8a"),Color("dbb66d"),Color("ca7c64")][i])
 G.rounded_box(parent,at+Vector3(0,0.04,0.42),Vector3(0.85,0.04,0.27),Color("d7d4c8"),0.02)
 for i in range(3): G.box(parent,at+Vector3(0,0.065,0.34+i*0.07),Vector3(0.7,0.006,0.025),Color("aaa99e"))

static func wall_light(parent: Node3D, at: Vector3) -> void:
 G.rounded_box(parent,at,Vector3(0.5,0.15,0.22),Color("dab980"),0.04)
 var lamp := G.rounded_box(parent,at+Vector3(0,-0.045,0.05),Vector3(0.41,0.08,0.18),Color("fff0c5"),0.03)
 lamp.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

static func bookshelf(parent: Node3D, at: Vector3) -> void:
 G.box(parent,at,Vector3(1.45,1.85,0.16),WOOD)
 for x in [-0.75,0.75]: G.box(parent,at+Vector3(x,0,0.2),Vector3(0.09,1.95,0.55),WOOD)
 for y in [-0.95,-0.32,0.32,0.95]: G.box(parent,at+Vector3(0,y,0.2),Vector3(1.55,0.07,0.55),WOOD)
 for row in range(3):
  for col in range(6):
   G.box(parent,at+Vector3(-0.57+col*0.22,-0.65+row*0.63,0.21),Vector3(0.15,0.49,0.32),[Color("9eaa9e"),Color("d8c9a8"),Color("b99580")][(row+col)%3])
   G.box(parent,at+Vector3(-0.57+col*0.22,-0.51+row*0.63,0.38),Vector3(0.09,0.1,0.012),CREAM)

static func bed(parent: Node3D, at: Vector3) -> void:
 G.shadow(parent,at+Vector3(0,0.055,0),Vector2(1.6,3))
 G.rounded_box(parent,at+Vector3(0,0.22,0),Vector3(0.9,0.35,1.65),Color("9aa9a2"),0.13)
 G.rounded_box(parent,at+Vector3(0,0.58,-0.1),Vector3(0.55,0.75,0.75),CREAM,0.08)
 G.rounded_box(parent,at+Vector3(0,0.9,0),Vector3(1.0,0.18,2.65),CREAM,0.08)
 G.rounded_box(parent,at+Vector3(0,1.01,0),Vector3(0.85,0.12,2.45),Color("92b7a8"),0.055)
 G.rounded_box(parent,at+Vector3(0,1.09,-0.93),Vector3(0.73,0.13,0.48),Color("e2dfc9"),0.06)
 for x in [-0.53,0.53]: G.box(parent,at+Vector3(x,0.86,0.15),Vector3(0.055,0.08,1.65),Color("7a918b"))

static func cart(parent: Node3D, at: Vector3) -> void:
 for x in [-0.3,0.3]:
  for z in [-0.22,0.22]:
   G.cylinder(parent,at+Vector3(x,0.56,z),0.025,0.93,Color("9ba9a4"))
   G.sphere(parent,at+Vector3(x,0.11,z),0.08,Color("57685e"))
 for y in [0.23,0.64,1.05]: G.rounded_box(parent,at+Vector3(0,y,0),Vector3(0.7,0.06,0.54),CREAM,0.03)
 G.rounded_box(parent,at+Vector3(0,0.77,0),Vector3(0.5,0.18,0.35),Color("9fb9b1"),0.04)
 G.cylinder(parent,at+Vector3(-0.17,1.2,0),0.07,0.24,Color("a4c0b9"))
