class_name HospitalDailySchedule
extends RefCounted
# The running day's booking is immutable. Only an explicit next-day command
# commits a preference. New history uses actual close receipts, never day * 4.
const BASE := 4
const ANNEX := 6
var today_count := BASE
var preferred_count := BASE
var legacy_through := 0
var legacy_paid_total := 0
var closed_counts: Array[int] = []
var six_seen := false

func closed_through() -> int: return legacy_through+closed_counts.size()

func past_visits(day: int) -> int:
 # Only this migrated prefix came from the fixed-four 0.6.0 invariant.
 var total := mini(day-1,legacy_through)*BASE
 for i in range(closed_counts.size()):
  if legacy_through+i+1 < day: total += closed_counts[i]
 return total

func past_paid(day: int) -> int:
 return legacy_paid_total+past_visits(day)-legacy_through*BASE

func record_close(day: int, departed: int) -> void:
 if day <= closed_through(): return
 assert(day == closed_through()+1 and departed == today_count)
 closed_counts.append(departed)

func next_day(count: int) -> void:
 today_count = count
 preferred_count = count
 if count == ANNEX: six_seen = true

func snapshot() -> Dictionary:
 return {"version":1,"today_count":today_count,"preferred_count":preferred_count,"legacy_through":legacy_through,"legacy_paid_total":legacy_paid_total,"closed_counts":closed_counts.duplicate(),"six_seen":six_seen}

static func from_save(data: Variant, day: int, expanded: bool, done: bool, paid_total: int, paid_today: int) -> HospitalDailySchedule:
 var r := HospitalDailySchedule.new()
 if data == null:
  r.legacy_through = day-1
  r.legacy_paid_total = paid_total-paid_today
  if done: r.closed_counts.append(BASE)
  return r
 if not data is Dictionary or data.get("version") != 1: return null
 for field in ["today_count","preferred_count"]:
  if not HospitalSimulation.whole(data.get(field),BASE,ANNEX) or not int(data[field]) in [BASE,ANNEX]: return null
  if data[field] == ANNEX and not expanded: return null
 if day == 1 and data.today_count != BASE: return null
 if not HospitalSimulation.whole(data.get("legacy_through"),0,day-1): return null
 if not HospitalSimulation.whole(data.get("legacy_paid_total"),0,100000000): return null
 if not data.get("six_seen") is bool or not data.get("closed_counts") is Array: return null
 if data.closed_counts.size() != day-int(data.legacy_through)-(0 if done else 1): return null
 r.legacy_through = int(data.legacy_through); r.legacy_paid_total = int(data.legacy_paid_total)
 for i in range(data.closed_counts.size()):
  var count: Variant = data.closed_counts[i]
  if not HospitalSimulation.whole(count,BASE,ANNEX) or not int(count) in [BASE,ANNEX]: return null
  if count == ANNEX and (not expanded or r.legacy_through+i+1 == 1): return null
  r.closed_counts.append(int(count))
 if done and r.closed_counts.back() != data.today_count: return null
 r.today_count = int(data.today_count); r.preferred_count = int(data.preferred_count); r.six_seen = data.six_seen
 if paid_total != r.past_paid(day)+paid_today: return null
 return r
