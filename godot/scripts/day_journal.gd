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
var chapter_stamp: Label
var training_value: Label
var financial_scroll: ScrollContainer
var financial_content: Control
var research_detail: Label
var lab_value: Label
var research_value: Label
var research_rows: Array[Control] = []
var portrait: TextureRect

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
 chapter_stamp = game.label_text("",20,game.TEAL)
 chapter_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
 card.add_child(chapter_stamp); game.place(chapter_stamp,Rect2(330,58,216,28))
 portrait = HospitalUiSkin.picture("res://assets/ui/portrait-minji.png",56)
 card.add_child(portrait); game.place(portrait,Rect2(22,90,56,56))
 quote = game.label_text("",22)
 quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 card.add_child(quote); game.place(quote,Rect2(90,87,452,65))
 var financial_nodes: Array[Control] = []
 var captions := ["일정을 마친 환자","오늘의 진료 수입","오늘의 증축 지출","운영 교육 지출","현재 보유 자금"]
 for i in range(5):
  var rule := ColorRect.new()
  rule.color = Color("e2d8c2"); rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
  financial_nodes.append(rule)
  card.add_child(rule); game.place(rule,Rect2(26,198+i*38,518,1))
  var caption: Label = game.label_text(captions[i],22)
  financial_nodes.append(caption)
  card.add_child(caption); game.place(caption,Rect2(26,162+i*38,245,34))
  var value: Label = game.label_text("",24,game.TEAL if i == 4 else game.INK)
  value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
  financial_nodes.append(value)
  card.add_child(value); game.place(value,Rect2(276,162+i*38,268,34))
  if i == 3: training_value = value
  else: values.append(value)
 facility = game.label_text("",20,game.TEAL)
 card.add_child(facility); game.place(facility,Rect2(26,357,518,34))
 financial_nodes.append(facility)
 financial_scroll = ScrollContainer.new()
 financial_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 card.add_child(financial_scroll); game.place(financial_scroll,Rect2(0,162,570,232))
 financial_content = Control.new(); financial_content.custom_minimum_size = Vector2(548,230)
 financial_scroll.add_child(financial_content)
 for node in financial_nodes:
  var old_position := node.position
  node.reparent(financial_content,false); node.position = old_position-Vector2(0,162)
 for i in range(2):
  var caption: Label = game.label_text(["연구소 설립 지출","연구 시작 지출"][i],22)
  financial_content.add_child(caption); game.place(caption,Rect2(26,238+i*40,280,36)); research_rows.append(caption)
  var value: Label = game.label_text("",24,game.TEAL)
  value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
  financial_content.add_child(value); game.place(value,Rect2(316,238+i*40,220,36)); research_rows.append(value)
  if i == 0: lab_value = value
  else: research_value = value
 research_detail = game.label_text("",22)
 research_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 financial_content.add_child(research_detail); research_rows.append(research_detail)
 game.place(research_detail,Rect2(26,326,510,280))
 close_button = game.button("병원 둘러보기",func(): hide(); closed.emit())
 next_button = game.button("다음 날 시작",func(): next_requested.emit(),true)
 for b in [close_button,next_button]:
  b.add_theme_font_size_override("font_size",23)
  b.custom_minimum_size.y = 62
  card.add_child(b)
 game.place(close_button,Rect2(24,406,246,62))
 game.place(next_button,Rect2(282,406,264,62))
 hide()

func present(sim: HospitalSimulation, guidance_enabled: bool = true) -> void:
 if not sim.all_done(): return
 date_label.text = "%d일차 · 누적 방문 %d회" % [sim.day,sim.chapters.total()]
 quote.text = "민지 · 오늘 오신 분들 얼굴이 기억나요.\n내일도 편하게 오실 수 있게 가꿔봐요." if sim.day == 1 else "민지 · 오늘의 일정을 모두 마쳤어요.\n내일도 차근차근 함께해요."
 chapter_stamp.text = ""
 portrait.texture = load("res://assets/ui/portrait-minji.png")
 var chapter := 2 if sim.chapters.chapter_two_day > 0 else (1 if sim.chapters.chapter_one_day > 0 else 0)
 if chapter > 0:
  chapter_stamp.text = "✓ %d장 완료" % chapter
  if not chapter in sim.chapters.presented:
   sim.chapters.presented.append(chapter)
   if chapter == 2 and guidance_enabled:
    quote.text = "민지 · 한 분씩도 바빴던 병원이\n이제 조금씩 자리를 잡아가네요."
 if sim.operations.chapter_three_day > 0:
  chapter_stamp.text = "✓ 3장 완료"
  if not sim.operations.presented:
   sim.operations.presented = true
   if guidance_enabled: quote.text = "민지 · 함께 맡으니 여유가 생겼어요.\n환자분 말씀도 더 들을 수 있었어요."
 if sim.research.chapter_four_day > 0:
  chapter_stamp.text = "✓ 4장 완료" if sim.day == sim.research.chapter_four_day or not sim.research.presented else ""
  if not sim.research.presented:
   sim.research.presented = true
   if guidance_enabled:
    quote.text = "윤서진 · 기록에서 찾은 첫 개선을\n오늘의 운영에 적용했어요."
    portrait.texture = load("res://assets/ui/portrait-researcher.png")
 var has_lab := sim.research.built_day > 0
 for node in research_rows: node.visible = has_lab
 financial_content.custom_minimum_size.y = 620 if has_lab else 230
 lab_value.text = "%d만" % sim.ledger.lab_expense
 research_value.text = "%d만" % sim.ledger.research_expense
 var research_day := sim.research.daily(sim.day)
 research_detail.text = "연구점수 잔액 %d / 200\n최초 지급 +%d · 마감 생산 +%d · 사용 −%d\n" % [sim.research.points,research_day.initial,research_day.produced,research_day.used]
 for id in ["ct","plan"]:
  if sim.research.projects.has(id): research_detail.text += "\n"+sim.research.PROJECTS[id]+"\n"+sim.research.status(id)+"\n"
 financial_scroll.scroll_vertical = 0
 training_value.text = "%d만" % sim.ledger.training_expense
 values[0].text = "%d명" % sim.completed()
 values[1].text = "%d만" % sim.ledger.income
 values[2].text = "%d만" % sim.ledger.expansion_expense if sim.ledger.expansion_expense >= 0 else "기록 없음 · 이전 저장"
 values[2].add_theme_font_size_override("font_size",24 if sim.ledger.expansion_expense >= 0 else 20)
 values[3].text = "%d만" % sim.money
 facility.text = "새 시설  ·  치료별관  ✓" if sim.ledger.new_annex else ("새 시설  ·  이전 기록 없음" if sim.ledger.opening_money < 0 else "새 시설  ·  없음")
 if sim.ledger.opening_money >= 0: facility.text = "시작 %d만 · " % sim.ledger.opening_money + ("새 시설: 치료별관 ✓" if sim.ledger.new_annex else "새 시설 없음")
 if has_lab: facility.text = "시작 %d만 · 연구 내역은 아래로 ↓" % sim.ledger.opening_money if sim.ledger.opening_money >= 0 else "이전 시작 자금 기록 없음 · 연구 내역 ↓"
 show()

func layout(game: Control) -> void:
 var touch := maxf(62,ceilf(44*game.size.y/game.ui_display_size.y))
 var dimensions := Vector2(570,424+touch)
 game.place(card,Rect2(game.safe_ui.position+(game.safe_ui.size-dimensions)*.5,dimensions))
 for b in [close_button,next_button]: b.custom_minimum_size.y = touch
 game.place(close_button,Rect2(24,406,246,touch))
 game.place(next_button,Rect2(282,406,264,touch))

func _unhandled_key_input(event: InputEvent) -> void:
 if visible and event.is_action_pressed("ui_cancel"):
  hide(); closed.emit()
  get_viewport().set_input_as_handled()
