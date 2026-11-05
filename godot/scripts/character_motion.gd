class_name CharacterMotion
extends RefCounted
# Presentation only. Clinical elapsed time, reservations, routes and income
# remain owned by HospitalSimulation. Existing saves need no new fields.
const TRANSFER_SECONDS := 1.35
const BEDSIDE := Vector3(1.05,0,1.55)

static func smooth_fraction(value: float) -> float:
 var t: float = clampf(value,0.0,1.0)
 return t*t*(3.0-2.0*t)

static func couch_yaw(state: String) -> float:
 return deg_to_rad(-35) if state in ["treatment","walk_treatment","leaving"] else 0.0

static func bed_position(p: Dictionary) -> Vector3:
 return Vector3(-4,0,-2.8) if p.state in ["ct_scan","walk_ct","walk_plan"] else Vector3(4+6*maxi(p.room,0),0,3)

static func wait_anchor(id: int) -> Vector3:
 return Vector3(-4.5+((id-1)%2)*1.3,0,2.3+floori((id-1)/2.0)*1.5)

static func seat_offset(id: int) -> float:
 return -.95 if id <= 2 else -.60

static func stand_offset(id: int) -> float:
 return 0.0 if id <= 2 else .30

static func seat_rise(p: Dictionary) -> float:
 if p.state == "walk_ct" and p.route.size() == 5:
  return clampf(p.position.distance_to(wait_anchor(p.id))/.65,0.0,1.0)
 return 1.0

static func seat_path(id: int, t: float) -> Vector3:
 var stand := wait_anchor(id)+Vector3(0,0,stand_offset(id))
 var side := Vector3(-2.05,0,stand.z)
 var exit_point := Vector3(-1.5,0,3)
 return stand.lerp(side,clampf(t/.72,0.0,1.0)) if t < .72 else side.lerp(exit_point,(t-.72)/.28)

static func walking_offset(p: Dictionary) -> Vector3:
 var anchor := wait_anchor(p.id)
 var exit_point := Vector3(-1.5,0,3)
 if p.state == "entering" and p.route.size() == 1:
  var t: float = p.position.distance_to(anchor)/anchor.distance_to(exit_point)
  return seat_path(p.id,clampf(t,0.0,1.0))-p.position
 if p.state == "walk_ct" and p.route.size() == 5:
  var distance: float = p.position.distance_to(anchor)
  var t: float = clampf((distance-.65)/(anchor.distance_to(exit_point)-.65),0.0,1.0)
  return seat_path(p.id,t)-p.position
 if p.state not in ["walk_ct","walk_plan","walk_treatment","leaving"]: return Vector3.ZERO
 var bed := bed_position(p)
 if p.state in ["walk_treatment","leaving"]:
  if p.room == 0 and p.position.x >= 1.5 and p.position.x <= 4 and is_equal_approx(p.position.z,3):
   var t: float = (p.position.x-1.5)/2.5
   var front := bed+BEDSIDE.rotated(Vector3.UP,couch_yaw(p.state))
   var at := Vector3(lerpf(1.5,front.x,t),0,lerpf(3.0,front.z,smooth_fraction(t/.5)))
   return at-p.position
  if p.room == 1:
   # Round the existing diagonal beside the main couch via its clear front.
   if p.position.x >= 1.5 and p.position.x < 4 and p.position.z >= 3 and p.position.z <= 5.2:
    var t: float = (p.position.x-1.5)/2.5
    var x := lerpf(1.5,1.85,smooth_fraction(t/.3))+2.15*smooth_fraction((t-.4)/.6)
    var at := Vector3(x,0,lerpf(3.0,5.2,smooth_fraction(t/.55)))
    return at-p.position
   if is_equal_approx(p.position.x,10) and p.position.z >= 3 and p.position.z <= 5.2:
    var front := bed+BEDSIDE.rotated(Vector3.UP,couch_yaw(p.state))
    var t: float = clampf((5.2-p.position.z)/2.2,0.0,1.0)
    return Vector3(10,0,5.2).lerp(front,t)-p.position
 var amount := smooth_fraction(1.0-p.position.distance_to(bed)/1.6)
 return BEDSIDE.rotated(Vector3.UP,couch_yaw(p.state))*amount

static func equipment_lift(p: Dictionary) -> float:
 if p.state == "treatment":
  var end: float = HospitalSimulation.DURATIONS.treatment-p.elapsed
  return 1.0-smooth_fraction((minf(p.elapsed,end)-TRANSFER_SECONDS)/.4)
 if p.state in ["walk_treatment","leaving"]:
  return smooth_fraction((3.0-p.position.distance_to(bed_position(p)))/1.0)
 return 0.0

static func transfer(p: Dictionary) -> Dictionary:
 var duration: float = HospitalSimulation.DURATIONS[p.state]
 var t: float = clampf(minf(p.elapsed,duration-p.elapsed),0.0,TRANSFER_SECONDS)
 var recline := smooth_fraction((t-.15)/.6)
 var first := smooth_fraction((t-.75)/.3)
 var second := smooth_fraction((t-1.05)/.3)
 var at := BEDSIDE.lerp(Vector3(1.05,1.22,2.05),recline)
 # Enter from the open foot end. The linac's actual overhead assembly
 # retracts before transfer; the CT bore stays fixed.
 at.x = lerpf(at.x,0.0,first)
 at.z = lerpf(at.z,.65,second)
 return {"position":at.rotated(Vector3.UP,couch_yaw(p.state)),"pitch":-PI*.5*recline,"recline":recline,"settled":t>=TRANSFER_SECONDS,
  "phase":"prepare" if p.elapsed < .15 else ("lie_down" if p.elapsed < TRANSFER_SECONDS else ("rise" if p.elapsed > duration-TRANSFER_SECONDS else "service"))}
