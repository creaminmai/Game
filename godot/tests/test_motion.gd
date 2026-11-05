extends SceneTree
const Sim = preload("res://scripts/hospital_simulation.gd")
const Actor = preload("res://scripts/actor.gd")
var failures: Array[String] = []
var checks := 0
var output := "res://../artifacts/motion-unit"
var game: Control
var collision_models := {}
var contacts := {}
var head_colliders: Array[Dictionary] = []

func add_geometry() -> void:
 for model in game.world.interior.get_children():
  if not model.has_meta("hospital_static") or collision_models.has(model.get_instance_id()): continue
  for mesh in model.find_children("*","MeshInstance3D",true,false):
   var collider := StaticBody3D.new()
   var moving_head: bool = mesh.name == "TreatmentHead"
   collider.collision_layer = 16 << head_colliders.size() if moving_head else 8
   collider.collision_mask = 0
   var shape := CollisionShape3D.new()
   shape.shape = mesh.mesh.create_trimesh_shape()
   collider.add_child(shape)
   if moving_head:
    game.world.add_child(collider)
    collider.global_transform = mesh.global_transform
    collider.global_position.y -= mesh.position.y-float(mesh.get_meta("rest_y"))
    head_colliders.append({"mesh":mesh,"mask":collider.collision_layer})
   else: mesh.add_child(collider)
  collision_models[model.get_instance_id()] = true

func probe_body(p: Dictionary) -> void:
 var a: HospitalActor = game.world.actors[p.id]
 var points := {"head":[a.head.to_global(Vector3(0,.065,.02)),.29],"torso":[a.body.to_global(Vector3(0,.9,0)),.15]}
 for i in range(2): points["hand"+str(i)] = [a.arms[i].to_global(Vector3(-.07 if i == 0 else .07,-.53,.045)),.075]
 for key in points:
  var sphere := SphereShape3D.new(); sphere.radius = points[key][1]
  var query := PhysicsShapeQueryParameters3D.new()
  query.shape = sphere
  query.transform.origin = points[key][0]
  query.collision_mask = 8
  var hits: Array = game.world.get_world_3d().direct_space_state.intersect_shape(query,1)
  if hits.is_empty():
   for assembly in head_colliders:
    query.collision_mask = assembly.mask
    query.transform.origin = points[key][0]-Vector3(0,assembly.mesh.position.y-float(assembly.mesh.get_meta("rest_y")),0)
    hits = game.world.get_world_3d().direct_space_state.intersect_shape(query,1)
    if not hits.is_empty(): break
  if not hits.is_empty():
   var contact_key: String = p.state+":"+str(p.room)+":"+key
   if not contacts.has(contact_key):
    var rest: Dictionary = game.world.get_world_3d().direct_space_state.get_rest_info(query)
    contacts[contact_key] = {"elapsed":p.elapsed,"position":str(points[key][0]),"pose":a.pose_phase,"surface_point":str(rest.get("point",Vector3.ZERO)),"normal":str(rest.get("normal",Vector3.ZERO)),"mesh":hits[0].collider.get_parent().name}

func check(ok: bool, title: String) -> void:
 checks += 1
 if not ok:
  failures.append(title)
  printerr("FAIL: ",title)

func pose_equal(a: HospitalActor, b: HospitalActor) -> bool:
 return a.position.is_equal_approx(b.position) and a.body.position.is_equal_approx(b.body.position) and a.body.rotation.is_equal_approx(b.body.rotation) and is_equal_approx(a.head.position.z,b.head.position.z)

func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
 DirAccess.make_dir_recursive_absolute(output)
 game = load("res://main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.set_process(false)
 add_geometry()
 await physics_frame
 var sim: HospitalSimulation = game.sim
 sim.tick(6)
 game.refresh()
 game.select_patient(1)
 var minji: HospitalActor = game.world.staff_models[0]
 game.perform_action()
 var reactions := minji.staff_event_count
 game.perform_action()
 check(reactions == 1 and minji.staff_event_count == reactions,"successful admission reacts once; repeated action does not duplicate work")
 check(game.action_button.disabled and game.action_button.text.contains("이동"),"action immediately shows actual new state and disables duplicate instruction")
 var actor: HospitalActor = game.world.actors[1]
 check(actor.eye_materials.size() == 2 and minji.eye_materials.size() == 2,"existing facial inlays have shared blink shader for patient and Minji")
 # Restore an actual game instance during the first stand-up frame, including
 # its normal ready/process lifecycle, rather than skipping to a service pose.
 var restored_game: Control = load("res://main.tscn").instantiate()
 var walk_restored: bool = restored_game.sim.restore(sim.snapshot())
 root.add_child(restored_game)
 await process_frame
 await process_frame
 check(walk_restored and restored_game.sim.paused and pose_equal(actor,restored_game.world.actors[1]),"actual game restores the early standing/walking pose while paused")
 restored_game.free()
 var frozen_body := minji.body.transform
 var frozen_head := minji.head.transform
 var frozen_arm := minji.arms[1].transform
 var frozen_time := minji.gesture_time
 sim.paused = true
 for i in range(60): game.world.sync(sim,1,0)
 check(frozen_body.is_equal_approx(minji.body.transform) and frozen_head.is_equal_approx(minji.head.transform) and frozen_arm.is_equal_approx(minji.arms[1].transform) and minji.gesture_time == frozen_time,"pause freezes Minji gesture, breathing and blink")
 sim.paused = false
 var seen := {}
 var phases := {}
 var snapshots := {}
 var max_step := 0.0
 var max_turn := 0.0
 var last_face := actor.head.global_position
 var last_yaw := actor.body.rotation.y
 var last_state: String = sim.get_patient(1).state
 var phase_trace: Array = []
 var prior_phase := ""
 var camera_center: Vector3 = game.world.view_center
 var expanded := false
 var dual := false
 for frame in range(180*60):
  for p in sim.patients:
   if p.state == "waiting": sim.admit(p.id)
   elif p.state == "plan_ready": sim.assign_plan(p.id)
  sim.tick(1.0/60)
  game.world.sync(sim,1,1.0/60)
  for other in sim.patients:
   if other.state in ["walk_ct","walk_plan","walk_treatment","ct_scan","treatment","leaving"]: probe_body(other)
  var p := sim.get_patient(1)
  seen[p.state] = true
  var face: Vector3 = actor.head.global_position
  max_step = maxf(max_step,face.distance_to(last_face))
  if p.state == last_state and p.state.begins_with("walk"):
   max_turn = maxf(max_turn,absf(angle_difference(last_yaw,actor.body.rotation.y)))
  if actor.pose_phase != prior_phase:
   phase_trace.append({"time":sim.time,"state":p.state,"pose":actor.pose_phase})
   prior_phase = actor.pose_phase
  phases[p.state+":"+actor.pose_phase] = true
  if p.state in ["ct_scan","treatment"]:
   var key: String = p.state+":"+actor.pose_phase
   if not snapshots.has(key):
    snapshots[key] = sim.snapshot()
    var restored := Sim.new()
    var ok := restored.restore(snapshots[key])
    var copy := Actor.new()
    game.world.interior.add_child(copy); copy.build(1)
    copy.sync(restored.get_patient(1),false,0)
    check(ok and pose_equal(actor,copy),"save reconstructs exact body transfer: "+key)
    copy.free()
   if p.elapsed > CharacterMotion.TRANSFER_SECONDS and p.elapsed < sim.DURATIONS[p.state]-CharacterMotion.TRANSFER_SECONDS:
    # Once per clinical state, not one assertion per animation frame.
    if not seen.has(p.state+"_paused"):
     check(absf(actor.body.rotation.x+PI/2) < .0001,"service remains lying at actual clinical elapsed time")
     var equipment: Array = game.world.treatment_heads.map(func(node): return node.position)
     var pose := actor.body.transform
     var h := actor.head.transform
     var stride := actor.stride
     var blink := actor.blink_amount
     var saved := sim.snapshot()
     sim.paused = true
     for i in range(8): sim.tick(.2); game.world.sync(sim,1,0)
     check(pose.is_equal_approx(actor.body.transform) and h.is_equal_approx(actor.head.transform) and stride == actor.stride and blink == actor.blink_amount,"pause freezes service pose and idle face: "+p.state)
     check(sim.snapshot() == saved or sim.time == saved.time,"pause does not advance service/payment")
     game.toggle_outside(); game.toggle_outside()
     check(pose.is_equal_approx(actor.body.transform),"inside/outside preserves service pose: "+p.state)
     check(equipment == game.world.treatment_heads.map(func(node): return node.position),"pause and inside/outside preserve actual equipment height: "+p.state)
     sim.paused = false
     seen[p.state+"_paused"] = true
  if sim.completed() > 0 and not expanded:
   check(sim.purchase_expansion(),"existing earnings unlock real annex purchase")
   game.refresh(); expanded = true
   add_geometry(); await physics_frame
  if sim.count_state("treatment") == 2 and not dual:
   dual = true
   var ids := sim.treatment_owners
   check(ids[0] != ids[1] and game.world.actors[ids[0]] != game.world.actors[ids[1]],"two treatment rooms display separate reserved patients")
   var restored := Sim.new()
   var restored_ok := restored.restore(sim.snapshot())
   for id in ids:
    var copy := Actor.new(); game.world.interior.add_child(copy); copy.build(id)
    copy.sync(restored.get_patient(id),false,0)
    check(restored_ok and pose_equal(game.world.actors[id],copy),"simultaneous treatment restores individual room pose: "+str(restored.get_patient(id).room))
    copy.free()
  if p.state == "leaving" and not seen.has("completion"):
   check(p.paid and sim.money >= 500 and actor.caption.visible,"one paid completion produces small nonblocking confirmation")
   check(PatientFeedback.describe(sim,p).heading == "오늘 일정 완료","completion wording refers to today's schedule")
   seen.completion = true
  last_face = face; last_yaw = actor.body.rotation.y; last_state = p.state
  if sim.all_done(): break
 check(sim.all_done() and sim.money == 1100 and sim.lifetime_completed == 4,"four departures and exactly one fee per patient; economy preserved")
 check(dual,"simultaneous treatment exercised")
 check(contacts.is_empty(),"head, torso and walking hands clear actual static and retracted equipment meshes")
 check(max_step < .22,"no large single-frame head teleport during walking and couch transfers")
 check(max_turn < .5,"corridor corners turn gradually")
 for state in ["ct_scan","treatment"]:
  for phase in ["prepare","lie_down","service","rise"]: check(phases.has(state+":"+phase),state+" has visible "+phase)
 check(minji.staff_event_count >= 2,"nearby departure triggers a restrained goodbye")
 var idle_starts := {}
 for person in game.world.actors.values()+game.world.staff_models: idle_starts[person.phase_seed] = true
 check(idle_starts.size() == game.world.actors.size()+game.world.staff_models.size(),"patients and staff have different idle/blink start phases")
 # Compare the same movement under 1x and 2x simulation-scaled updates.
 var a := Actor.new(); var b := Actor.new()
 game.world.interior.add_child(a); game.world.interior.add_child(b); a.build(2); b.build(2)
 var p := {"id":2,"state":"entering","route":[],"position":Vector3.ZERO,"room":-1,"elapsed":0.0}
 a.sync(p,false,0); b.sync(p,false,0)
 for i in range(60):
  p.position.z = (i+1)*2.1/60
  a.sync(p,false,1.0/60)
 for i in range(30):
  p.position.z = (i+1)*2.1/30
  b.sync(p,false,2.0/60)
 check(absf(a.stride-b.stride)<.0001 and absf(a.clock-b.clock)<.0001,"1x/2x stride and idle time agree at equal simulation distance/time")
 var freeze := a.body.transform
 var freeze_stride := a.stride
 var freeze_clock := a.clock
 for i in range(30): a.sync(p,false,0)
 check(a.body.transform.is_equal_approx(freeze) and a.stride == freeze_stride and a.clock == freeze_clock,"zero simulation delta freezes walking and all idle time")
 a.sync(p,true,0)
 var ring_start := a.selection.scale.x
 a.sync(p,true,.12)
 var ring_middle := a.selection.scale.x
 a.sync(p,true,.12)
 check(a.selection.visible and ring_start < ring_middle and ring_middle < a.selection.scale.x and is_equal_approx(a.selection.scale.x,1.0),"mint selection indicator eases in over 0.24 seconds")
 p.state = "plan_ready"
 for i in range(20): a.sync(p,false,1.0/60)
 check(a.gait == 0 and absf(a.left_leg.rotation.x)<.001,"walking settles smoothly after stopping")
 a.free(); b.free()
 var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"max_head_step_60fps":max_step,"max_turn_radians_per_frame":max_turn,"phases":phase_trace,"simultaneous_treatment":dual,"money":sim.money,"completed":sim.completed(),"save_format_changed":false,"geometry_contacts":contacts,"geometry_sample_rate":60}
 FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("MOTION: ",JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)
func _initialize() -> void: call_deferred("run")
