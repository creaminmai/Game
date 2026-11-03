class_name HospitalGeometry
extends RefCounted

static func material(color: Color) -> StandardMaterial3D:
 var mat := StandardMaterial3D.new()
 mat.albedo_color = color
 mat.roughness = 0.92
 mat.metallic_specular = 0.15
 return mat

static func shape(parent: Node3D, mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
 var node := MeshInstance3D.new()
 node.mesh = mesh
 node.material_override = material(color)
 node.position = at
 parent.add_child(node)
 return node

static func box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
 var mesh := BoxMesh.new()
 mesh.size = size
 return shape(parent,mesh,at,color)

static func sphere(parent: Node3D, at: Vector3, radius: float, color: Color) -> MeshInstance3D:
 var mesh := SphereMesh.new()
 mesh.radius = radius
 mesh.height = radius*2
 mesh.radial_segments = 16
 mesh.rings = 8
 return shape(parent,mesh,at,color)

static func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
 var mesh := CylinderMesh.new()
 mesh.top_radius = radius
 mesh.bottom_radius = radius
 mesh.height = height
 mesh.radial_segments = 20
 return shape(parent,mesh,at,color)

static func label(parent: Node3D, caption: String, at: Vector3, size: int = 40) -> Label3D:
 var node := Label3D.new()
 node.text = caption
 node.font = load("res://assets/SunshineHangul.otf")
 node.font_size = size
 node.pixel_size = 0.012
 node.position = at
 node.modulate = Color("214b49")
 node.outline_modulate = Color("fff9e8")
 node.outline_size = 8
 node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 node.no_depth_test = true
 parent.add_child(node)
 return node

static func plant(parent: Node3D, at: Vector3) -> void:
 cylinder(parent,at+Vector3(0,0.2,0),0.27,0.4,Color("d3aa86"))
 for i in range(3):
  var leaf := sphere(parent,at+Vector3((i-1)*0.18,0.65+0.15*(i%2),0),0.29,Color("639e78"))
  leaf.scale = Vector3(0.7,1.6,0.7)
