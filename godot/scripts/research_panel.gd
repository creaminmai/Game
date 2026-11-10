class_name HospitalResearchPanel
extends Control
# The scroll area grows, never the touch-target density. This is an actual
# operational screen over the exterior model, not a rendered illustration.
var game: Control
var card: Panel
var heading: Label
var balance: Label
var summary: Label
var scroll: ScrollContainer
var contents: VBoxContainer
var build_button: Button
var close_button: Button
var return_button: Button
var project_buttons: Dictionary = {}
var project_status: Dictionary = {}
var project_reasons: Dictionary = {}
var texts: Array[Label] = []
var confirmation: HospitalGameDialog
var confirm_title: Label
var confirm_body: Label
var confirm_reason: Label
var pending := ""

func build(owner_game: Control) -> void:
 game = owner_game
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter = Control.MOUSE_FILTER_STOP
 card = Panel.new(); card.add_theme_stylebox_override("panel",HospitalUiSkin.frame()); add_child(card)
 heading = game.label_text("연구소 1단계",26,game.TEAL); card.add_child(heading)
 close_button = game.button("연구소 보기",func(): close(); game.world.focus_lab()); card.add_child(close_button)
 balance = game.label_text("",23,game.TEAL); card.add_child(balance)
 scroll = ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; card.add_child(scroll)
 contents = VBoxContainer.new(); contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL; contents.add_theme_constant_override("separation",14); scroll.add_child(contents)
 summary = add_text("",22)
 build_button = game.button("연구소 설립 · 1,800만",offer.bind("build"),true); contents.add_child(build_button)
 for id in ["ct","plan"]:
  var box := PanelContainer.new(); box.mouse_filter = Control.MOUSE_FILTER_PASS
  box.add_theme_stylebox_override("panel",HospitalUiSkin.frame()); contents.add_child(box)
  var column := VBoxContainer.new(); column.add_theme_constant_override("separation",8); box.add_child(column)
  var title: Label = game.label_text(HospitalResearchLab.PROJECTS[id],24,game.TEAL); column.add_child(title); texts.append(title)
  var description: Label = game.label_text("비용 500만 + 연구점수 6점\n"+("CT 단계만 5초 → 4초" if id == "ct" else "계획 검토만 5초 → 4초 · 자동 준비 3초 유지"),22)
  description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; column.add_child(description); texts.append(description)
  var status_label: Label = game.label_text("",22); status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; column.add_child(status_label); texts.append(status_label); project_status[id] = status_label
  var reason: Label = game.label_text("",22); reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; column.add_child(reason); texts.append(reason); project_reasons[id] = reason
  var b: Button = game.button("비용·일정 확인",offer.bind(id),true); column.add_child(b); project_buttons[id] = b
 return_button = game.button("병원으로 돌아가기",func(): close(); if game.outside: game.toggle_outside(),true); card.add_child(return_button)
 build_confirmation()
 hide()

func add_text(value: String, font: int) -> Label:
 var label: Label = game.label_text(value,font)
 label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 contents.add_child(label); texts.append(label)
 return label

func build_confirmation() -> void:
 confirmation = HospitalGameDialog.new(); confirmation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(confirmation)
 var shade := ColorRect.new(); shade.color = Color(.08,.18,.15,.35); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE; shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); confirmation.add_child(shade)
 confirmation.card = game.panel(confirmation)
 confirmation.card.minimum_size_changed.connect(layout.call_deferred)
 var column := VBoxContainer.new(); column.add_theme_constant_override("separation",16); confirmation.card.add_child(column)
 confirm_title = game.label_text("",27,game.TEAL); column.add_child(confirm_title)
 confirm_body = game.label_text("",23); confirm_body.custom_minimum_size.x = 540; confirm_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; column.add_child(confirm_body)
 confirm_reason = game.label_text("",22,game.TEAL); confirm_reason.custom_minimum_size.x = 540; confirm_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; column.add_child(confirm_reason)
 var actions := HBoxContainer.new(); actions.add_theme_constant_override("separation",14); column.add_child(actions)
 confirmation.cancel_button = game.button("다음에",confirmation.cancel)
 confirmation.ok_button = game.button("",confirmation.accept,true)
 for b in [confirmation.cancel_button,confirmation.ok_button]: b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; actions.add_child(b)
 confirmation.confirmed.connect(commit)
 confirmation.canceled.connect(func(): pending = ""; refresh())
 confirmation.hide()

func open() -> void:
 show(); refresh(); layout()

func close() -> void:
 confirmation.hide(); pending = ""; hide()
 game.world.preview_lab(false)
 game.refresh()

func offer(id: String) -> void:
 pending = id
 if id == "build":
  confirm_title.text = "연구소 1단계 · 설립 확인"
  confirm_body.text = "설립비 1,800만 · 최초 연구점수 6점\n연구 슬롯 1개 · 진료한 날 마감에 4점\n보관 상한 200점 · 일일 운영비 없음"
  confirmation.ok_button.text = "연구소 짓기"
 else:
  confirm_title.text = HospitalResearchLab.PROJECTS[id]
  confirm_body.text = "500만 + 연구점수 6점 사용\n%d일차 마감 예정 / %d일차부터 적용\n%s\n시작 후 취소·환불은 없어요." % [game.sim.day+1,game.sim.day+2,"CT 단계만 5초 → 4초" if id == "ct" else "계획 검토만 5초 → 4초 · 준비 3초 유지"]
  confirmation.ok_button.text = "연구 시작"
 confirmation.popup_centered(); refresh(); layout()

func commit() -> void:
 var success: bool = game.sim.purchase_lab() if pending == "build" else game.sim.start_research(pending)
 if success:
  if pending == "build":
   game.world.sync(game.sim,game.selected_id,0)
   game.world.preview_lab(false)
  game.persist()
 pending = ""; refresh(); game.refresh()

func refresh() -> void:
 var sim: HospitalSimulation = game.sim
 var lab := sim.research
 balance.text = "연구점수 %d / 200 · 보유 자금 %d만" % [lab.points,sim.money]
 var today := lab.daily(sim.day)
 summary.text = "윤서진 · 진료 기록을 살펴보는 연구 담당\n연구 슬롯 1개 · 실제 진료한 날 마감에 4점\n오늘 최초 +%d / 생산 +%d / 사용 -%d" % [today.initial,today.produced,today.used]
 if lab.built_day == 0: summary.text = "병원 옆 예정지에 연구소를 마련해요.\n설립비 1,800만 · 최초 연구점수 6점\n슬롯 1개 · 운영일 마감 생산 4점 · 상한 200점\n"+lab.build_reason(sim)
 build_button.visible = lab.built_day == 0
 build_button.disabled = lab.build_reason(sim) != ""
 for id in project_buttons:
  project_status[id].text = lab.status(id)
  project_reasons[id].text = lab.start_reason(sim,id) if not lab.projects.has(id) else ""
  project_reasons[id].visible = project_reasons[id].text != ""
  project_buttons[id].disabled = lab.start_reason(sim,id) != ""
  project_buttons[id].text = "적용 완료 ✓" if lab.applied(id) else ("진행·적용 대기" if lab.projects.has(id) else "비용·일정 확인")
 if confirmation.visible:
  var reason: String = lab.build_reason(sim) if pending == "build" else lab.start_reason(sim,pending)
  confirm_reason.text = reason if reason != "" else "확인하면 비용을 한 번 사용해요."
  confirmation.ok_button.disabled = reason != ""

func layout() -> void:
 var scale_to_pixels: float = game.ui_display_size.y/game.size.y
 var touch := maxf(48,ceilf(44/scale_to_pixels))
 var font := maxi(22,ceili(15/scale_to_pixels))
 var area: Rect2 = game.safe_ui
 var width := minf(610,area.size.x-36)
 var height := minf(600,area.size.y-24)
 game.place(card,Rect2(area.end-Vector2(width+12,height+12),Vector2(width,height)))
 game.place(heading,Rect2(20,12,width-190,40))
 game.place(close_button,Rect2(width-162,10,142,touch))
 balance.add_theme_font_size_override("font_size",font)
 game.place(balance,Rect2(20,22+touch,width-40,40))
 game.place(scroll,Rect2(16,68+touch,width-32,height-96-touch*2))
 for text in texts: text.add_theme_font_size_override("font_size",font)
 for b in [close_button,return_button,build_button,confirmation.ok_button,confirmation.cancel_button]+project_buttons.values():
  b.custom_minimum_size.y = touch; b.add_theme_font_size_override("font_size",font)
 game.place(return_button,Rect2(20,height-touch-14,width-40,touch))
 game.place(confirmation.card,Rect2(area.position+(area.size-Vector2(590,360+touch))*.5,Vector2(590,360+touch)))

func _unhandled_key_input(event: InputEvent) -> void:
 if visible and not confirmation.visible and event.is_action_pressed("ui_cancel"):
  close(); get_viewport().set_input_as_handled()
