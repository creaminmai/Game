class_name HospitalDailyLedger
extends RefCounted
# Receipts, not rewards. Updated only in the existing payment/purchase branches.
# -1 explicitly means an old save has no trustworthy opening/expense record.
var opening_money := 900
var income := 0
var expansion_expense := 0
var new_annex := false
var training_expense := 0
var lab_expense := 0
var research_expense := 0

func start_day(balance: int) -> void:
 opening_money = balance
 income = 0
 expansion_expense = 0
 new_annex = false
 training_expense = 0
 lab_expense = 0
 research_expense = 0

func snapshot() -> Dictionary:
 return {"version":3,"opening_money":opening_money,"income":income,"expansion_expense":expansion_expense,"new_annex":new_annex,"training_expense":training_expense,"lab_expense":lab_expense,"research_expense":research_expense}

static func whole(value: Variant, low: int, high: int) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and value == floor(float(value)) and value >= low and value <= high

static func from_save(data: Variant, paid_count: int, balance: int, expanded: bool) -> HospitalDailyLedger:
 var result := HospitalDailyLedger.new()
 if data == null:
  result.opening_money = -1
  result.expansion_expense = -1
  # The existing paid flags and unchanged visit fee are exact current-day receipts.
  result.income = paid_count*200
  return result
 if not data is Dictionary or not whole(data.get("version"),1,3): return null
 var training: Variant = data.get("training_expense",0)
 if data.version >= 2 and not data.has("training_expense"): return null
 if not whole(training,0,500) or not int(training) in [0,500]: return null
 if data.version == 1 and training != 0: return null
 if not whole(data.get("opening_money"),-1,100000000): return null
 if not whole(data.get("income"),0,paid_count*200) or data.income != paid_count*200: return null
 if not whole(data.get("expansion_expense"),-1,600) or not int(data.expansion_expense) in [-1,0,600] or not data.get("new_annex") is bool: return null
 if data.new_annex != (data.expansion_expense == 600): return null
 if data.new_annex and not expanded: return null
 var lab: Variant = data.get("lab_expense",0)
 var research: Variant = data.get("research_expense",0)
 if not whole(lab,0,1800) or not int(lab) in [0,1800] or not whole(research,0,500) or not int(research) in [0,500]: return null
 if data.version < 3 and (lab != 0 or research != 0): return null
 if data.version == 3 and (not data.has("lab_expense") or not data.has("research_expense")): return null
 if data.opening_money >= 0:
  if data.expansion_expense < 0 or balance != data.opening_money+data.income-data.expansion_expense-training-lab-research: return null
 result.opening_money = int(data.opening_money)
 result.income = int(data.income)
 result.expansion_expense = int(data.expansion_expense)
 result.new_annex = data.new_annex
 result.training_expense = int(training)
 result.lab_expense = int(lab)
 result.research_expense = int(research)
 return result
