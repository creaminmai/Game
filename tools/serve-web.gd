extends SceneTree
# Small LAN-only delivery helper run by the already-installed Godot editor.
# It serves the exported web directory; it never reads native game saves.
var server := TCPServer.new()
var clients: Array[Dictionary] = []
var web_root := ""
var port := 8765
func _initialize() -> void:
 var args := OS.get_cmdline_user_args()
 if args.is_empty(): printerr("Usage: godot --headless --script serve-web.gd -- /absolute/web [port]"); quit(1); return
 web_root = args[0].simplify_path().trim_suffix("/")
 if args.size() > 1: port = int(args[1])
 if not FileAccess.file_exists(web_root.path_join("index.html")) or server.listen(port,"0.0.0.0") != OK:
  printerr("Could not serve web directory; check path or occupied port."); quit(1); return
 print("Web server ready on port ",port,". Keep this window open; use this Mac's LAN address on the same Wi-Fi.")
func _process(_delta: float) -> bool:
 while server.is_connection_available():
  clients.append({"peer":server.take_connection(),"header":"","file":null,"sent":false,"started":Time.get_ticks_msec()})
 for i in range(clients.size()-1,-1,-1):
  var c: Dictionary = clients[i]
  var peer: StreamPeerTCP = c.peer
  peer.poll()
  if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED or Time.get_ticks_msec()-c.started > 120000:
   peer.disconnect_from_host(); clients.remove_at(i); continue
  if not c.sent:
   var count := peer.get_available_bytes()
   if count == 0: continue
   c.header += peer.get_utf8_string(count)
   if c.header.length() > 16384: peer.disconnect_from_host(); continue
   if not c.header.contains("\r\n\r\n"): continue
   var request: PackedStringArray = c.header.split("\r\n")[0].split(" ")
   var relative := request[1].split("?")[0].uri_decode().trim_prefix("/") if request.size() >= 2 else ""
   if relative.is_empty(): relative = "index.html"
   var path := web_root.path_join(relative).simplify_path()
   if request.size() < 2 or request[0] not in ["GET","HEAD"] or not path.begins_with(web_root+"/") or not FileAccess.file_exists(path):
    peer.put_data("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".to_utf8_buffer()); peer.disconnect_from_host(); continue
   c.file = FileAccess.open(path,FileAccess.READ)
   var types := {"html":"text/html; charset=utf-8","js":"application/javascript","wasm":"application/wasm","png":"image/png","svg":"image/svg+xml","json":"application/json"}
   peer.put_data(("HTTP/1.1 200 OK\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: no-cache\r\nConnection: close\r\n\r\n" % [types.get(path.get_extension(),"application/octet-stream"),c.file.get_length()]).to_utf8_buffer())
   c.sent = true
   if request[0] == "HEAD": c.file.close(); peer.disconnect_from_host(); continue
  if c.file != null and c.file.is_open():
   # Partial writes avoid stalling other browser asset requests.
   var at: int = c.file.get_position()
   var data: PackedByteArray = c.file.get_buffer(65536)
   var result := peer.put_partial_data(data)
   if result[0] != OK: peer.disconnect_from_host(); continue
   c.file.seek(at+result[1])
   if c.file.get_position() >= c.file.get_length():
    c.file.close(); peer.disconnect_from_host()
 return false
