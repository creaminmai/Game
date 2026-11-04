class_name HospitalHudButton
extends Button
var symbol := ""
static var icon_cache := {}

func _draw() -> void:
 var path := "res://assets/ui/"+symbol+".svg"
 if ResourceLoader.exists(path):
  if not icon_cache.has(symbol): icon_cache[symbol] = load(path)
  var pixels := minf(49,minf(size.x,size.y)-8)
  draw_texture_rect(icon_cache[symbol],Rect2((size-Vector2.ONE*pixels)*0.5,Vector2.ONE*pixels),false,Color(1,1,1,0.45) if disabled else Color.WHITE)
  return
 var ink := Color("418e7b") if not disabled else Color("9aa89b")
 if symbol in ["pause","play"]: ink = Color("fff5dc")
 var c := size*0.5
 var r := 13.0
 match symbol:
  "pause":
   draw_line(c+Vector2(-6,-12),c+Vector2(-6,12),ink,5,true)
   draw_line(c+Vector2(6,-12),c+Vector2(6,12),ink,5,true)
  "play":
   draw_colored_polygon(PackedVector2Array([c+Vector2(-8,-13),c+Vector2(13,0),c+Vector2(-8,13)]),ink)
  "people":
   draw_circle(c+Vector2(0,-8),6,ink)
   draw_arc(c+Vector2(0,13),12,PI,TAU,20,ink,4,true)
   draw_arc(c+Vector2(-12,11),9,PI,PI*1.5,12,ink,3,true)
   draw_circle(c+Vector2(-14,-7),4,ink)
  "attention":
   draw_circle(c,16,ink,false,2.5,true)
   draw_line(c+Vector2(0,-9),c+Vector2(0,3),ink,4,true)
   draw_circle(c+Vector2(0,9),2.3,ink)
  "build":
   draw_line(c+Vector2(-14,-7),c+Vector2(14,-7),ink,5,true)
   draw_line(c+Vector2(0,-7),c+Vector2(0,15),ink,5,true)
   draw_line(c+Vector2(-12,-12),c+Vector2(-12,-2),ink,4,true)
   draw_line(c+Vector2(12,-12),c+Vector2(12,-2),ink,4,true)
  "outside":
   draw_polyline(PackedVector2Array([c+Vector2(-16,-1),c+Vector2(0,-14),c+Vector2(16,-1)]),ink,3,true)
   draw_polyline(PackedVector2Array([c+Vector2(-12,-1),c+Vector2(-12,13),c+Vector2(12,13),c+Vector2(12,-1)]),ink,3,true)
   draw_rect(Rect2(c+Vector2(-4,3),Vector2(8,10)),ink,false,2)
  "overview":
   for side in [-1,1]:
    for v in [-1,1]:
     draw_polyline(PackedVector2Array([c+Vector2(side*5,v*14),c+Vector2(side*14,v*14),c+Vector2(side*14,v*5)]),ink,3,true)
  "plus", "minus":
   draw_line(c+Vector2(-r,0),c+Vector2(r,0),ink,3,true)
   if symbol == "plus": draw_line(c+Vector2(0,-r),c+Vector2(0,r),ink,3,true)
  "close":
   draw_line(c+Vector2(-9,-9),c+Vector2(9,9),ink,3,true)
   draw_line(c+Vector2(-9,9),c+Vector2(9,-9),ink,3,true)
