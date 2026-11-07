class_name HospitalDayJournal
extends Control
signal next_requested
signal closed
var card: Panel
var heading: Label
var date_label: Label
var quote: Label
var values: Array[Label] = []
var facility: Label
var next_button: Button
var close_button: Button

func build(game: Control) -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter = Control.MOUSE_FILTER_STOP
 var shade := ColorRect.new()
 shade.color = Color(.12,.21,.18,.35)
 shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(shade)
 card = Panel.new()
 card.add_theme_stylebox_override("panel",HospitalUiSkin.frame())
 add_child(card)
 heading = game.label_text("오늘의 병원 일지",28,game.TEAL)
 card.add_child(heading); game.place(heading,Rect2(24,16,340,40))
 date_label = game.label_text("",19)
 card.add_child(date_label); game.place(date_label,Rect2(24,54,300,28))
 var seal: Label = game.label_text("✓ 일정 완료",22,game.TEAL)
 card.add_child(seal); game.place(seal,Rect2(386,30,160,38))
 var portrait := HospitalUiSkin.picture("res://assets/ui/portrait-minji.png",56)
 card.add_child(portrait); game.place(portrait,Rect2(22,90,56,56))
 quote = game.label_text("",22)
 quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 card.add_child(quote); game.place(quote,Rect2(90,87,452,65))
 var captions := ["일정을 마친 환자","오늘의 진료 수입","오늘의 증축 지출","현재 보유 자금"]
 for i in range(4):
  var rule := ColorRect.new()
  rule.color = Color("e2d8c2"); rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
  card.add_child(rule); game.place(rule,Rect2(26,198+i*38,518,1))
  var caption: Label = game.label_text(captions[i],22)
  card.add_child(caption); game.place(caption,Rect2(26,162+i*38,245,34))
  var value: Label = game.label_text("",24,game.TEAL if i == 3 else game.INK)
  value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
  card.add_child(value); game.place(value,Rect2(276,162+i*38,268,34))
  values.append(value)
 facility = game.label_text("",20,game.TEAL)
 card.add_child(facility); game.place(facility,Rect2(26,319,518,34))
 close_button = game.button("병원 둘러보기",func(): hide(); closed.emit())
 next_button = game.button("다음 날 시작",func(): next_requested.emit(),true)
 for b in [close_button,next_button]:
  b.add_theme_font_size_override("font_size",23)
  b.custom_minimum_size.y = 62
  card.add_child(b)
 game.place(close_button,Rect2(24,368,246,62))
 game.place(next_button,Rect2(282,368,264,62))
 hide()

func present(sim: HospitalSimulation) -> void:
 if not sim.all_done(): return
 date_label.text = "%d일차 · 햇살병원" % sim.day
 quote.text = "민지 · 오늘 오신 분들 얼굴이 기억나요.\n내일도 편하게 오실 수 있게 가꿔봐요." if sim.day == 1 else "민지 · 오늘의 일정을 모두 마쳤어요.\n내일도 차근차근 함께해요."
 values[0].text = "%d명" % sim.completed()
 values[1].text = "%d만" % sim.ledger.income
 values[2].text = "%d만" % sim.ledger.expansion_expense if sim.ledger.expansion_expense >= 0 else "기록 없음 · 이전 저장"
 values[2].add_theme_font_size_override("font_size",24 if sim.ledger.expansion_expense >= 0 else 20)
 values[3].text = "%d만" % sim.money
 facility.text = "새 시설  ·  치료별관  ✓" if sim.ledger.new_annex else ("새 시설  ·  이전 기록 없음" if sim.ledger.opening_money < 0 else "새 시설  ·  없음")
 show()

func layout(game: Control) -> void:
 game.place(card,Rect2((game.size.x-570)*.5,(game.size.y-448)*.5,570,448))

func _unhandled_key_input(event: InputEvent) -> void:
 if visible and event.is_action_pressed("ui_cancel"):
  hide(); closed.emit()
  get_viewport().set_input_as_handled()
