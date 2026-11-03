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
var selected_id := 1
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
var confirmation: ConfirmationDialog
var viewport: SubViewport
var scene_container: SubViewportContainer
var root_column: VBoxContainer
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

func build_ui() -> void:
 var background := ColorRect.new()
 background.color = Color("f6f2e7")
 background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 background.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(background)
 var margin := MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,20)
 add_child(margin)
 root_column = VBoxContainer.new()
 root_column.add_theme_constant_override("separation",10)
 margin.add_child(root_column)
 var heading := HBoxContainer.new()
 root_column.add_child(heading)
 var title_column := VBoxContainer.new()
 title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 title_column.add_theme_constant_override("separation",0)
 heading.add_child(title_column)
 title_column.add_child(label_text("SUNSHINE  /  작은 병원의 하루",15,MUTED))
 title_column.add_child(label_text("햇살병원",35))
 pause_button = button("일시정지",toggle_pause)
 heading.add_child(pause_button)
 stats = label_text("",23)
 root_column.add_child(stats)
 var separator := HSeparator.new()
 root_column.add_child(separator)
 scene_caption = label_text("방사선과  ·  환자를 누르거나 아래 목록에서 선택하세요",17,MUTED)
 root_column.add_child(scene_caption)
 scene_container = SubViewportContainer.new()
 scene_container.name = "HospitalView"
 scene_container.stretch = true
 scene_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
 scene_container.custom_minimum_size.y = 280
 scene_container.gui_input.connect(scene_input)
 root_column.add_child(scene_container)
 viewport = SubViewport.new()
 viewport.size = Vector2i(680,500)
 viewport.handle_input_locally = false
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 viewport.own_world_3d = true
 scene_container.add_child(viewport)
 var view_actions := HBoxContainer.new()
 view_actions.add_theme_constant_override("separation",10)
 root_column.add_child(view_actions)
 outside_button = button("병원 밖",toggle_outside)
 view_actions.add_child(outside_button)
 expansion_button = button("치료별관 · 600만",open_expansion)
 expansion_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 view_actions.add_child(expansion_button)
 var list_title := HBoxContainer.new()
 root_column.add_child(list_title)
 var list_label := label_text("오늘의 환자",22)
 list_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 list_title.add_child(list_label)
 next_button = button("조작 필요한 환자 →",select_next_action)
 next_button.add_theme_font_size_override("font_size",18)
 list_title.add_child(next_button)
 for id in range(1,5):
  var row := button("",select_patient.bind(id))
  row.name = "Patient%d" % id
  row.alignment = HORIZONTAL_ALIGNMENT_LEFT
  row.custom_minimum_size.y = 52
  row.add_theme_font_size_override("font_size",20)
  rows.append(row)
  root_column.add_child(row)
 detail = label_text("",19)
 detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 detail.custom_minimum_size.y = 30
 root_column.add_child(detail)
 progress = ProgressBar.new()
 progress.custom_minimum_size.y = 7
 progress.show_percentage = false
 progress.add_theme_stylebox_override("background",style(Color("e0e1d3"),Color.TRANSPARENT,4))
 progress.add_theme_stylebox_override("fill",style(Color("73a78f"),Color.TRANSPARENT,4))
 root_column.add_child(progress)
 var commands := HBoxContainer.new()
 commands.add_theme_constant_override("separation",10)
 root_column.add_child(commands)
 action_button = button("접수하기",perform_action,true)
 action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 commands.add_child(action_button)
 next_day_button = button("다음 날 시작",start_day)
 next_day_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 commands.add_child(next_day_button)
 notice = label_text("환자를 선택하고 접수해 주세요. 첫 치료 후 별관을 지을 수 있어요.",16,MUTED)
 notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 notice.custom_minimum_size.y = 42
 root_column.add_child(notice)
 confirmation = ConfirmationDialog.new()
 confirmation.title = "치료별관 증축"
 confirmation.dialog_text = "600만으로 치료실을 하나 더 만듭니다.\n두 환자를 동시에 치료할 수 있어요."
 confirmation.ok_button_text = "600만 지불 · 증축"
 confirmation.cancel_button_text = "취소"
 confirmation.min_size = Vector2i(500,220)
 confirmation.confirmed.connect(confirm_expansion)
 confirmation.canceled.connect(func(): notice.text = "증축을 취소했어요. 자금은 그대로예요.")
 add_child(confirmation)

func scene_input(event: InputEvent) -> void:
 if outside: return
 if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
  var id := world.pick(event.position)
  if id > 0: select_patient(id)

func select_patient(id: int) -> void:
 if sim.get_patient(id).is_empty(): return
 selected_id = id
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
 confirmation.popup_centered()

func confirm_expansion() -> void:
 if sim.purchase_expansion():
  world.add_wing()
  notice.text = "치료별관이 열렸어요. 이제 두 환자를 동시에 치료합니다."
 else: notice.text = sim.expansion_reason()
 refresh()

func start_day() -> void:
 if outside: return
 if sim.start_next_day():
  selected_id = 1
  notice.text = "%d일차를 시작해요. 자금과 치료별관은 유지됩니다." % sim.day
 refresh()

func refresh() -> void:
 stats.text = "%d일차   /   자금 %s만   /   치료 %d/4" % [sim.day,sim.money,sim.completed()]
 pause_button.text = "재생" if sim.paused else "일시정지"
 pause_button.disabled = outside
 outside_button.text = "병원 안으로" if outside else "병원 밖"
 scene_caption.text = "병원 외관  ·  진료는 잠시 멈춰 있어요" if outside else "방사선과  ·  환자 또는 목록을 눌러 선택"
 expansion_button.text = "치료별관 운영 중 · 치료실 2개" if sim.expanded else "치료별관 증축 · 600만"
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
 next_day_button.visible = sim.all_done()
 next_day_button.disabled = outside
 if sim.all_done(): notice.text = "오늘 모두 귀가했어요! 다음 날에도 병원을 이어 운영해요."
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
