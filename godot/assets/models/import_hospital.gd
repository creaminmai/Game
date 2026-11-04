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
   if material is StandardMaterial3D:
    # Engine calibration is per material, not a screen-wide saturation filter.
    # Original packed Blender base colors remain the editable source.
    match material.resource_name:
     "Honey oak":
      material.albedo_color = Color("f8dfc1")
      material.roughness = 0.46
      material.metallic_specular = 0.35
     "Coral woven upholstery":
      material.albedo_color = Color("ffded0")
      material.roughness = 0.82
      material.metallic_specular = 0.22
     "white":
      material.albedo_color = Color("f1eee7")
      material.roughness = 0.26
      material.metallic_specular = 0.5
 return scene
