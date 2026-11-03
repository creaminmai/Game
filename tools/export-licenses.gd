extends SceneTree
func _initialize() -> void:
 var args := OS.get_cmdline_user_args()
 if args.size() != 1:
  quit(1)
  return
 var file := FileAccess.open(args[0].path_join("LICENSE-Godot.txt"),FileAccess.WRITE)
 if file == null:
  quit(1)
  return
 file.store_string(Engine.get_license_text()+"\n")
 var info := Engine.get_license_info()
 for name in info:
  file.store_string("\n"+name+"\n"+info[name]+"\n")
 file.close()
 quit(0)
