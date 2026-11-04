extends Control
const Sim = preload("res://scripts/hospital_simulation.gd")
const World = preload("res://scripts/world.gd")
const Feedback = preload("res://scripts/patient_feedback.gd")
const Store = preload("res://scripts/save_store.gd")
const UISkin = preload("res://scripts/ui_skin.gd")
const TEAL := Color("339f8c")
const INK := Color("634833")
const MUTED := Color("8d8069")
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
var scene_container: TextureRect
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
var orientation_hint: Label
var tool_buttons: Array[Button] = []
var tool_labels: Array[Label] = []
var drag_start := Vector2.ZERO
var dragging := false
var save_time := 0.0
var ui_time := 0.0
var no_save := false
var top_bar: PanelContainer
var goal_ribbon: PanelContainer
var dock: PanelContainer
var brand_portrait: TextureRect
var patient_portrait: TextureRect
var outside_label: Label
var speed_button: Button
var playback_speed := 1.0
var stages: Array[PanelContainer] = []
var stage_labels: Array[Label] = []
var reason_label: Label
var toast: PanelContainer
var notice_timer: Timer
var speech_bubble: PanelContainer
var bubble_text: Label
var recording_caption := ""

func _ready() -> void:
 no_save = "--no-save" in OS.get_cmdline_user_args() or "--qa" in OS.get_cmdline_user_args()
 if not no_save: store.load_into(sim)
 var theme_resource := Theme.new()
 var rounded_font := FontVariation.new()
 rounded_font.base_font = load("res://assets/SunshineHangul.otf")
 rounded_font.variation_embolden = 0.65
 theme_resource.default_font = rounded_font
 theme_resource.default_font_size = 18
 theme = theme_resource
 build_ui()
 world = World.new()
 viewport.add_child(world)
 sim.changed.connect(on_change)
 if not store.message.is_empty(): show_notice(store.message)
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
 result.custom_minimum_size.y = 44
 result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 result.add_theme_stylebox_override("normal",UISkin.frame("primary" if primary else "panel"))
 result.add_theme_stylebox_override("hover",UISkin.frame("primary" if primary else "panel",Color(1.04,1.04,1.02)))
 result.add_theme_stylebox_override("pressed",UISkin.frame("primary" if primary else "panel",Color(.88,.94,.9)))
 result.add_theme_stylebox_override("disabled",UISkin.frame("panel",Color(.88,.88,.83)))
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
 b.add_theme_stylebox_override("normal",UISkin.frame("panel"))
 b.add_theme_stylebox_override("hover",UISkin.frame("primary"))
 b.add_theme_stylebox_override("pressed",UISkin.frame("primary",Color(.9,.96,.92)))
 b.add_theme_stylebox_override("disabled",UISkin.frame("panel",Color(.83,.85,.8)))
 b.add_theme_stylebox_override("focus",style(Color.TRANSPARENT,Color("efcb78"),22))
 b.pressed.connect(callback)
 return b

func place(control: Control, rect: Rect2) -> void:
 control.position = rect.position
 control.size = rect.size

func panel(parent: Node, color: Color = Color("f2ead5")) -> PanelContainer:
 var node := PanelContainer.new()
 node.add_theme_stylebox_override("panel",UISkin.frame())
 parent.add_child(node)
 return node

func build_ui() -> void:
 scene_container = TextureRect.new()
 scene_container.name = "HospitalView"
 scene_container.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 scene_container.stretch_mode = TextureRect.STRETCH_SCALE
 scene_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 scene_container.gui_input.connect(scene_input)
 add_child(scene_container)
 viewport = SubViewport.new()
 viewport.size = Vector2i(960,540)
 viewport.handle_input_locally = false
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 viewport.own_world_3d = true
 viewport.msaa_3d = Viewport.MSAA_2X
 scene_container.add_child(viewport)
 scene_container.texture = viewport.get_texture()
 # UI floats over the world. Transparent regions never intercept world gestures.
 hud = Control.new()
 hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(hud)
 top_bar = panel(hud)
 dock = panel(hud)
 goal_ribbon = panel(hud)
 brand_portrait = UISkin.picture("res://assets/ui/portrait-minji.png",52)
 hud.add_child(brand_portrait)
 title = label_text("햇살병원",26,Color("175b50"))
 title.add_theme_color_override("font_shadow_color",Color("fff5db"))
 title.add_theme_constant_override("shadow_outline_size",4)
 hud.add_child(title)
 day_label = label_text("",16)
 hud.add_child(day_label)
 money_panel = panel(hud,Color("f4e5b8"))
 stats = label_text("",22)
 stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 var money_content := HBoxContainer.new()
 money_panel.add_child(money_content)
 money_content.add_child(UISkin.picture("res://assets/ui/coin.svg",34))
 stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 money_content.add_child(stats)
 pause_button = icon_button("pause","일시정지 / 재생",toggle_pause)
 pause_button.add_theme_stylebox_override("normal",UISkin.frame("primary"))
 hud.add_child(pause_button)
 speed_button = button("x1",toggle_speed)
 speed_button.tooltip_text = "진행 속도 1배 / 2배"
 hud.add_child(speed_button)
 goal = label_text("",16,Color("36584a"))
 goal.add_theme_color_override("font_shadow_color",Color("f9edd1"))
 goal.add_theme_constant_override("shadow_outline_size",4)
 goal_ribbon.add_child(goal)
 scene_caption = label_text("",14)
 hud.add_child(scene_caption)
 patient_button = icon_button("people","오늘의 환자 목록",toggle_roster)
 next_button = icon_button("attention","지시가 필요한 환자 찾기",select_next_action)
 expansion_button = icon_button("build","치료별관 증축 · 600만",open_expansion)
 outside_button = icon_button("outside","병원 안 / 밖",toggle_outside)
 overview_button = icon_button("overview","병원 전체 보기",func(): world.show_overview())
 tool_buttons = [overview_button,patient_button,next_button,expansion_button]
 hud.add_child(outside_button)
 outside_label = label_text("병원 밖",14)
 outside_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 hud.add_child(outside_label)
 for i in range(tool_buttons.size()):
  tool_buttons[i].custom_minimum_size = Vector2(56,56)
  hud.add_child(tool_buttons[i])
  var caption := label_text(["병원","환자","진료","증축"][i],15)
  caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  caption.add_theme_color_override("font_shadow_color",Color("fff4dc"))
  caption.add_theme_constant_override("shadow_outline_size",4)
  hud.add_child(caption)
  tool_labels.append(caption)
 zoom_in_button = icon_button("plus","확대",func(): world.zoom_by(0.82))
 zoom_out_button = icon_button("minus","축소",func(): world.zoom_by(1.22))
 for b in [zoom_in_button,zoom_out_button]:
  b.custom_minimum_size = Vector2(44,44)
  hud.add_child(b)
 selection_panel = panel(hud)
 var content := VBoxContainer.new()
 content.add_theme_constant_override("separation",5)
 selection_panel.add_child(content)
 var info := HBoxContainer.new()
 content.add_child(info)
 patient_portrait = UISkin.picture("res://assets/ui/portrait-patient-1.png",52)
 info.add_child(patient_portrait)
 detail = label_text("",16)
 detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 info.add_child(detail)
 dismiss_button = icon_button("close","환자 정보 닫기",clear_selection)
 dismiss_button.custom_minimum_size = Vector2(32,32)
 var close_style := style(Color.TRANSPARENT)
 close_style.content_margin_left = 2; close_style.content_margin_right = 2
 close_style.content_margin_top = 2; close_style.content_margin_bottom = 2
 for state in ["normal","hover","pressed","disabled"]:
  dismiss_button.add_theme_stylebox_override(state,close_style)
 dismiss_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
 dismiss_button.add_theme_font_size_override("font_size",17)
 info.add_child(dismiss_button)
 progress = ProgressBar.new()
 var journey := VBoxContainer.new()
 journey.add_theme_constant_override("separation",4)
 content.add_child(journey)
 for i in range(4):
  var stage := PanelContainer.new()
  stage.custom_minimum_size.y = 28
  var stage_content := HBoxContainer.new()
  stage.add_child(stage_content)
  stage_content.add_child(UISkin.picture("res://assets/ui/"+["people","ct","plan","treatment"][i]+".svg",24))
  var caption := label_text(["접수","CT 촬영","치료 계획","방사선 치료"][i],15)
  stage_content.add_child(caption)
  stages.append(stage)
  stage_labels.append(caption)
  journey.add_child(stage)
 reason_label = label_text("",13)
 reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 reason_label.custom_minimum_size.y = 60
 content.add_child(reason_label)
 progress.custom_minimum_size.y = 6
 progress.show_percentage = false
 var track := style(Color("e5ddc8"),Color.TRANSPARENT,3)
 track.content_margin_top = 0; track.content_margin_bottom = 0
 var fill: StyleBoxFlat = track.duplicate()
 fill.bg_color = TEAL
 progress.add_theme_stylebox_override("background",track)
 progress.add_theme_stylebox_override("fill",fill)
 content.add_child(progress)
 action_button = button("접수하기",perform_action,true)
 action_button.custom_minimum_size.y = 44
 action_button.add_theme_font_size_override("font_size",16)
 content.add_child(action_button)
 var patient_link := button("환자 목록  >",toggle_roster)
 patient_link.custom_minimum_size.y = 32
 patient_link.add_theme_font_size_override("font_size",15)
 content.add_child(patient_link)
 toast = panel(hud)
 toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
 notice = label_text("",14)
 notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 toast.add_child(notice)
 toast.hide()
 notice_timer = Timer.new()
 notice_timer.one_shot = true
 notice_timer.wait_time = 4.0
 add_child(notice_timer)
 notice_timer.timeout.connect(func(): toast.hide())
 speech_bubble = PanelContainer.new()
 speech_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
 var bubble_style := StyleBoxTexture.new()
 bubble_style.texture = load("res://assets/ui/speech.svg")
 for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
  bubble_style.set_texture_margin(side,16)
  bubble_style.set_content_margin(side,14 if side in [SIDE_LEFT,SIDE_RIGHT] else 8)
 speech_bubble.add_theme_stylebox_override("panel",bubble_style)
 bubble_text = label_text("",13)
 bubble_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 speech_bubble.add_child(bubble_text)
 hud.add_child(speech_bubble)
 speech_bubble.hide()
 next_day_button = button("오늘 진료 완료 · 다음 날 시작",start_day,true)
 hud.add_child(next_day_button)
 roster = panel(hud)
 var list := VBoxContainer.new()
 list.add_theme_constant_override("separation",10)
 roster.add_child(list)
 var list_heading := HBoxContainer.new()
 list.add_child(list_heading)
 var list_title := label_text("오늘의 환자",23)
 list_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 list_heading.add_child(list_title)
 roster_close = button("닫기",toggle_roster)
 list_heading.add_child(roster_close)
 for id in range(1,5):
  var row := button("",select_patient.bind(id))
  row.name = "Patient%d" % id
  row.alignment = HORIZONTAL_ALIGNMENT_LEFT
  row.clip_text = true
  row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
  row.custom_minimum_size.y = 56
  row.add_theme_font_size_override("font_size",18)
  rows.append(row)
  list.add_child(row)
 roster.hide()
 orientation_hint = label_text("가로로 돌려 플레이해 주세요",32)
 orientation_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 orientation_hint.add_theme_stylebox_override("normal",style(Color("fff5dd")))
 hud.add_child(orientation_hint)
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
 confirmation.canceled.connect(func(): show_notice("증축을 취소했어요"))
 confirmation.hide()
 resized.connect(layout_hud)
 get_window().size_changed.connect(func(): layout_hud.call_deferred())
 layout_hud.call_deferred()

func layout_hud() -> void:
 var w := size.x
 var h := size.y
 # Render the world at display resolution (capped at 720p), independently of
 # the logical HUD scale. Enlarging a 960px SubViewport blurred model details.
 var pixels := Vector2(get_window().size)
 var quality_scale := minf(1.0,minf(1280.0/pixels.x,720.0/pixels.y))
 var render_size := Vector2i(pixels*quality_scale)
 if viewport.size != render_size: viewport.size = render_size
 place(top_bar,Rect2(-4,-6,w+8,70))
 place(brand_portrait,Rect2(14,2,58,58))
 place(title,Rect2(78,12,190,38))
 place(day_label,Rect2(w-355,19,185,30))
 place(money_panel,Rect2(w*.43-75,6,150,50))
 place(pause_button,Rect2(w-137,7,50,50))
 pause_button.custom_minimum_size = Vector2(50,50)
 place(speed_button,Rect2(w-79,9,64,46))
 place(goal_ribbon,Rect2(18,71,415,43))
 place(scene_caption,Rect2(450,77,w-470,24))
 var dock_x := (w-392)*0.5
 place(dock,Rect2(dock_x,h-91,392,88))
 for i in range(tool_buttons.size()):
  place(tool_buttons[i],Rect2(dock_x+22+i*91,h-87,56,56))
  place(tool_labels[i],Rect2(dock_x+6+i*91,h-31,88,24))
 place(outside_button,Rect2(18,h-89,66,66))
 place(outside_label,Rect2(6,h-27,90,22))
 place(zoom_in_button,Rect2(18,h-145,44,44))
 place(zoom_out_button,Rect2(70,h-145,44,44))
 place(selection_panel,Rect2(w-252,77,238,minf(414,h-94)))
 place(next_day_button,Rect2((w-380)*0.5,h-153,380,54))
 place(toast,Rect2((w-370)*.5,h-150,370,50))
 place(roster,Rect2(w-366,96,352,334))
 orientation_hint.visible = w < h
 place(orientation_hint,Rect2(24,142,w-48,70))
 place(confirmation.card,Rect2((w-540)*0.5,(h-310)*0.5,540,310))
 if is_instance_valid(world):
  var right := w-18
  if selection_panel.visible: right = selection_panel.position.x-12
  if roster.visible: right = minf(right,roster.position.x-12)
  var safe := Rect2(126,124,maxf(180,right-126),maxf(120,h-224))
  var scale_to_render := Vector2(viewport.size)/size
  world.set_play_area(Rect2(safe.position*scale_to_render,safe.size*scale_to_render))
  update_bubble()

func show_notice(message: String) -> void:
 if message.is_empty(): return
 notice.text = message
 toast.show()
 notice_timer.start()

func update_bubble() -> void:
 var id: int = selected_id
 var p: Dictionary = sim.get_patient(id)
 if p.is_empty() or not sim.needs_action(p):
  id = sim.next_action_patient(-1)
  p = sim.get_patient(id)
 speech_bubble.hide()
 if p.is_empty() or outside or roster.visible or confirmation.visible or not world.actors.has(id): return
 var actor: Node3D = world.actors[id]
 var anchor: Vector2 = world.camera.unproject_position(actor.head.global_position+Vector3(0,.6,0))*size/Vector2(viewport.size)
 var rect := Rect2(anchor-Vector2(66,38),Vector2(132,36))
 var safe := Rect2(world.play_area.position*size/Vector2(viewport.size),world.play_area.size*size/Vector2(viewport.size))
 if not safe.encloses(rect): return
 bubble_text.text = Feedback.describe(sim,p).bubble
 place(speech_bubble,rect)
 speech_bubble.show()

func toggle_speed() -> void:
 playback_speed = 2.0 if playback_speed == 1.0 else 1.0
 speed_button.text = "x%d" % int(playback_speed)

func refresh_journey(p: Dictionary) -> void:
 var stage := 0
 if p.state in ["walk_ct","ct_queue","ct_scan"]: stage = 1
 elif p.state in ["walk_plan","plan_ready","plan_queue","planning"]: stage = 2
 elif p.state in ["walk_treatment","treatment_queue","treatment"]: stage = 3
 elif p.state in ["leaving","complete"]: stage = 4
 for i in range(4):
  var color := Color("fff1c7") if i == stage else (Color("e0eee0") if i < stage else Color("f3eadb"))
  var box := style(color,Color("e7bf6c") if i == stage else Color.TRANSPARENT,16)
  box.content_margin_top = 2; box.content_margin_bottom = 2
  box.content_margin_left = 8; box.content_margin_right = 8
  stages[i].add_theme_stylebox_override("panel",box)
  stage_labels[i].text = (["접수","CT 촬영","치료 계획","방사선 치료"][i])+ ("  ✓" if i < stage else "")

func toggle_roster() -> void:
 roster.visible = not roster.visible

func clear_selection() -> void:
 selected_id = -1
 world.show_overview()
 refresh()

func scene_input(event: InputEvent) -> void:
 if confirmation.visible: return
 var pixel_scale := Vector2(viewport.size)/scene_container.size
 if event is InputEventMouseButton:
  if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: world.zoom_by(0.88)
  elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: world.zoom_by(1.14)
  elif event.button_index == MOUSE_BUTTON_LEFT:
   if event.pressed:
    drag_start = event.position*pixel_scale
    dragging = false
   else:
    if not dragging and not outside:
     var id := world.pick(event.position*pixel_scale)
     if id > 0: select_patient(id)
    dragging = false
 elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
  if (event.position*pixel_scale).distance_to(drag_start) > 8: dragging = true
  if dragging: world.pan_by(event.relative*pixel_scale)
 elif event is InputEventMagnifyGesture:
  world.zoom_by(1.0/event.factor)

func select_patient(id: int) -> void:
 if sim.get_patient(id).is_empty(): return
 selected_id = id
 roster.hide()
 world.focus_patient(sim.get_patient(id))
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
 if not outside and not sim.get_patient(selected_id).is_empty(): world.focus_patient(sim.get_patient(selected_id))
 refresh()

func open_expansion() -> void:
 var reason: String = sim.expansion_reason()
 if not reason.is_empty(): show_notice(reason); return
 roster.hide()
 confirmation.popup_centered()

func confirm_expansion() -> void:
 if sim.purchase_expansion():
  world.add_wing()
  world.show_overview()
  show_notice("치료별관이 열렸어요. 두 환자를 동시에 치료해요.")
 else: show_notice(sim.expansion_reason())
 refresh()

func start_day() -> void:
 if outside: return
 if sim.start_next_day():
  selected_id = -1
  world.show_overview()
  show_notice("%d일차를 시작해요. 자금과 별관은 유지돼요." % sim.day)
 refresh()

func refresh() -> void:
 stats.text = "%s만" % sim.money
 day_label.text = "%d일차 · 완료 %d/4" % [sim.day,sim.completed()]
 goal.text = ("첫 환자를 따뜻하게 맞이해요" if sim.lifetime_completed == 0 else ("오늘의 환자를 모두 돌봐주세요" if not sim.all_done() else "오늘의 진료를 모두 마쳤어요"))+"   %d/4" % sim.completed()
 pause_button.symbol = "play" if sim.paused else "pause"
 pause_button.queue_redraw()
 pause_button.disabled = outside
 outside_label.text = "병원 안" if outside else "병원 밖"
 scene_caption.text = recording_caption if not recording_caption.is_empty() else ("일시정지" if sim.paused else "")
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
 progress.value = 0
 if not p.is_empty():
  refresh_journey(p)
  patient_portrait.texture = load("res://assets/ui/portrait-patient-%d.png" % selected_id)
  var feedback: Dictionary = Feedback.describe(sim,p)
  detail.text = "%s 님\n%s" % [p.name,feedback.heading]
  reason_label.text = feedback.reason
  action_button.text = feedback.action
  if sim.paused:
   reason_label.text = "일시정지 중이에요.\n재생하면 이어서 진행해요."
   if sim.needs_action(p): action_button.text = "재생 후 지시 가능"
  if Sim.DURATIONS.has(p.state): progress.value = p.elapsed/Sim.DURATIONS[p.state]*100
 selection_panel.visible = not p.is_empty() and not outside and not sim.all_done()
 next_day_button.visible = sim.all_done()
 next_day_button.disabled = outside
 layout_hud()
 if is_instance_valid(world): world.sync(sim,selected_id,0)

func on_change() -> void:
 save_time = 2.0

func _process(delta: float) -> void:
 if not is_instance_valid(world): return
 sim.tick(delta*playback_speed)
 world.sync(sim,selected_id,delta*playback_speed if not sim.paused else 0.0)
 update_bubble()
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
 if not store.save(sim) and not store.message.is_empty(): show_notice(store.message)

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
  persist()
