class_name HospitalUiSkin
extends RefCounted

static var skins := {}
static func frame(kind: String = "panel", tint: Color = Color.WHITE) -> StyleBoxTexture:
 var key := kind+str(tint)
 if not skins.has(key):
  var box := StyleBoxTexture.new()
  box.texture = load("res://assets/ui/"+kind+".svg")
  box.modulate_color = tint
  for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
   box.set_texture_margin(side,24)
   box.set_content_margin(side,14 if side in [SIDE_LEFT,SIDE_RIGHT] else 10)
  skins[key] = box
 return skins[key]

static func picture(path: String, pixels: int) -> TextureRect:
 var node := TextureRect.new()
 node.texture = load(path)
 node.custom_minimum_size = Vector2(pixels,pixels)
 node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 node.mouse_filter = Control.MOUSE_FILTER_IGNORE
 if "portrait-" in path:
  var rounded := ShaderMaterial.new()
  rounded.shader = load("res://assets/ui/portrait_mask.gdshader")
  node.material = rounded
 return node
