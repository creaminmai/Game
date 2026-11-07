class_name HospitalMobileScreen
extends RefCounted

# Touch targets use CSS pixels / platform points, not Retina framebuffer pixels.
static func display_points(game: Control) -> Vector2:
 var pixels := Vector2(game.get_window().size)
 if OS.has_feature("web"):
  var raw: Variant = JavaScriptBridge.eval("JSON.stringify([document.querySelector('#canvas').clientWidth,document.querySelector('#canvas').clientHeight])")
  var values: Variant = JSON.parse_string(str(raw))
  if values is Array and values.size() == 2 and values[0] > 0 and values[1] > 0:
   return Vector2(values[0],values[1])
 elif OS.has_feature("android"):
  return pixels/maxf(1.0,DisplayServer.screen_get_dpi()/160.0)
 elif OS.has_feature("ios") or OS.has_feature("macos"):
  return pixels/maxf(1.0,DisplayServer.screen_get_scale())
 return pixels

# Native safe areas are framebuffer pixels; Web env() values are CSS pixels.
static func safe_rect(game: Control, test_insets: Vector4 = Vector4.ZERO) -> Rect2:
 var pixels := Vector2(game.get_window().size)
 var insets := test_insets
 if OS.has_feature("web"):
  pixels = display_points(game)
  var raw: Variant = JavaScriptBridge.eval("JSON.stringify(window.sunshineSafeInsets ? window.sunshineSafeInsets() : [0,0,0,0])")
  var values: Variant = JSON.parse_string(str(raw))
  if values is Array and values.size() == 4:
   insets = Vector4(values[0],values[1],values[2],values[3])
 elif OS.has_feature("android") or OS.has_feature("ios"):
  var area := DisplayServer.get_display_safe_area()
  if area.size.x > 0 and area.size.y > 0:
   insets = Vector4(area.position.x,area.position.y,pixels.x-area.end.x,pixels.y-area.end.y)
 var scale := game.size/pixels
 return Rect2(Vector2(insets.x,insets.y)*scale,(pixels-Vector2(insets.x+insets.z,insets.y+insets.w))*scale)
