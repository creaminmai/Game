extends Control
const Sim = preload("res://scripts/hospital_simulation.gd")
const World = preload("res://scripts/world.gd")
const Store = preload("res://scripts/save_store.gd")
const TEAL := Color("28695f")
const INK := Color("264c47")
const MUTED := Color("71847a")
var sim = Sim.new()
var store = Store.new()
var world: HospitalWorld
var selected_id := -1
var outside := false
var previous_pause := false
var stats: Label
var notice: Label
var scene_caption: Label
var rows: Array[Button] = []
var action_button: Button
var next_button: Button
var pause_button: Button
var outside_button: Button
var expansion_button: Button
var next_day_button: Button
var detail: Label
var progress: ProgressBar
var confirmation: HospitalGameDialog
var viewport: SubViewport
var scene_container: SubViewportContainer
var hud: Control
var title: Label
var day_label: Label
var goal: Label
var money_panel: PanelContainer
var patient_button: Button
var zoom_in_button: Button
var zoom_out_button: Button
var overview_button: Button
var dismiss_button: Button
var selection_panel: PanelContainer
var roster: PanelContainer
var roster_close: Button
var tool_buttons: Array[Button] = []
var tool_labels: Array[Label] = []
var drag_start := Vector2.ZERO
var dragging := false
var save_time := 0.0
var ui_time := 0.0
var no_save := false

func _ready() -> void:
 no_save = "--no-save" in OS.get_cmdline_user_args() or "--qa" in OS.get_cmdline_user_args()
 if not no_save: store.load_into(sim)
 var theme_resource := Theme.new()
 theme_resource.default_font = load("res://assets/SunshineHangul.otf")
 theme_resource.default_font_size = 21
 theme = theme_resource
 build_ui()
 world = World.new()
 viewport.add_child(world)
 sim.changed.connect(on_change)
 if not store.message.is_empty(): notice.text = store.message
 refresh()

func style(color: Color, border: Color = Color.TRANSPARENT, radius: int = 14) -> StyleBoxFlat:
 var result := StyleBoxFlat.new()
 result.bg_color = color
 result.border_color = border
 result.set_border_width_all(2 if border.a > 0 else 0)
 result.set_corner_radius_all(radius)
 result.content_margin_left = 18
 result.content_margin_right = 18
 result.content_margin_top = 10
 result.content_margin_bottom = 10
 return result

func label_text(text_value: String, font_size: int, color: Color = INK) -> Label:
 var result := Label.new()
 result.text = text_value
 result.add_theme_font_size_override("font_size",font_size)
 result.add_theme_color_override("font_color",color)
 result.mouse_filter = Control.MOUSE_FILTER_IGNORE
 return result

func button(text_value: String, callback: Callable, primary: bool = false) -> Button:
 var result := Button.new()
 result.text = text_value
 result.custom_minimum_size.y = 52
 result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 result.add_theme_stylebox_override("normal",style(TEAL if primary else Color("fffdf5")))
 result.add_theme_stylebox_override("hover",style(Color("3a7c70") if primary else Color("e5eee2")))
 result.add_theme_stylebox_override("pressed",style(Color("21554d") if primary else Color("d5e4d8")))
 result.add_theme_stylebox_override("disabled",style(Color("dedfd4")))
 result.add_theme_stylebox_override("focus",style(Color.TRANSPARENT,Color("dda75b")))
 for name_text in ["font_color","font_hover_color","font_pressed_color"]:
  result.add_theme_color_override(name_text,Color("fffbed") if primary else INK)
 result.add_theme_color_override("font_disabled_color",Color("7b877d"))
 result.pressed.connect(callback)
 return result

func icon_button(symbol: String, caption: String, callback: Callable) -> Button:
 var b := preload("res://scripts/hud_button.gd").new()
 b.symbol = symbol
 b.custom_minimum_size = Vector2(66,66)
 b.tooltip_text = caption
 b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 b.add_theme_stylebox_override("normal",style(Color("36675b"),Color("cfbd8a"),22))
 b.add_theme_stylebox_override("hover",style(Color("497c68"),Color("f2d890"),22))
 b.add_theme_stylebox_override("pressed",style(Color("204e46"),Color("f2d890"),22))
 b.add_theme_stylebox_override("disabled",style(Color("63796b"),Color("aab39b"),22))
 b.add_theme_stylebox_override("focus",style(Color.TRANSPARENT,Color("efcb78"),22))
 b.pressed.connect(callback)
 return b

func place(control: Control, rect: Rect2) -> void:
 control.position = rect.position
 control.size = rect.size

func panel(parent: Node, color: Color = Color("f2ead5")) -> PanelContainer:
 var node := PanelContainer.new()
 node.add_theme_stylebox_override("panel",style(color,Color("b5a679"),20))
 parent.add_child(node)
 return node

func build_ui() -> void:
 scene_container = SubViewportContainer.new()
 scene_container.name = "HospitalView"
 scene_container.stretch = true
 scene_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 scene_container.gui_input.connect(scene_input)
 add_child(scene_container)
 viewport = SubViewport.new()
 viewport.size = Vector2i(720,1280)
 viewport.handle_input_locally = false
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 viewport.own_world_3d = true
 viewport.msaa_3d = Viewport.MSAA_2X
 scene_container.add_child(viewport)
 # UI floats over the world. Transparent regions never intercept world gestures.
 hud = Control.new()
 hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(hud)
 title = label_text("햇살병원",25)
 title.add_theme_color_override("font_shadow_color",Color("fff5db"))
 title.add_theme_constant_override("shadow_outline_size",4)
 hud.add_child(title)
 day_label = label_text("",18)
 hud.add_child(day_label)
 money_panel = panel(hud,Color("f4e5b8"))
 stats = label_text("",24)
 stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 money_panel.add_child(stats)
 pause_button = icon_button("pause","일시정지 / 재생",toggle_pause)
 hud.add_child(pause_button)
 goal = label_text("",19,Color("36584a"))
 goal.add_theme_color_override("font_shadow_color",Color("f9edd1"))
 goal.add_theme_constant_override("shadow_outline_size",4)
 hud.add_child(goal)
 scene_caption = label_text("",17)
 hud.add_child(scene_caption)
 patient_button = icon_button("people","오늘의 환자 목록",toggle_roster)
 next_button = icon_button("attention","지시가 필요한 환자 찾기",select_next_action)
 expansion_button = icon_button("build","치료별관 증축 · 600만",open_expansion)
 outside_button = icon_button("outside","병원 안 / 밖",toggle_outside)
 tool_buttons = [patient_button,next_button,expansion_button,outside_button]
 for i in range(tool_buttons.size()):
  hud.add_child(tool_buttons[i])
  var caption := label_text(["환자","지시 필요","증축","병원 밖"][i],15)
  caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  caption.add_theme_color_override("font_shadow_color",Color("fff4dc"))
  caption.add_theme_constant_override("shadow_outline_size",4)
  hud.add_child(caption)
  tool_labels.append(caption)
 zoom_in_button = icon_button("plus","확대",func(): world.zoom_by(0.82))
 zoom_out_button = icon_button("minus","축소",func(): world.zoom_by(1.22))
 overview_button = icon_button("overview","병원 전체 보기",func(): world.show_overview())
 for b in [zoom_in_button,zoom_out_button,overview_button]: hud.add_child(b)
 selection_panel = panel(hud)
 var content := VBoxContainer.new()
 content.add_theme_constant_override("separation",8)
 selection_panel.add_child(content)
 var info := HBoxContainer.new()
 content.add_child(info)
 detail = label_text("",22)
 detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 info.add_child(detail)
 dismiss_button = button("닫기",clear_selection)
 dismiss_button.custom_minimum_size = Vector2(70,42)
 dismiss_button.add_theme_font_size_override("font_size",17)
 info.add_child(dismiss_button)
 progress = ProgressBar.new()
 progress.custom_minimum_size.y = 8
 progress.show_percentage = false
 progress.add_theme_stylebox_override("background",style(Color("d7d8bd"),Color.TRANSPARENT,4))
 progress.add_theme_stylebox_override("fill",style(Color("6f9c79"),Color.TRANSPARENT,4))
 content.add_child(progress)
 action_button = button("접수하기",perform_action,true)
 action_button.custom_minimum_size.y = 58
 content.add_child(action_button)
 notice = label_text("환자를 누르면 진료할 수 있어요",18)
 notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 notice.add_theme_color_override("font_shadow_color",Color("fff4dc"))
 notice.add_theme_constant_override("shadow_outline_size",4)
 hud.add_child(notice)
 next_day_button = button("오늘 진료 완료 · 다음 날 시작",start_day,true)
 hud.add_child(next_day_button)
 roster = panel(hud)
 var list := VBoxContainer.new()
 list.add_theme_constant_override("separation",10)
 roster.add_child(list)
 var list_heading := HBoxContainer.new()
 list.add_child(list_heading)
 var list_title := label_text("오늘의 환자",26)
 list_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 list_heading.add_child(list_title)
 roster_close = button("닫기",toggle_roster)
 list_heading.add_child(roster_close)
 for id in range(1,5):
  var row := button("",select_patient.bind(id))
  row.name = "Patient%d" % id
  row.alignment = HORIZONTAL_ALIGNMENT_LEFT
  row.custom_minimum_size.y = 68
  row.add_theme_font_size_override("font_size",21)
  rows.append(row)
  list.add_child(row)
 roster.hide()
 confirmation = preload("res://scripts/game_dialog.gd").new()
 confirmation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 confirmation.mouse_filter = Control.MOUSE_FILTER_STOP
 add_child(confirmation)
 var shade := ColorRect.new()
 shade.color = Color(0.07,0.15,0.12,0.55)
 shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 confirmation.add_child(shade)
 confirmation.card = panel(confirmation)
 var dialog_content := VBoxContainer.new()
 dialog_content.add_theme_constant_override("separation",18)
 confirmation.card.add_child(dialog_content)
 var heading := label_text("치료별관",32)
 heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 dialog_content.add_child(heading)
 var message := label_text("치료실을 하나 더 열어요
두 환자를 동시에 치료할 수 있어요",21)
 message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 dialog_content.add_child(message)
 var cost := label_text("증축 비용   600만",28,TEAL)
 cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 dialog_content.add_child(cost)
 var actions := HBoxContainer.new()
 actions.add_theme_constant_override("separation",12)
 dialog_content.add_child(actions)
 confirmation.cancel_button = button("다음에",confirmation.cancel)
 confirmation.ok_button = button("별관 짓기",confirmation.accept,true)
 for b in [confirmation.cancel_button,confirmation.ok_button]:
  b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  actions.add_child(b)
 confirmation.confirmed.connect(confirm_expansion)
 confirmation.canceled.connect(func(): notice.text = "증축을 취소했어요")
 confirmation.hide()
 resized.connect(layout_hud)
 layout_hud.call_deferred()

func layout_hud() -> void:
 var w := size.x
 var h := size.y
 place(title,Rect2(24,28,220,40))
 place(day_label,Rect2(25,72,280,28))
 place(money_panel,Rect2(w-304,26,196,66))
 place(pause_button,Rect2(w-90,26,66,66))
 place(goal,Rect2(24,112,w-120,32))
 place(scene_caption,Rect2(24,151,w-120,26))
 for i in range(tool_buttons.size()):
  place(tool_buttons[i],Rect2(w-90,204+i*96,66,66))
  place(tool_labels[i],Rect2(w-100,271+i*96,86,24))
 var bottom := h-102
 if selection_panel.visible: bottom = h-292
 if next_day_button.visible: bottom = h-178
 place(zoom_in_button,Rect2(24,bottom,66,66))
 place(zoom_out_button,Rect2(102,bottom,66,66))
 place(overview_button,Rect2(180,bottom,66,66))
 var action_width := minf(w-40,680)
 place(selection_panel,Rect2((w-action_width)*0.5,h-208,action_width,178))
 var next_width := minf(w-48,680)
 place(next_day_button,Rect2((w-next_width)*0.5,h-94,next_width,64))
 place(notice,Rect2(24,h-29,w-48,26))
 var roster_width := minf(w-128,592)
 place(roster,Rect2(w-roster_width-104,maxf(180,h*0.26),roster_width,400))
 place(confirmation.card,Rect2((w-540)*0.5,(h-310)*0.5,540,310))

func toggle_roster() -> void:
 roster.visible = not roster.visible

func clear_selection() -> void:
 selected_id = -1
 refresh()

func scene_input(event: InputEvent) -> void:
 if confirmation.visible: return
 if event is InputEventMouseButton:
  if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: world.zoom_by(0.88)
  elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: world.zoom_by(1.14)
  elif event.button_index == MOUSE_BUTTON_LEFT:
   if event.pressed:
    drag_start = event.position
    dragging = false
   else:
    if not dragging and not outside:
     var id := world.pick(event.position)
     if id > 0: select_patient(id)
    dragging = false
 elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
  if event.position.distance_to(drag_start) > 8: dragging = true
  if dragging: world.pan_by(event.relative)
 elif event is InputEventMagnifyGesture:
  world.zoom_by(1.0/event.factor)

func select_patient(id: int) -> void:
 if sim.get_patient(id).is_empty(): return
 selected_id = id
 roster.hide()
 world.focus_patient(sim.get_patient(id).position)
 refresh()

func select_next_action() -> void:
 var id: int = sim.next_action_patient(selected_id)
 if id > 0: select_patient(id)

func perform_action() -> void:
 if outside: return
 var p: Dictionary = sim.get_patient(selected_id)
 if p.is_empty(): return
 if p.state == "waiting": sim.admit(selected_id)
 elif p.state == "plan_ready": sim.assign_plan(selected_id)
 refresh()

func toggle_pause() -> void:
 if outside: return
 sim.paused = not sim.paused
 refresh()

func toggle_outside() -> void:
 if not outside:
  roster.hide()
  previous_pause = sim.paused
  sim.paused = true
  outside = true
 else:
  outside = false
  sim.paused = previous_pause
 world.show_outside(outside)
 refresh()

func open_expansion() -> void:
 var reason: String = sim.expansion_reason()
 if not reason.is_empty(): notice.text = reason; return
 roster.hide()
 confirmation.popup_centered()

func confirm_expansion() -> void:
 if sim.purchase_expansion():
  world.add_wing()
  world.show_overview()
  notice.text = "치료별관이 열렸어요. 이제 두 환자를 동시에 치료합니다."
 else: notice.text = sim.expansion_reason()
 refresh()

func start_day() -> void:
 if outside: return
 if sim.start_next_day():
  selected_id = -1
  notice.text = "%d일차를 시작해요. 자금과 치료별관은 유지됩니다." % sim.day
 refresh()

func refresh() -> void:
 stats.text = "%s만" % sim.money
 day_label.text = "%d일차 · 치료 %d/4" % [sim.day,sim.completed()]
 goal.text = "첫 환자를 치료하면 별관이 열려요" if sim.lifetime_completed == 0 else ("오늘의 환자를 모두 돌봐주세요" if not sim.all_done() else "오늘의 진료를 모두 마쳤어요")
 pause_button.symbol = "play" if sim.paused else "pause"
 pause_button.queue_redraw()
 pause_button.disabled = outside
 tool_labels[3].text = "병원 안" if outside else "병원 밖"
 scene_caption.text = "진료 일시정지" if sim.paused else ""
 expansion_button.tooltip_text = "치료별관 운영 중" if sim.expanded else "치료별관 · 600만"
 expansion_button.disabled = sim.expanded
 for i in range(4):
  var id := i+1
  var p: Dictionary = sim.get_patient(id)
  var active := id == selected_id and not p.is_empty()
  var need: bool = not p.is_empty() and sim.needs_action(p)
  var patient_name: String = p.name if not p.is_empty() else Sim.NAMES[(i+sim.day-1)%4]
  rows[i].text = "%s  %s     %s" % ["●" if active else "%02d" % id,patient_name,sim.status_text(id)]
  rows[i].disabled = p.is_empty()
  rows[i].add_theme_stylebox_override("normal",style(Color("e1eee3") if active else (Color("fff0de") if need else Color("fffdf5")),TEAL if active else Color.TRANSPARENT))
  rows[i].tooltip_text = "도착 후 선택할 수 있어요" if p.is_empty() else "환자 선택 · " + sim.status_text(id)
 next_button.disabled = sim.next_action_patient(selected_id) == -1
 var p: Dictionary = sim.get_patient(selected_id)
 action_button.disabled = outside or sim.paused or p.is_empty() or not sim.needs_action(p)
 action_button.text = "병원 안에서 진료" if outside else ("재생 후 지시 가능" if sim.paused else "진료 진행 중")
 progress.value = 0
 if not p.is_empty():
  detail.text = "%s · %s" % [p.name,sim.status_text(selected_id)]
  if Sim.DURATIONS.has(p.state):
   progress.value = p.elapsed / Sim.DURATIONS[p.state] * 100
   detail.text += "  %d초 남음" % maxi(0,ceili(Sim.DURATIONS[p.state]-p.elapsed))
  if not outside and not sim.paused:
   if p.state == "waiting": action_button.text = "선택 환자 접수"
   elif p.state == "plan_ready": action_button.text = "박 선생에게 계획 맡기기"
 selection_panel.visible = not p.is_empty() and not outside and not sim.all_done()
 next_day_button.visible = sim.all_done()
 next_day_button.disabled = outside
 if sim.all_done(): notice.text = "오늘 모두 귀가했어요! 다음 날에도 병원을 이어 운영해요."
 layout_hud()
 if is_instance_valid(world): world.sync(sim,selected_id,0)

func on_change() -> void:
 save_time = 2.0

func _process(delta: float) -> void:
 if not is_instance_valid(world): return
 sim.tick(delta)
 world.sync(sim,selected_id,delta if not sim.paused else 0.0)
 ui_time += delta
 save_time += delta
 if ui_time >= 0.15:
  ui_time = 0
  refresh()
 if save_time >= 2.0:
  save_time = 0
  persist()

func persist() -> void:
 if no_save: return
 if not store.save(sim) and not store.message.is_empty(): notice.text = store.message

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
  persist()
