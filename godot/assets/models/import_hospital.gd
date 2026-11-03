@tool
extends EditorScenePostImport

# Godot 4.6.3 imports the atlas image but leaves ao_on_uv2=false for these
# separate glTF occlusion textures. Surface color uses UV0; baked AO uses UV1.
func _post_import(scene: Node) -> Object:
 for instance in scene.find_children("*","MeshInstance3D",true,false):
  for surface in range(instance.mesh.get_surface_count()):
   var material: Material = instance.mesh.surface_get_material(surface)
   if material is StandardMaterial3D and material.ao_enabled:
    material.ao_on_uv2 = true
 return scene
