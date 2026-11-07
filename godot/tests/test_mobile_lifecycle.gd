extends SceneTree
# Run in a unique XDG_DATA_HOME per case. Two separate OS processes exercise
# actual main._ready / atomic disk restore, never the player's user directory.
var game: Control
var failures: Array[String] = []
var checks := 0
var scenario := "moving"
var mode := "prepare"
var output := ""
func _initialize() -> void: run.call_deferred()
func check(value: bool, caption: String) -> void:
 checks += 1
 if not value: failures.append(caption); printerr("FAIL: ",caption)
func advance() -> void:
 for p in game.sim.patients:
  if p.state == "waiting": game.sim.admit(p.id)
  elif p.state == "plan_ready": game.sim.assign_plan(p.id)
 game.sim.tick(.05)
func reached() -> bool:
 var p: Dictionary = game.sim.get_patient(1)
 match scenario:
  "moving","user-paused": return p.get("state") == "walk_ct"
  "ct": return p.get("state") == "ct_scan" and p.elapsed > 1.0
  "therapy": return p.get("state") == "treatment" and p.elapsed > 1.0
  "purchase": return game.sim.expansion_reason().is_empty()
  "journal","day-two": return game.sim.all_done()
  "dual": return game.sim.count_state("treatment") == 2
 return false
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--case="): scenario = arg.trim_prefix("--case=")
  if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
  if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
 game = load("res://main.tscn").instantiate()
 root.add_child(game); game.set_process(false)
 await process_frame; await process_frame
 var checkpoint_path := output.path_join(scenario+"-checkpoint.json")
 if mode == "prepare":
  check(game.sim.money == 900 and game.sim.patients.size() == 1 and game.sim.time == 0,"isolated fresh store")
  for step in range(30000):
   advance()
   if scenario in ["journal","day-two","dual"] and game.sim.expansion_reason().is_empty(): game.sim.purchase_expansion()
   if reached(): break
  check(reached(),"reached actual scenario through normal operating rules")
  if scenario == "purchase":
   game.confirm_expansion()
   check(game.sim.expanded and game.sim.ledger.expansion_expense == 600,"purchase charged once")
  if scenario == "day-two": game.start_day()
  game.story.disable(); game.refresh()
  if scenario == "user-paused": game.toggle_pause()
  var expected: Dictionary = game.sim.snapshot()
  # These are injected platform notifications, not physical-device switching.
  game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
  game._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
  game.sim.tick(120)
  var frozen: Dictionary = game.sim.snapshot()
  check(frozen.patients == expected.patients and frozen.money == expected.money and frozen.time == expected.time,"background never advances treatment or receipts")
  game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
  check(game.sim.paused,"background hold survives focus-in ordering")
  game._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED)
  check(game.sim.paused == (scenario == "user-paused"),"resume preserves user pause intent")
  game.toggle_outside(); game._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED); game._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED)
  check(game.sim.paused and game.outside,"outside pause survives app resume")
  game.toggle_outside()
  game._web_visibility([true]); game.sim.tick(120); game._web_visibility([false])
  check(game.sim.money == expected.money and game.sim.snapshot().patients == expected.patients,"web visibility uses independent no-offline-progress hold")
  game.persist()
  FileAccess.open(checkpoint_path,FileAccess.WRITE).store_string(JSON.stringify(game.sim.snapshot()))
 else:
  var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(checkpoint_path))
  var restored: Dictionary = JSON.parse_string(JSON.stringify(game.sim.snapshot()))
  check(not game.store.blocked and game.store.message.contains("불러왔어요"),"main ready loads actual saved file")
  for key in ["day","money","expanded","patients","daily_ledger","lifetime_completed"]:
   check(restored[key] == expected[key],"separate process restores "+key)
  check(game.sim.paused,"relaunch safely waits for user play")
  game._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED)
  check(game.sim.paused,"resume event never unpauses a restored game")
  game.sim.tick(100)
  check(game.sim.money == expected.money,"relaunch gives no duplicate fee")
  if game.sim.expanded:
   check(game.world.wing_built and game.sim.treatment_owners.size() == 2,"restored annex is complete and usable")
   check(not game.sim.purchase_expansion() and game.sim.money == expected.money,"restored purchase cannot charge twice")
  if scenario == "journal": check(game.journal.visible and game.journal.values[3].text == "1100만","journal resumes actual 800/600/1100 ledger")
  if scenario == "day-two": check(game.sim.day == 2 and game.sim.ledger.income == 0 and game.sim.ledger.expansion_expense == 0,"new day resets receipts only")
  if scenario == "dual": check(game.world.actors.size() == game.sim.patients.size() and game.sim.count_state("treatment") == 2,"both restored treatment actors exist")
  game.persist()
 var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"case":scenario,"phase":mode,"platform":"Linux headless; injected lifecycle notifications + real process restart"}
 FileAccess.open(output.path_join(scenario+"-"+mode+".json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("MOBILE LIFECYCLE ",scenario," ",mode,": ",checks," checks, ",failures.size()," failures")
 game.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
