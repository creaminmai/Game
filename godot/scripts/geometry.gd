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
 shadow(parent,at+Vector3(0,0.055,0),Vector2(0.85,0.7))
 cylinder(parent,at+Vector3(0,0.23,0),0.25,0.44,Color("c3a387"))
 cylinder(parent,at+Vector3(0,0.45,0),0.27,0.07,Color("ded0b4"))
 cylinder(parent,at+Vector3(0,0.49,0),0.22,0.015,Color("665241"))
 for i in range(8):
  var angle := i*2.4
  var height := 0.66+(i%3)*0.17
  var leaf := oval(parent,at+Vector3(cos(angle)*0.2,height,sin(angle)*0.2),Vector3(0.19,0.55,0.12),Color("6b915a") if i%2 == 0 else Color("8aa76b"))
  leaf.rotation = Vector3(sin(angle)*0.5,angle,cos(angle)*0.45)

static func flowers(parent: Node3D, at: Vector3, color: Color = Color("d88ca0")) -> void:
 rounded_box(parent,at+Vector3(0,0.18,0),Vector3(1.4,0.35,0.65),Color("b4ab8a"),0.1)
 for i in range(7):
  var center := at+Vector3(-0.55+i*0.18,0.52+(i%2)*0.12,0)
  oval(parent,center-Vector3(0,0.15,0),Vector3(0.4,0.3,0.4),Color("6d8d56"))
  for j in range(4):
   var angle := j*TAU/4
   sphere(parent,center+Vector3(cos(angle)*0.08,0,sin(angle)*0.08),0.075,color)
  sphere(parent,center+Vector3(0,0.06,0),0.045,Color("efce72"))

static var rounded_meshes: Dictionary = {}

# Six subdivided faces projected onto a rounded cuboid. Unlike overlapping spheres,
# this produces a continuous surface with shared, analytical edge normals.
static func rounded_box(parent: Node3D, at: Vector3, size: Vector3, color: Color, radius: float = 0.12) -> MeshInstance3D:
 var r := minf(radius, minf(size.x,minf(size.y,size.z))*0.49)
 var key := str(size)+":"+str(r)
 if not rounded_meshes.has(key):
  var tool := SurfaceTool.new()
  tool.begin(Mesh.PRIMITIVE_TRIANGLES)
  var half := size*0.5
  var inner := half-Vector3.ONE*r
  for axis in range(3):
   for sign_value in [-1.0,1.0]:
    var u := (axis+1)%3
    var v := (axis+2)%3
    var coords_u: Array[float] = [-half[u],-half[u]+r*0.3,-half[u]+r,half[u]-r,half[u]-r*0.3,half[u]]
    var coords_v: Array[float] = [-half[v],-half[v]+r*0.3,-half[v]+r,half[v]-r,half[v]-r*0.3,half[v]]
    for i in range(5):
     for j in range(5):
      var indices := [Vector2i(i,j),Vector2i(i,j+1),Vector2i(i+1,j),Vector2i(i+1,j),Vector2i(i,j+1),Vector2i(i+1,j+1)]
      if sign_value < 0: indices.reverse()
      for index in indices:
       var p := Vector3.ZERO
       p[axis] = half[axis]*sign_value
       p[u] = coords_u[index.x]; p[v] = coords_v[index.y]
       var q := p.clamp(-inner,inner)
       var normal := (p-q).normalized()
       tool.set_normal(normal)
       tool.add_vertex(q+normal*r)
  rounded_meshes[key] = tool.commit()
 return shape(parent,rounded_meshes[key],at,color)

static func oval(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
 var node := sphere(parent,at,0.5,color)
 node.scale = size
 return node

static func ring(parent: Node3D, at: Vector3, inner: float, outer: float, color: Color) -> MeshInstance3D:
 var mesh := TorusMesh.new()
 mesh.inner_radius = inner
 mesh.outer_radius = outer
 mesh.rings = 32
 mesh.ring_segments = 12
 var node := shape(parent,mesh,at,color)
 node.rotation.x = PI/2
 return node

static func logo(parent: Node3D, at: Vector3, scale_value: float = 1.0) -> void:
 var root := Node3D.new()
 parent.add_child(root)
 root.position = at
 root.scale = Vector3.ONE*scale_value
 oval(root,Vector3(0,0.12,0),Vector3(0.48,0.48,0.07),Color("edb449"))
 for i in range(5):
  var angle := PI*0.15+i*PI*0.175
  var ray := rounded_box(root,Vector3(cos(angle)*0.4,sin(angle)*0.4+0.12,0),Vector3(0.055,0.14,0.06),Color("edb449"),0.02)
  ray.rotation.z = angle-PI/2
 for side in [-1,1]:
  var leaf := oval(root,Vector3(side*0.14,-0.12,0.07),Vector3(0.37,0.15,0.07),Color("799354"))
  leaf.rotation.z = side*0.55

static var shadow_material: ShaderMaterial
static func shadow(parent: Node3D, at: Vector3, size: Vector2) -> MeshInstance3D:
 if shadow_material == null:
  var shader := Shader.new()
  shader.code = "shader_type spatial; render_mode unshaded, cull_disabled, depth_draw_never; void fragment(){float d=length((UV-vec2(0.5))*2.0); ALBEDO=vec3(0.14,0.18,0.13); ALPHA=(1.0-smoothstep(0.15,1.0,d))*0.24;}"
  shadow_material = ShaderMaterial.new()
  shadow_material.shader = shader
 var mesh := QuadMesh.new()
 mesh.size = size
 var node := MeshInstance3D.new()
 node.mesh = mesh
 node.material_override = shadow_material
 node.position = at
 node.rotation.x = -PI/2
 node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 parent.add_child(node)
 return node
