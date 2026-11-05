extends SceneTree
var game: Control
var checks := 0
var failures: Array[String] = []
var output := ""
var selected_by_input := 0
var collision_models := {}
var camera_metrics := {}

func camera_snapshot() -> Dictionary:
 var center: Vector3 = game.world.view_center
 return {"center":[center.x,center.y,center.z],"size":game.world.camera.size}

func check(condition: bool, caption: String) -> void:
 checks += 1
 if not condition:
  failures.append(caption)
  printerr("FAIL: ",caption)

func settle() -> void:
 await process_frame
 await process_frame
 if is_instance_valid(game) and is_instance_valid(game.world):
  while game.world.transition_active: await process_frame

func model_bounds(model: Node3D) -> AABB:
 var found := false
 var bounds := AABB()
 for mesh in model.find_children("*","MeshInstance3D",true,false):
  if not mesh.is_visible_in_tree(): continue
  var local_bounds: AABB = (model.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
  bounds = bounds.merge(local_bounds) if found else local_bounds
  found = true
 return bounds

func click(control: Control) -> void:
 var point := control.get_global_rect().get_center()
 point *= Vector2(root.size)/root.get_visible_rect().size
 var move := InputEventMouseMotion.new()
 move.position = point
 Input.parse_input_event(move)
 var down := InputEventMouseButton.new()
 down.button_index = MOUSE_BUTTON_LEFT
 down.pressed = true
 down.position = point
 Input.parse_input_event(down)
 await process_frame
 down = InputEventMouseButton.new()
 down.button_index = MOUSE_BUTTON_LEFT
 down.position = point
 down.pressed = false
 Input.parse_input_event(down)
 await settle()

func shot(name_text: String) -> void:
 game.update_bubble()
 await RenderingServer.frame_post_draw
 var image := root.get_texture().get_image()
 check(image.save_png(output.path_join(name_text+".png")) == OK,"capture " + name_text)

func check_layout(caption: String) -> void:
 var screen := Rect2(Vector2.ZERO,root.get_visible_rect().size)
 var good := true
 var controls: Array[Control] = []
 for row in game.rows: controls.append(row)
 controls.append_array([game.pause_button,game.outside_button,game.expansion_button,game.action_button,game.next_button,game.notice,
  game.patient_button,game.zoom_in_button,game.zoom_out_button,game.overview_button,game.selection_panel,game.detail,game.dismiss_button,
  game.money_panel,game.goal,game.next_day_button,game.roster_close])
 controls.append_array([game.speed_button,game.reason_label,game.speech_bubble,game.patient_view_button])
 for stage in game.stages: controls.append(stage)
 for control in controls:
  if control.is_visible_in_tree() and not screen.encloses(control.get_global_rect()):
   printerr("Outside viewport: ",control.name," ",control.get_global_rect()," screen ",screen)
   good = false
 check(good,caption + " controls fit viewport")
 check(game.scene_container.get_global_rect() == screen,caption + " 3D fills the whole viewport")
 check(absf(screen.size.aspect()-Vector2(root.size).aspect()) < 0.01,caption + " viewport expands without letterboxing")

func check_projected(points: Array[Vector3], caption: String) -> void:
 var clear := true
 var scale_to_hud := game.size/Vector2(game.viewport.size)
 for point in points:
  var pixel: Vector2 = game.world.camera.unproject_position(point)*scale_to_hud
  clear = clear and pixel.y > 120 and pixel.y < game.size.y-94 and pixel.x > 20
  clear = clear and pixel.x < game.size.x-18
  if game.selection_panel.visible:
   clear = clear and not game.selection_panel.get_global_rect().grow(6).has_point(pixel)
  if not clear: printerr("OCCLUDED ",caption," ",pixel)
 check(clear,caption)

func add_visibility_geometry() -> void:
 for model in game.world.interior.get_children():
  if not model.has_meta("hospital_static") or collision_models.has(model.get_instance_id()): continue
  for mesh in model.find_children("*","MeshInstance3D",true,false):
   var collider := StaticBody3D.new()
   collider.collision_layer = 8
   collider.collision_mask = 0
   var shape := CollisionShape3D.new()
   shape.shape = mesh.mesh.create_trimesh_shape()
   collider.add_child(shape)
   mesh.add_child(collider)
  collision_models[model.get_instance_id()] = true

func check_face_visible(p: Dictionary) -> void:
 add_visibility_geometry()
 await physics_frame
 var head: Node3D = game.world.actors[p.id].head
 var face := head.to_global(Vector3(0,.065,.34))
 var pixel: Vector2 = game.world.camera.unproject_position(face)
 var start: Vector3 = game.world.camera.project_ray_origin(pixel)
 var query := PhysicsRayQueryParameters3D.create(start,face,8)
 var hit: Dictionary = game.world.get_world_3d().direct_space_state.intersect_ray(query)
 check(hit.is_empty(),"treatment face is visible past actual device triangles in room %d" % p.room)
 if not hit.is_empty(): printerr("FACE OCCLUSION ",hit.position," face ",face)

func couch_bounds(model: Node3D, origin: Vector3, yaw: float) -> AABB:
 var space := Transform3D(Basis(Vector3.UP,yaw),origin).affine_inverse()
 var bounds := AABB()
 var found := false
 for mesh in model.find_children("*","MeshInstance3D",true,false):
  if not mesh.is_visible_in_tree(): continue
  var local: AABB = (space*mesh.global_transform)*mesh.get_aabb()
  bounds = bounds.merge(local) if found else local
  found = true
 return bounds

func check_couch_pose(p: Dictionary) -> void:
 var actor = game.world.actors[p.id]
 var torso = actor.body.find_child("Torso",true,false)
 var yaw := deg_to_rad(-35) if p.state == "treatment" else 0.0
 var body_bounds := couch_bounds(torso,p.position,yaw)
 var head_bounds := couch_bounds(actor.head,p.position,yaw)
 print("COUCH ",p.state," torso ",body_bounds," head ",head_bounds)
 check(body_bounds.position.y >= 1.055 and body_bounds.position.y < 1.14,"body rests on mattress without sinking or floating")
 check(head_bounds.position.y >= 1.18 and head_bounds.position.y < 1.26,"head supported by pillow")
 check(absf(head_bounds.get_center().z+.91) < .15,"head aligned with actual pillow")
 if p.state == "treatment":
  check(body_bounds.end.y < 1.6875-.08,"torso clears collimator aperture")
  # The chin may project into the head footprint, but below its solid housing.
  check(head_bounds.get_center().z < -.75 and body_bounds.end.y < 1.6075,"face behind collimator with torso clearance")
 var bounds := couch_bounds(actor.body,p.position,yaw)
 check(bounds.position.z >= -1.4 and bounds.end.z <= 1.4,"lying patient stays on the couch length")

func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
 if output.is_empty(): output = ProjectSettings.globalize_path("res://../artifacts/validation")
 DirAccess.make_dir_recursive_absolute(output)
 root.size = Vector2i(960,540)
 game = load("res://main.tscn").instantiate()
 root.add_child(game)
 await settle()
 game.set_process(false)
 check(game.no_save,"QA never reads or writes user save")
 await click(game.speed_button)
 check(game.playback_speed == 2.0,"speed button enables double-speed play")
 await click(game.speed_button)
 check(game.playback_speed == 1.0,"speed button restores normal speed")
 check(game.rows.size() == 4 and game.rows[1].disabled,"future arrivals visible but not selectable")
 check(not game.roster.visible and not game.selection_panel.visible,"HUD starts without list or patient card")
 await click(game.patient_button)
 check(game.roster.visible,"patient roster opens on request")
 await click(game.rows[2])
 check(game.selected_id == -1,"future arrival click preserves selection")
 await click(game.roster_close)
 game.sim.tick(24)
 game.refresh()
 await settle()
 check_layout("960x540 landscape")
 check(game.world.actors[1].seated and game.world.actors[1].book.visible,"waiting patient sits and reads at the chair")
 var patient_bounds := model_bounds(game.world.actors[1].body)
 check(patient_bounds.position.y > -0.05 and patient_bounds.end.y < 2.1 and patient_bounds.size.y > 1.7,"imported patient parts stay within the intended body proportions")
 var nurse_bounds := model_bounds(game.world.staff_models[0].body)
 check(nurse_bounds.position.y > -0.05 and nurse_bounds.end.y < 2.1 and nurse_bounds.size.y > 1.7,"imported nurse working pose keeps connected body proportions")
 var ao_correct := true
 var material_response := {}
 var ao_count := 0
 for instance in game.world.interior.find_children("*","MeshInstance3D",true,false):
  for surface in range(instance.mesh.get_surface_count()):
   var material: Material = instance.get_active_material(surface)
   if material is StandardMaterial3D and material.ao_enabled:
    ao_count += 1
    ao_correct = ao_correct and material.ao_on_uv2
    material_response[material.resource_name] = material.roughness
 check(ao_correct and ao_count >= 25,"imported hospital occlusion uses its atlas coordinates")
 check(is_equal_approx(material_response.get("Coral woven upholstery",0.0),.82) and is_equal_approx(material_response.get("Honey oak",0.0),.46) and is_equal_approx(material_response.get("white",0.0),.26),"cloth, wood and coated equipment retain separate material responses")
 check_projected([Vector3(-5.43,3.05,-3.7),Vector3(-2.57,3.05,-3.7),Vector3(-4,1.1,-1.53)],"default framing keeps CT clear of header and goal")
 check(not game.notice.is_visible_in_tree(),"no persistent instruction text over the hospital")
 await shot("01-fullscreen-game")
 camera_metrics.default_view = camera_snapshot()
 var operating_size: float = game.world.camera.size
 var operating_center: Vector3 = game.world.view_center
 game.select_patient(1)
 await settle()
 check(is_equal_approx(game.world.camera.size,operating_size),"opening patient card keeps operating zoom")
 check(game.world.view_center.is_equal_approx(operating_center),"selecting an already visible patient keeps camera position")
 camera_metrics.patient_card = camera_snapshot()
 var targets := {}
 for key in ["patient_button","action_button"]:
  var rect: Rect2 = game.get(key).get_global_rect()
  targets[key] = [rect.get_center().x,rect.get_center().y]
 FileAccess.open(output.path_join("ui-targets.json"),FileAccess.WRITE).store_string(JSON.stringify(targets))
 root.size = Vector2i(1280,720)
 await settle()
 await settle()
 game.refresh()
 await settle()
 check_layout("1280x720 selected-patient review")
 check(game.viewport.size == Vector2i(1280,720),"world renders at display resolution independently of the logical HUD")
 print("REVIEW PANEL: ",game.selection_panel.get_global_rect()," world render: ",game.viewport.size)
 await shot("01-patient-admission")
 await click(game.patient_view_button)
 check(game.world.camera.size < operating_size*.85,"explicit patient-view button enlarges the patient")
 await shot("01-explicit-patient-view")
 await click(game.overview_button)
 check(is_equal_approx(game.world.camera.size,operating_size) and game.world.view_center.is_equal_approx(operating_center),"hospital button restores the stable operating view")
 game.world.focus_patient(game.sim.get_patient(1))
 check(game.world.transition_active and is_equal_approx(game.world.camera.size,operating_size),"automatic transition starts without snapping")
 game.world._process(.21)
 check(game.world.camera.size < operating_size and game.world.camera.size > game.world.target_size,"transition passes through an intermediate view at 0.21 seconds")
 await settle()
 await click(game.overview_button)
 game.world.zoom_by(.7)
 game.world.pan_by(Vector2(-1600,0))
 var offscreen: Vector2 = game.world.camera.unproject_position(game.world.actors[1].head.global_position)
 check(not game.world.play_area.has_point(offscreen),"offscreen-selection test starts with the patient outside the usable view")
 var preserved_zoom: float = game.world.camera.size
 game.select_patient(1)
 await settle()
 var revealed: Vector2 = game.world.camera.unproject_position(game.world.actors[1].head.global_position)
 check(game.world.play_area.has_point(revealed) and is_equal_approx(game.world.camera.size,preserved_zoom),"offscreen selection pans the patient into view without zooming")
 var nearest: Vector2 = offscreen.clamp(game.world.play_area.position,game.world.play_area.end)
 check(offscreen.distance_to(revealed) <= offscreen.distance_to(nearest)+45,"offscreen reveal stops near the edge instead of centering the room")
 await click(game.overview_button)
 root.size = Vector2i(960,540)
 game.clear_selection()
 await settle()
 var initial_zoom: float = game.world.camera.size
 await click(game.zoom_in_button)
 check(game.world.camera.size < initial_zoom,"zoom button enlarges actual 3D")
 await click(game.overview_button)
 check(game.world.overview_mode,"overview returns to full hospital")
 await click(game.patient_button)
 await shot("02-patient-roster")
 await click(game.rows[2])
 check(game.selected_id == 3,"patient list selection via real input")
 check_projected([Vector3(-4.5,1.9,3.8),Vector3(-4,3.05,-3.7),Vector3(-4,1.1,-1.53)],"selected patient and CT fit beside the patient card")
 check(not game.roster.visible and game.selection_panel.visible,"selection closes roster and shows contextual action")
 selected_by_input += 1
 game.sim.tick(0.5); game.refresh()
 check(game.selected_id == 3,"refresh never steals selection")
 await click(game.action_button)
 check(game.sim.ct_owner == 3,"selected patient admitted via real input")
 check(not game.world.actors[3].seated and game.world.actors[3].left_leg.visible,"admitted patient stands for CT travel")
 await click(game.next_button)
 check(game.selected_id == 4,"explicit helper cycles patients needing action")
 await click(game.action_button)
 check(game.sim.queue_rank(4) == 1 and game.rows[3].text.contains("1번째"),"queue ordinal displayed after input")
 check(game.action_button.disabled and game.action_button.text.contains("CT 대기"),"queued patient is labeled waiting rather than undergoing care")
 check(game.reason_label.text.contains("이동 중") and game.reason_label.text.contains("추가 지시 없이"),"reserved CT explains preceding travel and automatic queue")
 await shot("02-ct-queue")
 # Clicking actual patient geometry uses the same viewport ray query as mouse/touch input.
 var actor: Node3D = game.world.actors[1]
 var local: Vector2 = game.world.camera.unproject_position(actor.position+actor.body.position+Vector3(0,1.0,0))
 var event := InputEventMouseButton.new()
 event.button_index = MOUSE_BUTTON_LEFT
 event.pressed = true
 event.position = game.scene_container.global_position+local
 Input.parse_input_event(event)
 await settle()
 event = InputEventMouseButton.new()
 event.button_index = MOUSE_BUTTON_LEFT
 event.position = game.scene_container.global_position+local
 Input.parse_input_event(event)
 await settle()
 check(game.selected_id == 1,"3D patient selection via real input ray")
 # Dragging moves the camera, without treating the gesture as a patient tap.
 var old_center: Vector3 = game.world.view_center
 var old_selection: int = game.selected_id
 var press := InputEventMouseButton.new()
 press.button_index = MOUSE_BUTTON_LEFT
 press.pressed = true
 press.position = Vector2(220,280)
 Input.parse_input_event(press)
 await settle()
 var drag := InputEventMouseMotion.new()
 drag.position = Vector2(280,300)
 drag.relative = Vector2(60,20)
 drag.button_mask = MOUSE_BUTTON_MASK_LEFT
 Input.parse_input_event(drag)
 await settle()
 press = InputEventMouseButton.new()
 press.button_index = MOUSE_BUTTON_LEFT
 press.position = Vector2(280,300)
 Input.parse_input_event(press)
 await settle()
 check(game.world.view_center != old_center and game.selected_id == old_selection,"world drag pans without selecting")
 await click(game.zoom_in_button)
 var manual_center: Vector3 = game.world.view_center
 var manual_size: float = game.world.camera.size
 await click(game.action_button)
 game.sim.tick(.5)
 game.refresh()
 await settle()
 check(game.sim.get_patient(1).state != "waiting","manual-camera regression includes an actual patient state change")
 check(not game.world.auto_frame and game.world.view_center.is_equal_approx(manual_center) and is_equal_approx(game.world.camera.size,manual_size),"state updates preserve user drag and zoom")
 await click(game.pause_button)
 var frozen: Dictionary = game.sim.snapshot()
 game.sim.tick(3)
 check(game.sim.snapshot() == frozen,"pause button stops simulation")
 await click(game.outside_button)
 check(game.outside and game.sim.paused,"outside pauses treatment")
 await click(game.outside_button)
 check(game.sim.paused,"return preserves previous paused state")
 await click(game.pause_button)
 await click(game.outside_button)
 await click(game.outside_button)
 check(not game.sim.paused,"return restores running state")
 var expanded := false
 var dual_seen := false
 var restore_checked := false
 var poses_checked := {}
 var selected_states := {}
 var roster_camera_checked := false
 for iteration in range(600):
  for p in game.sim.patients:
   if game.sim.needs_action(p):
    var check_roster_camera := false
    if p.state == "plan_ready" and not roster_camera_checked and not game.sim.expanded:
     game.clear_selection()
     await click(game.overview_button)
     var patient_pixel: Vector2 = game.world.camera.unproject_position(game.world.actors[p.id].head.global_position)*game.size/Vector2(game.viewport.size)
     check_roster_camera = patient_pixel.x > game.size.x-378 and patient_pixel.x < game.size.x-264
    await click(game.patient_button)
    var before_roster_selection: Vector3 = game.world.view_center
    await click(game.rows[p.id-1])
    if check_roster_camera:
     check(game.world.view_center.is_equal_approx(before_roster_selection),"roster selection uses the opened card area, not the closed list width")
     roster_camera_checked = true
    selected_by_input += 1
    await click(game.action_button)
  game.sim.tick(0.5)
  game.refresh()
  for p in game.sim.patients:
   if p.state in ["ct_scan","treatment"]:
    var pose_key: String = p.state+str(p.room)
    if not poses_checked.has(pose_key):
     check_couch_pose(p)
     poses_checked[pose_key] = true
     game.select_patient(p.id)
     await settle()
     var x: float = -4.0 if p.state == "ct_scan" else 4.0+6.0*p.room
     var z: float = -2.8 if p.state == "ct_scan" else 3.0
     check_projected([Vector3(x,3.05,z-.9),Vector3(x,1.2,z+1.3),game.world.actors[p.id].head.global_position],"active patient and device clear the card: "+pose_key)
     await physics_frame
     var face: Vector3 = game.world.actors[p.id].head.to_global(Vector3(0,.065,.34))
     check(game.world.pick(game.world.camera.unproject_position(face)) == p.id,"lying patient face remains selectable: "+pose_key)
     if p.state == "treatment": await check_face_visible(p)
     await shot("pose-"+pose_key)
   if p.state in ["plan_queue","treatment_queue"] and not selected_states.has(p.state):
    game.select_patient(p.id)
    await settle()
    check(game.action_button.disabled and game.action_button.text.contains("대기") and game.reason_label.text.contains("자동"),p.state+" has truthful queue feedback")
    check(game.detail.get_line_count() == 2,"queue heading keeps patient name and status on two lines")
    if p.state == "treatment_queue":
     var queue_points: Array[Vector3] = [game.world.actors[p.id].head.global_position,Vector3(4,3.05,2.1),Vector3(4,1.2,4.3)]
     if game.sim.expanded: queue_points.append_array([Vector3(10,3.05,2.1),Vector3(10,1.2,4.3)])
     check_projected(queue_points,"waiting patient and occupied treatment devices clear the HUD")
     await shot("treatment-queue")
    selected_states[p.state] = true
  if game.sim.completed() > 0 and not expanded:
   await click(game.outside_button)
   var money: int = game.sim.money
   await click(game.expansion_button)
   check(game.confirmation.visible,"purchase dialog opens via input")
   await click(game.confirmation.get_cancel_button())
   check(game.sim.money == money and not game.sim.expanded,"cancel costs nothing")
   await click(game.expansion_button)
   await shot("03-expansion-confirmation")
   await click(game.confirmation.get_ok_button())
   check(game.sim.expanded and game.sim.money == money-600,"confirm button buys actual annex")
   check(game.world.wing_built and game.world.beams.size() == 2,"annex creates second physical device")
   await shot("04-exterior-expanded")
   await click(game.outside_button)
   expanded = true
  if game.sim.count_state("treatment") == 2 and not dual_seen:
   await click(game.dismiss_button)
   await click(game.overview_button)
   await settle()
   await shot("05-two-treatments")
   camera_metrics.expanded_view = camera_snapshot()
   dual_seen = true
   var copy = load("res://scripts/hospital_simulation.gd").new()
   restore_checked = copy.restore(game.sim.snapshot()) and copy.paused
  if game.sim.all_done(): break
 check(poses_checked.size() == 3,"CT and both treatment couches verified")
 check(roster_camera_checked,"roster-to-card camera regression exercised the boundary patient")
 check(game.sim.all_done() and game.sim.completed() == 4,"four patients complete and leave")
 check(game.sim.money == 1100 and expanded,"day one economy after annex")
 check(dual_seen and restore_checked,"concurrent treatment captured and restorable")
 check(game.next_day_button.visible,"next-day button appears after departure")
 await shot("06-day-complete")
 await click(game.next_day_button)
 check(game.sim.day == 2 and game.sim.patients.size() == 1,"next day through real input")
 game.refresh(); await settle()
 check(game.world.actors.size() == 1,"previous day actors removed")
 for dimensions in [Vector2i(640,360),Vector2i(844,390),Vector2i(1280,720),Vector2i(1024,768),Vector2i(390,844)]:
  root.size = dimensions
  await settle()
  game.refresh()
  await settle()
  check_layout(str(dimensions))
  check(game.orientation_hint.visible == (dimensions.x < dimensions.y),str(dimensions)+" rotation hint follows orientation")
  game.select_patient(1)
  await settle()
  check_layout(str(dimensions)+" patient action")
  if dimensions.x >= dimensions.y:
   check_projected([Vector3(-4,3.05,-3.7),Vector3(-4,1.1,-1.53)],str(dimensions)+" CT remains below HUD with selected card")
  await click(game.patient_button)
  check(game.roster.visible,str(dimensions)+" roster opens after resize")
  check_layout(str(dimensions)+" roster")
  await click(game.roster_close)
  await click(game.dismiss_button)
  check(not game.selection_panel.visible,str(dimensions)+" patient action closes after resize")
  await shot("layout-%dx%d" % [dimensions.x,dimensions.y])
 var report := {"checks": checks,"failures": failures,"passed": failures.is_empty(),"selected_by_real_input": selected_by_input,"camera_views":camera_metrics,
  "completed":4,"money_after_day_one":1100,"dual_treatment_captured":dual_seen,"android_ios_tested":false,
  "note":"Desktop Godot automatic input QA, not manual playtest or mobile performance measurement."}
 var file := FileAccess.open(output.path_join("results.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  ")); file.close()
 print("SCENE: %d checks, %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
 run.call_deferred()
