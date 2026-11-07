class_name HospitalSaveStore
extends RefCounted
var path := "user://hospital_v2.json"
var blocked := false
var message := ""

func load_into(sim: HospitalSimulation, story: FirstDayStory = null) -> bool:
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
 if data is Dictionary and data.has("first_day_story") and not FirstDayStory.valid(data.first_day_story):
  blocked = true
  message = "이야기 저장 형식을 확인할 수 없어 원본을 보존합니다."
  return false
 if not sim.restore(data):
  blocked = true
  message = "저장 형식을 확인할 수 없어 원본을 보존합니다."
  return false
 message = "이전 진료를 불러왔어요. 재생을 눌러 이어가세요."
 if story != null: story.restore(data.get("first_day_story"))
 return true

func save(sim: HospitalSimulation, story: FirstDayStory = null) -> bool:
 if blocked: return false
 var temporary := path + ".tmp"
 var file := FileAccess.open(temporary,FileAccess.WRITE)
 if file == null:
  message = "저장할 공간을 확인해 주세요."
  return false
 var data := sim.snapshot()
 if story != null: data.first_day_story = story.snapshot()
 file.store_string(JSON.stringify(data))
 file.flush()
 file.close()
 if DirAccess.rename_absolute(temporary,path) != OK:
  message = "저장 파일 교체에 실패했습니다."
  return false
 return true
