extends "res://tests/test_motion.gd"
const Fixture = preload("res://tests/daily_capacity_fixture.gd")
func run() -> void:
 var mode := "held"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
 output = "res://../artifacts/capacity-motion-"+mode
 DirAccess.make_dir_recursive_absolute(output)
 game = load("res://main.tscn").instantiate(); root.add_child(game)
 await process_frame; game.set_process(false); game.story.disable()
 var checkpoint := Fixture.six_day()
 if mode == "auto":
  checkpoint = preload("res://tests/research_fixture.gd").prepare(4)
  assert(checkpoint.start_next_day(6))
 check(game.sim.restore(checkpoint.snapshot()),"actual six-day checkpoint")
 game.sim.paused = false; game.user_paused = false; game.pause_holds.clear()
 game.refresh(); game.world.show_overview()
 add_geometry(); await physics_frame
 var sim: HospitalSimulation = game.sim
 if mode == "held":
  # Six arrivals with no commands: four seats and two actual clear standing spots.
  for n in range(40*30):
   sim.tick(1.0/30); game.world.sync(sim,-1,1.0/30)
   for p in sim.patients:
    if p.id >= 5: probe_body(p)
  check(sim.patients.size() == 6 and sim.count_state("waiting") == 6,"all six reach distinct waiting locations")
  for id in [5,6]:
   check(not game.world.actors[id].seated and not game.world.actors[id].sitting_legs.visible,"standing visitor is never seated without a chair")
   for other in sim.patients:
    if other.id == id: continue
    var a: HospitalActor = game.world.actors[id]; var b: HospitalActor = game.world.actors[other.id]
    check(a.body.global_position.distance_to(b.body.global_position) > .7,"separate waiting bodies")
 var minimum_pair := 99.0
 var pair_contacts := {}
 var camera_size: float = game.world.camera.size
 for n in range(250*30):
  Fixture.step(sim,1.0/30); game.world.sync(sim,-1,1.0/30)
  for p in sim.patients:
   if p.id >= 5 and p.state != "complete": probe_body(p)
  for a in sim.patients:
   if a.state == "complete": continue
   for b in sim.patients:
    if a.id >= b.id or b.id < 5 or b.state == "complete": continue
    var aa: HospitalActor = game.world.actors[a.id]; var bb: HospitalActor = game.world.actors[b.id]
    var distance := aa.head.global_position.distance_to(bb.head.global_position)
    minimum_pair = minf(minimum_pair,distance)
    if distance < .50:
     var key: String = "%d-%d:%s-%s" % [a.id,b.id,a.state,b.state]
     if not pair_contacts.has(key): pair_contacts[key] = {"time":sim.time,"distance":distance,"a":str(aa.body.global_position),"b":str(bb.body.global_position)}
  if sim.all_done(): break
 check(sim.all_done() and sim.ledger.income == 1200 and sim.max_treating == 2,"six actual full flows and two rooms")
 check(contacts.is_empty(),"new patients clear actual furniture mesh probes")
 check(pair_contacts.is_empty(),"new patients do not overlap other patient heads")
 check(is_equal_approx(game.world.camera.size,camera_size),"six-person updates never zoom camera")
 var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"geometry_contacts":contacts,"patient_contacts":pair_contacts,"minimum_head_distance":minimum_pair,"sample_rate":30,"platform":"Linux Godot actual GLB geometry, headless physics; not physical mobile"}
 FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("CAPACITY MOTION: ",JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)
