extends SceneTree
const Sim = preload("res://scripts/hospital_simulation.gd")
const Store = preload("res://scripts/save_store.gd")
var checks := 0
var failures: Array[String] = []

func check(condition: bool, caption: String) -> void:
 checks += 1
 if not condition:
  failures.append(caption)
  printerr("FAIL: ",caption)

func autoplay(sim: HospitalSimulation, seconds: float, expand: bool = false) -> void:
 for i in range(int(seconds*10)):
  for p in sim.patients:
   if p.state == "waiting": sim.admit(p.id)
   elif p.state == "plan_ready": sim.assign_plan(p.id)
  if expand and sim.lifetime_completed > 0 and not sim.expanded: sim.purchase_expansion()
  sim.tick(0.1)

func run() -> void:
 var s = Sim.new()
 check(s.patients.size() == 1 and s.money == 900,"initial patient and money")
 check(s.status_text(2).contains("도착 예정"),"unarrived patient status")
 check(not s.admit(1),"cannot admit while entering")
 check(not s.purchase_expansion(),"expansion locked before treatment")
 s.tick(12)
 check(s.patients.size() == 3,"staggered arrivals")
 check(s.get_patient(1).state == "waiting","walk reaches waiting room")
 check(s.next_action_patient(1) > 0,"find patient requiring action")
 s.paused = true
 var before: Dictionary = s.snapshot()
 s.tick(5)
 check(s.snapshot() == before,"pause freezes complete simulation")
 check(not s.admit(1),"paused admission blocked")
 s.paused = false
 check(s.admit(1),"admit waiting patient")
 check(s.ct_owner == 1 and s.get_patient(1).state == "walk_ct","CT reserved during travel")
 check(not s.admit(1),"duplicate admission blocked")
 check(s.admit(2),"second patient admitted")
 check(s.get_patient(2).state == "ct_queue" and s.queue_rank(2) == 1,"CT queue rank")
 s.tick(6)
 check(s.admit(3),"third patient admitted")
 check(s.queue_rank(3) == 2,"FIFO second position")
 check(s.status_text(3).contains("2번째"),"queue status includes ordinal")
 var saved: Dictionary = s.snapshot()
 var restored = Sim.new()
 check(restored.restore(JSON.parse_string(JSON.stringify(saved))),"restore JSON round trip")
 check(restored.paused and restored.ct_owner == s.ct_owner,"restoration pauses and restores reservation")
 check(JSON.stringify(restored.snapshot()) == JSON.stringify(saved),"all fields restored exactly")
 var bad: Dictionary = saved.duplicate(true)
 bad.patients[1].state = "walk_ct"
 bad.patients[1].route = [[0,0,0]]
 bad.patients[1].next_state = "ct_scan"
 check(not restored.restore(bad),"duplicate CT ownership rejected")
 check(JSON.stringify(restored.snapshot()) == JSON.stringify(saved),"invalid save is transactional")
 for mutation in ["version","route","paid","position","room","elapsed","ids","queue_order","destination"]:
  bad = saved.duplicate(true)
  match mutation:
   "version": bad.version = 100
   "route": bad.patients[0].route = []
   "paid": bad.patients[0].paid = true
   "position": bad.patients[0].position = [0,0]
   "room": bad.patients[0].room = 5
   "elapsed": bad.patients[0].elapsed = -1
   "ids": bad.patients[1].id = 1
   "queue_order": bad.patients[1].queue_order = 90000
   "destination": bad.patients[0].next_state = "complete"
  check(not restored.restore(bad),"reject invalid " + mutation)
 check(not s.start_next_day(),"cannot start next day mid-treatment")
 autoplay(s,280,true)
 check(s.completed() == 4 and s.all_done(),"all four treated and returned home")
 check(s.expanded and s.treatment_owners.size() == 2,"actual second treatment capacity")
 check(s.max_treating == 2,"two patients treated concurrently")
 check(s.money == 1100 and s.lifetime_completed == 4,"first day economy")
 check(not s.purchase_expansion() and s.money == 1100,"no double charge")
 var balance: int = s.money
 s.tick(200)
 check(s.money == balance,"no duplicate payout from extra ticks")
 check(s.start_next_day(),"next day starts after everyone leaves")
 check(s.day == 2 and s.money == 1100 and s.expanded,"next day retains assets")
 check(s.patients.size() == 1 and s.ct_owner == -1 and s.treatment_owners == [-1,-1],"next day clears old reservations")
 check(not s.start_next_day(),"next day cannot start twice")
 autoplay(s,260)
 check(s.all_done() and s.lifetime_completed == 8 and s.money == 1900,"second day functional flow")
 var poor = Sim.new()
 poor.lifetime_completed = 1; poor.money = 599
 check(not poor.purchase_expansion() and poor.money == 599,"insufficient funds protected")
 var dual = Sim.new()
 dual.lifetime_completed = 1
 dual.purchase_expansion()
 var found := false
 for i in range(2200):
  autoplay(dual,0.1)
  if dual.count_state("treatment") == 2:
   found = true
   break
 check(found,"reach dual-treatment checkpoint")
 var resumed = Sim.new()
 check(resumed.restore(dual.snapshot()),"restore concurrent treatments")
 resumed.paused = false
 autoplay(resumed,180)
 check(resumed.money == 1100 and resumed.completed() == 4,"resumed treatments pay exactly once")
 var store = Store.new()
 store.path = "user://test-hospital-save.json"
 check(store.save(dual),"atomic file save")
 var disk = Sim.new()
 check(store.load_into(disk) and disk.paused,"load persisted save")
 var file := FileAccess.open(store.path,FileAccess.WRITE)
 file.store_string("broken data"); file.close()
 var damaged = Store.new()
 damaged.path = store.path
 check(not damaged.load_into(disk) and damaged.blocked,"damaged save blocks writes")
 check(not damaged.save(dual) and FileAccess.get_file_as_string(store.path) == "broken data","damaged original preserved")
 DirAccess.remove_absolute(store.path)
 print("SIMULATION: %d checks, %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
 run.call_deferred()
