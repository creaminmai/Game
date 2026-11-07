class_name HospitalAdmissionDuty
extends RefCounted
# One role, no employee/economy framework. The simulation owns this clock.
const DELAY := 3.0
var enabled := false
var offer_seen := false
var candidate_id := -1
var elapsed := 0.0

func reset_pending() -> void:
 candidate_id = -1
 elapsed = 0.0

func set_enabled(value: bool, day: int) -> bool:
 if value and day < 2: return false
 enabled = value
 offer_seen = true
 reset_pending()
 return true

func tick(sim: HospitalSimulation, delta: float) -> void:
 if not enabled or sim.day < 2: return
 var first := -1
 for p in sim.patients:
  if p.state == "waiting" and (first < 0 or p.id < first): first = p.id
 if first != candidate_id:
  reset_pending()
  candidate_id = first
 if first < 0: return
 elapsed += delta
 if elapsed + .000001 < DELAY: return
 # No scheduled callbacks survive toggles, manual admission, pause or reload.
 sim.admit(first)
 reset_pending()

func snapshot() -> Dictionary:
 return {"version":1,"enabled":enabled,"offer_seen":offer_seen,"candidate_id":candidate_id,"elapsed":elapsed}

static func from_save(data: Variant, day: int, patients: Array[Dictionary]) -> HospitalAdmissionDuty:
 var result := HospitalAdmissionDuty.new()
 if data == null: return result # Existing saves never imply consent.
 if not data is Dictionary or data.get("version") != 1: return null
 if not data.get("enabled") is bool or not data.get("offer_seen") is bool: return null
 if not HospitalSimulation.whole(data.get("candidate_id"),-1,4) or data.candidate_id == 0: return null
 if not HospitalSimulation.finite_number(data.get("elapsed"),0,DELAY): return null
 if data.enabled and (day < 2 or not data.offer_seen): return null
 if (not data.enabled or data.candidate_id == -1) and (data.elapsed != 0 or data.candidate_id != -1): return null
 # A manual command can have invalidated the current candidate just before save.
 # Recheck it on the next simulation step; it can never admit twice.
 if data.candidate_id > patients.size(): return null
 result.enabled = data.enabled
 result.offer_seen = data.offer_seen
 result.candidate_id = int(data.candidate_id)
 result.elapsed = float(data.elapsed)
 return result
