class_name HospitalSaveStore
extends RefCounted
var path := "user://hospital_v2.json"
var blocked := false
var message := ""

func load_into(sim: HospitalSimulation) -> bool:
 if not FileAccess.file_exists(path):
  if path == "user://hospital_v2.json" and FileAccess.file_exists("user://first_visit_v1.json"):
   blocked = true
   message = "이전 버전 저장을 발견했어요. 호환 확인 전까지 원본을 보존합니다."
  return false
 var file := FileAccess.open(path,FileAccess.READ)
 if file == null:
  blocked = true
  message = "저장을 읽을 수 없어 원본을 보존합니다."
  return false
 var parser := JSON.new()
 var error := parser.parse(file.get_as_text())
 var data: Variant = parser.data if error == OK else null
 if not sim.restore(data):
  blocked = true
  message = "저장 형식을 확인할 수 없어 원본을 보존합니다."
  return false
 message = "이전 진료를 불러왔어요. 재생을 눌러 이어가세요."
 return true

func save(sim: HospitalSimulation) -> bool:
 if blocked: return false
 var temporary := path + ".tmp"
 var file := FileAccess.open(temporary,FileAccess.WRITE)
 if file == null:
  message = "저장할 공간을 확인해 주세요."
  return false
 file.store_string(JSON.stringify(sim.snapshot()))
 file.flush()
 file.close()
 if DirAccess.rename_absolute(temporary,path) != OK:
  message = "저장 파일 교체에 실패했습니다."
  return false
 return true
