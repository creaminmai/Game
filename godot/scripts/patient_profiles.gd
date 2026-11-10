class_name HospitalPatientProfiles
extends RefCounted
# Ordinary visitors, unrelated to branch characters or story reward arcs.
const DATA := [
 {"name":"김영수","shirt":"dca48c","hair":"aaa09a","glasses":true},
 {"name":"이정호","shirt":"a2c4d8","hair":"c5c1bd","glasses":true},
 {"name":"박상철","shirt":"c2a3c8","hair":"795944","glasses":false},
 {"name":"최민석","shirt":"b9c69e","hair":"afa6b4","glasses":false},
 {"name":"윤태호","shirt":"547b9b","hair":"493d34","glasses":false},
 {"name":"오진우","shirt":"e4ba72","hair":"986141","glasses":true}]
static func profile(id: int) -> Dictionary: return DATA[id-1]
static func patient_name(id: int, day: int) -> String:
 # Preserve the original four-name daily rotation; new ordinary visitors are stable.
 return DATA[(id+day-2)%4].name if id <= 4 else DATA[id-1].name
static func has_seat(id: int) -> bool: return id <= 4
static func wait_position(id: int) -> Vector3:
 if id == 5: return Vector3(-1.85,0,1.15)
 if id == 6: return Vector3(-1.65,0,5.8)
 return Vector3(-4.5+((id-1)%2)*1.3,0,2.3+floori((id-1)/2.0)*1.5)
