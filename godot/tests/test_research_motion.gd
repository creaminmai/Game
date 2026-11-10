extends "res://tests/test_motion.gd"
func run() -> void:
 output = "res://../artifacts/research-motion"
 DirAccess.make_dir_recursive_absolute(output)
 var fixture = preload("res://tests/research_fixture.gd")
 var prepared: HospitalSimulation = fixture.prepare()
 prepared.purchase_lab(); prepared.start_research("ct")
 fixture.finish(prepared); prepared.start_next_day(); fixture.finish(prepared); prepared.start_next_day()
 game = load("res://main.tscn").instantiate()
 root.add_child(game); await process_frame; game.set_process(false)
 check(game.sim.restore(prepared.snapshot()),"actual seven-day CT research checkpoint")
 game.sim.paused = false; game.story.disable(); game.refresh()
 add_geometry(); await physics_frame
 var actor: HospitalActor = game.world.actors[1]
 var face := actor.head.global_position
 var max_step := 0.0
 var phases := {}; var snapshots := {}; var dual := false
 var phase_trace: Array = []; var previous := ""
 var ct_start := -1.0; var ct_end := -1.0
 for frame in range(180*60):
  game.sim.tick(1.0/60)
  game.world.sync(game.sim,1,1.0/60)
  var p: Dictionary = game.sim.get_patient(1)
  if p.state == "ct_scan" and ct_start < 0: ct_start = game.sim.time
  if previous == "ct_scan" and p.state != "ct_scan": ct_end = game.sim.time
  previous = p.state
  for other in game.sim.patients:
   if other.state in ["walk_ct","walk_plan","walk_treatment","ct_scan","treatment","leaving"]: probe_body(other)
  max_step = maxf(max_step,face.distance_to(actor.head.global_position)); face = actor.head.global_position
  var key: String = p.state+":"+actor.pose_phase
  if not phases.has(key): phase_trace.append({"state":p.state,"pose":actor.pose_phase,"time":game.sim.time,"elapsed":p.elapsed})
  phases[key] = true
  if p.state == "ct_scan" and not snapshots.has(key):
   snapshots[key] = true
   var restored := HospitalSimulation.new()
   check(restored.restore(game.sim.snapshot()),"four-second CT transfer restores "+key)
   var copy := Actor.new(); game.world.interior.add_child(copy); copy.build(1)
   copy.sync(restored.get_patient(1),false,0)
   check(pose_equal(actor,copy),"exact shortened CT pose from real elapsed time "+key)
   copy.free()
  dual = dual or HospitalChapterProgress.simultaneous(game.sim)
  if game.sim.all_done(): break
 check(absf(ct_end-ct_start-4) < .02,"actual CT step exactly four seconds at sixty-hertz sampling")
 check(max_step < .22,"no new transfer teleport after shortening")
 for phase in ["prepare","lie_down","service","rise"]: check(phases.has("ct_scan:"+phase),"four-second CT retains "+phase)
 check(contacts.is_empty(),"actual head/torso/hands clear device meshes after shortening")
 check(dual and game.sim.all_done() and game.sim.money == 3100,"normal queues dual rooms and 800 receipts preserved after research")
 var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"ct_seconds":ct_end-ct_start,"max_head_step_60fps":max_step,"geometry_contacts":contacts,"phases":phase_trace,"physical_mobile":false}
 FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("RESEARCH MOTION: ",checks," checks, ",failures.size()," failures")
 game.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
