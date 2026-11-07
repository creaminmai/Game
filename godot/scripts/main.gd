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
var story := FirstDayStory.new()
var world: HospitalWorld
var selected_id := -1
var outside := false
var user_paused := false
var pause_holds: Dictionary = {}
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
var patient_view_button: Button
var story_panel: Panel
var story_portrait: TextureRect
var story_heading: Label
var story_text: Label
var story_summary: Label
var story_next: Button
var story_skip: Button
var story_off: Button
var story_highlight: Panel
var guide_settings: Button
var guide_panel: Panel
var guide_close: Button
var guide_description: Label
var journal: HospitalDayJournal
var journal_seen_day := -1
var annex_highlight_pending := false
var facility_callout: PanelContainer
var facility_label: Label
var safe_insets_test := Vector4.ZERO
var safe_ui := Rect2()
var web_visibility_callback: JavaScriptObject
var patient_list_link: Button
var journey_grid: GridContainer
var web_inspect := false
var ui_display_size := Vector2(1280,720)
var admission_toggle: Button
var admission_offer: Panel
var admission_offer_text: Label
var admission_accept: Button
var admission_decline: Button
var admission_skip: Button
var admission_offer_open := false

func _ready() -> void:
 no_save = "--no-save" in OS.get_cmdline_user_args() or "--qa" in OS.get_cmdline_user_args()
 if not no_save: store.load_into(sim,story)
 if store.blocked or ("--qa" in OS.get_cmdline_user_args() and not "--tutorial" in OS.get_cmdline_user_args()): story.disable()
 user_paused = sim.paused
 if OS.has_feature("web"):
  web_inspect = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('playtest')"))
  web_visibility_callback = JavaScriptBridge.create_callback(_web_visibility)
  var browser := JavaScriptBridge.get_interface("window")
  if browser != null: browser.sunshineBindVisibility(web_visibility_callback)
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
 sim.admitted.connect(func(id: int): world.reception_response(sim.get_patient(id).position))
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
 hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
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
 # Text wrapping settles after container sorting; shrink the first opened card
 # immediately when its minimum height changes, rather than waiting for a tick.
 selection_panel.minimum_size_changed.connect(func(): layout_hud.call_deferred())
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
 var journey := GridContainer.new()
 journey.columns = 1
 journey_grid = journey
 journey.add_theme_constant_override("v_separation",4)
 journey.add_theme_constant_override("h_separation",4)
 content.add_child(journey)
 for i in range(4):
  var stage := PanelContainer.new()
  stage.custom_minimum_size.y = 28
  stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
 var links := HBoxContainer.new()
 content.add_child(links)
 patient_view_button = button("환자 보기",func(): world.focus_patient(sim.get_patient(selected_id)))
 patient_view_button.tooltip_text = "선택 환자 주변을 자세히 보기 · 병원 버튼으로 기본 시점 복귀"
 patient_view_button.custom_minimum_size.y = 32
 patient_view_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 patient_view_button.add_theme_font_size_override("font_size",13)
 links.add_child(patient_view_button)
 var patient_link := button("환자 목록",toggle_roster)
 patient_list_link = patient_link
 patient_link.custom_minimum_size.y = 32
 patient_link.add_theme_font_size_override("font_size",13)
 patient_link.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 links.add_child(patient_link)
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
 next_day_button = button("오늘의 병원 일지",open_journal,true)
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
 shade.color = Color(0.07,0.15,0.12,0.35)
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
 var message := label_text("치료실 1개 추가
최대 두 환자를 동시에 치료할 수 있어요",21)
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
 confirmation.canceled.connect(func(): world.preview_expansion(false); show_notice("증축을 취소했어요"); refresh())
 confirmation.hide()
 build_story_ui()
 facility_callout = panel(hud)
 facility_callout.mouse_filter = Control.MOUSE_FILTER_IGNORE
 facility_callout.z_index = 20
 facility_label = label_text("",20,TEAL)
 facility_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 facility_callout.add_child(facility_label)
 facility_callout.hide()
 journal = HospitalDayJournal.new()
 add_child(journal)
 journal.build(self)
 journal.next_requested.connect(start_day)
 journal.closed.connect(refresh)
 resized.connect(layout_hud)
 get_window().size_changed.connect(func(): layout_hud.call_deferred())
 layout_hud.call_deferred()

func build_story_ui() -> void:
 story_panel = Panel.new()
 story_panel.add_theme_stylebox_override("panel",UISkin.frame())
 hud.add_child(story_panel)
 story_portrait = UISkin.picture("res://assets/ui/portrait-minji.png",44)
 story_panel.add_child(story_portrait)
 story_heading = label_text("",19,TEAL)
 story_panel.add_child(story_heading)
 story_text = label_text("",18)
 story_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 story_panel.add_child(story_text)
 story_summary = label_text("",13,TEAL) # Legacy test/tool handle; the journal owns the daily figures.
 story_panel.add_child(story_summary)
 story_summary.hide()
 story_next = button("다음",advance_story,true)
 story_skip = button("이번 대화 건너뛰기",skip_story)
 for b in [story_next,story_skip]: story_panel.add_child(b)
 for state in ["normal","hover","pressed"]:
  story_skip.add_theme_stylebox_override(state,style(Color.TRANSPARENT,Color("c9baa1") if state != "normal" else Color.TRANSPARENT,10))
 guide_settings = button("안내 설정",toggle_guide_settings)
 hud.add_child(guide_settings)
 guide_panel = Panel.new()
 guide_panel.add_theme_stylebox_override("panel",UISkin.frame())
 hud.add_child(guide_panel)
 var settings_title := label_text("운영 설정",24,TEAL)
 guide_panel.add_child(settings_title)
 place(settings_title,Rect2(18,18,260,40))
 guide_description = label_text("첫날 안내 설정\n켜면 현재 할 일부터 안내해요.\n이미 지난 이야기는 반복하지 않아요.",21)
 guide_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 guide_panel.add_child(guide_description)
 story_off = button("안내 끄기",toggle_guidance)
 guide_close = button("게임으로",toggle_guide_settings,true)
 for b in [story_off,guide_close]: guide_panel.add_child(b)
 admission_toggle = button("",toggle_admission)
 guide_panel.add_child(admission_toggle)
 guide_panel.hide()
 admission_offer = Panel.new()
 admission_offer.add_theme_stylebox_override("panel",UISkin.frame())
 hud.add_child(admission_offer)
 var portrait := UISkin.picture("res://assets/ui/portrait-minji.png",44)
 admission_offer.add_child(portrait)
 place(portrait,Rect2(14,12,44,44))
 var heading := label_text("민지 · 접수 위임",24,TEAL)
 admission_offer.add_child(heading)
 place(heading,Rect2(70,16,350,36))
 admission_offer_text = label_text("접수는 제가 맡아볼까요?\n치료 계획은 직접 맡겨 주세요.",22)
 admission_offer_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 admission_offer.add_child(admission_offer_text)
 admission_accept = button("접수 맡기기",answer_admission_offer.bind(true),true)
 admission_decline = button("직접 할게요",answer_admission_offer.bind(false))
 admission_skip = button("이번 제안 건너뛰기",answer_admission_offer.bind(false))
 for b in [admission_accept,admission_decline,admission_skip]: admission_offer.add_child(b)
 admission_offer.hide()
 story_highlight = Panel.new()
 var outline := style(Color.TRANSPARENT,Color("4cbaa5"),18)
 outline.set_border_width_all(3)
 story_highlight.add_theme_stylebox_override("panel",outline)
 story_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
 story_highlight.z_index = 10
 hud.add_child(story_highlight)
 story_panel.hide()
 story_highlight.hide()

func advance_story() -> void:
 story.next_line(sim)
 refresh()
 persist()

func skip_story() -> void:
 story.finish_dialogue()
 refresh()
 persist()

func disable_story() -> void:
 story.disable()
 refresh()
 persist()

func toggle_guide_settings() -> void:
 guide_panel.visible = not guide_panel.visible
 refresh()

func toggle_guidance() -> void:
 if story.enabled: story.disable()
 else: story.enable_current(sim,selected_id)
 refresh()
 persist()

func answer_admission_offer(accepted: bool) -> void:
 sim.set_admission_delegated(accepted)
 admission_offer_open = false
 refresh()
 persist()

func toggle_admission() -> void:
 if sim.set_admission_delegated(not sim.admission.enabled):
  admission_offer_open = false
  refresh()
  persist()

func refresh_admission() -> void:
 if not story.enabled: admission_offer_open = false
 if sim.day >= 2 and not sim.admission.offer_seen and story.enabled and not outside and pause_holds.is_empty() and not guide_panel.visible and not journal.visible and not confirmation.visible and not roster.visible:
  admission_offer_open = true
  sim.admission.offer_seen = true
  persist()
 admission_offer.visible = admission_offer_open and not outside and not guide_panel.visible and not journal.visible and not confirmation.visible and not roster.visible
 guide_settings.text = "안내 설정" if sim.day == 1 else ("설정 · 접수\n민지에게 맡김" if sim.admission.enabled else "설정 · 접수\n직접")
 admission_toggle.disabled = sim.day < 2
 admission_toggle.text = "접수 위임 · 2일차부터 가능" if sim.day < 2 else ("접수: 민지에게 맡김 → 직접 하기" if sim.admission.enabled else "접수: 직접 → 민지에게 맡기기")
 guide_description.text = "접수 위임은 무료예요.\n치료 계획은 직접 맡겨 주세요."
 story_off.text = "첫날 안내: 켜짐 → 끄기" if story.enabled else "첫날 안내: 꺼짐 → 다시 켜기"
 zoom_in_button.visible = not guide_panel.visible and not admission_offer.visible
 zoom_out_button.visible = zoom_in_button.visible
 if admission_offer.visible: goal_ribbon.hide()

func open_journal() -> void:
 if outside or not sim.all_done(): return
 journal_seen_day = sim.day
 if story.active == "day_end": story.finish_dialogue()
 guide_panel.hide()
 journal.present(sim)
 refresh()
 persist()

func refresh_story() -> void:
 story.sync(sim,selected_id,not outside and pause_holds.is_empty() and not confirmation.visible and not guide_panel.visible)
 if sim.all_done() and not outside and not confirmation.visible and journal_seen_day != sim.day:
  # Never interrupt an earlier line the player is still reading. No timed wait.
  if story.active in ["","day_end"] or not story.enabled:
   journal_seen_day = sim.day
   if story.active == "day_end": story.finish_dialogue()
   guide_panel.hide()
   journal.present(sim)
 story_panel.visible = story.enabled and story.active != "" and not outside and not roster.visible and not confirmation.visible and not guide_panel.visible and not journal.visible and sim.day == 1
 guide_settings.visible = not confirmation.visible and not journal.visible
 story_off.text = "안내 끄기" if story.enabled else "안내 다시 켜기"
 if story_panel.visible:
  var lines: Array = story.lines(sim)
  var speech: Array = lines[mini(story.line,lines.size()-1)]
  story_heading.text = "%s  ·  %d/%d" % [speech[0],mini(story.line+1,lines.size()),lines.size()]
  story_text.text = speech[1]
  story_portrait.texture = load("res://assets/ui/portrait-patient-1.png" if speech[0] == "김영수" else "res://assets/ui/portrait-minji.png")
  story_next.text = "다음"
  story_next.tooltip_text = "다음 대사" if story.line < lines.size()-1 else "이야기를 마치고 직접 해보기"
 var hint := story.hint(sim,selected_id,outside)
 if not hint.is_empty(): goal.text = hint
 goal_ribbon.visible = not story_panel.visible and not guide_panel.visible
 if story.enabled and sim.day == 1 and selected_id == 1 and not sim.paused and sim.needs_action(sim.get_patient(1)):
  reason_label.text = "다음 행동 ↓ 접수하기" if sim.get_patient(1).state == "waiting" else "다음 행동 ↓ 계획 맡기기\n의학적 판단은 의료진이 맡아요."

func layout_story() -> void:
 if not is_instance_valid(story_panel): return
 var scale_to_pixels := ui_display_size.y/size.y
 var touch := maxf(44,ceilf(44/scale_to_pixels))
 var body_font := maxi(18,ceili(16/scale_to_pixels))
 var name_font := maxi(19,ceili(17/scale_to_pixels))
 var w := 348.0 if scale_to_pixels < 1.0 else 324.0
 var body_height := body_font*4.15
 var footer := 66+body_height
 place(story_panel,Rect2(18,71,w,footer+touch+14))
 story_heading.add_theme_font_size_override("font_size",name_font)
 story_text.add_theme_font_size_override("font_size",body_font)
 story_next.add_theme_font_size_override("font_size",maxi(18,ceili(15/scale_to_pixels)))
 story_skip.add_theme_font_size_override("font_size",maxi(13,ceili(12/scale_to_pixels)))
 place(story_portrait,Rect2(14,12,44,44))
 place(story_heading,Rect2(70,16,w-84,36))
 place(story_text,Rect2(14,62,w-28,body_height))
 for b in [story_next,story_skip,guide_settings,story_off,guide_close,action_button,next_day_button,confirmation.ok_button,confirmation.cancel_button]: b.custom_minimum_size.y = touch
 place(story_next,Rect2(w-106,footer,92,touch))
 place(story_skip,Rect2(8,footer,w-126,touch))
 # Share the bottom utility row with the outside control, never the dialogue column.
 place(guide_settings,Rect2(98,hud.size.y-31-touch,180,touch))
 guide_settings.add_theme_font_size_override("font_size",maxi(16,ceili(13/scale_to_pixels)))
 var settings_height := 128+touch*3
 place(guide_panel,Rect2(18,71,470,settings_height))
 place(guide_close,Rect2(312,12,140,touch))
 place(story_off,Rect2(18,26+touch,434,touch))
 admission_toggle.custom_minimum_size.y = touch
 place(admission_toggle,Rect2(18,38+touch*2,434,touch))
 guide_description.add_theme_font_size_override("font_size",maxi(18,ceili(14/scale_to_pixels)))
 place(guide_description,Rect2(18,50+touch*3,434,72))
 var offer_font := maxi(20,ceili(16/scale_to_pixels))
 var offer_body := offer_font*3.6
 var offer_footer := 62+offer_body
 place(admission_offer,Rect2(18,71,470,offer_footer+touch*2+24))
 admission_offer_text.add_theme_font_size_override("font_size",offer_font)
 place(admission_offer_text,Rect2(14,62,442,offer_body))
 for b in [admission_accept,admission_decline,admission_skip]:
  b.custom_minimum_size.y = touch
  b.add_theme_font_size_override("font_size",maxi(18,ceili(15/scale_to_pixels)))
 place(admission_accept,Rect2(14,offer_footer,215,touch))
 place(admission_decline,Rect2(241,offer_footer,215,touch))
 place(admission_skip,Rect2(14,offer_footer+touch+8,442,touch))
 story_highlight.hide()
 if not story.enabled or story_panel.visible or guide_panel.visible or journal.visible or outside or sim.day != 1 or confirmation.visible: return
 var p: Dictionary = sim.get_patient(1)
 if p.is_empty(): return
 var target: Control = null
 if p.state in ["entering","waiting","plan_ready"]:
  target = (rows[0] if roster.visible else patient_button) if selected_id != 1 else (action_button if sim.needs_action(p) else null)
 elif sim.all_done(): target = next_day_button
 if target != null and target.is_visible_in_tree() and not target.disabled:
  place(story_highlight,Rect2(target.get_global_rect().position-hud.position,target.size).grow(3))
  story_highlight.show()

func layout_hud() -> void:
 ui_display_size = HospitalMobileScreen.display_points(self)
 safe_ui = HospitalMobileScreen.safe_rect(self,safe_insets_test)
 place(hud,safe_ui)
 var w := safe_ui.size.x
 var h := safe_ui.size.y
 var touch := maxf(44,ceilf(44*size.y/ui_display_size.y))
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
 place(pause_button,Rect2(w-23-maxf(64,touch)-maxf(50,touch),1,maxf(50,touch),maxf(50,touch)))
 pause_button.custom_minimum_size = Vector2(maxf(50,touch),maxf(50,touch))
 speed_button.custom_minimum_size = Vector2(touch,touch)
 place(speed_button,Rect2(w-13-maxf(64,touch),1,maxf(64,touch),maxf(46,touch)))
 place(goal_ribbon,Rect2(18,71,415,43))
 place(scene_caption,Rect2(450,77,w-470,24))
 if story.enabled and sim.day == 1: place(scene_caption,Rect2(552,77,w-570,24))
 if not recording_caption.is_empty():
  place(scene_caption,Rect2(w-258,h-34,248,30))
  var caption_style := style(Color(.99,.97,.9,.94),Color.TRANSPARENT,8)
  caption_style.content_margin_top = 4; caption_style.content_margin_bottom = 4
  scene_caption.add_theme_stylebox_override("normal",caption_style)
 var dock_x := (w-392)*0.5
 place(dock,Rect2(dock_x,h-91,392,88))
 for i in range(tool_buttons.size()):
  tool_buttons[i].custom_minimum_size = Vector2.ONE*maxf(56,touch)
  place(tool_buttons[i],Rect2(dock_x+22+i*91,h-31-maxf(56,touch),maxf(56,touch),maxf(56,touch)))
  place(tool_labels[i],Rect2(dock_x+6+i*91,h-31,88,24))
 outside_button.custom_minimum_size = Vector2.ONE*maxf(66,touch)
 place(outside_button,Rect2(18,h-31-maxf(66,touch),maxf(66,touch),maxf(66,touch)))
 place(outside_label,Rect2(6,h-27,90,22))
 for b in [zoom_in_button,zoom_out_button,dismiss_button,roster_close,patient_view_button,patient_list_link]:
  b.custom_minimum_size = Vector2(touch,touch)
 for row in rows: row.custom_minimum_size.y = maxf(56,touch)
 place(zoom_in_button,Rect2(18,h-101-touch,touch,touch))
 place(zoom_out_button,Rect2(26+touch,h-101-touch,touch,touch))
 var compact := ui_display_size.y/size.y < 1.0
 journey_grid.columns = 4 if compact else 1
 for caption in stage_labels: caption.visible = not compact
 detail.add_theme_font_size_override("font_size",22 if compact else 16)
 reason_label.add_theme_font_size_override("font_size",22 if compact else 13)
 reason_label.custom_minimum_size.y = 48 if compact else 60
 action_button.add_theme_font_size_override("font_size",22 if compact else 16)
 var card_width := 280.0 if compact else 238.0
 place(selection_panel,Rect2(w-card_width-14,77,card_width,h-94))
 place(next_day_button,Rect2((w-380)*0.5,h-153,380,54))
 notice.add_theme_font_size_override("font_size",maxi(16,ceili(16*size.y/ui_display_size.y)))
 toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
 place(toast,Rect2((w-420)*.5,h-187,420,88))
 place(roster,Rect2(w-366,76,352,h-90))
 orientation_hint.visible = w < h
 place(orientation_hint,Rect2(24,142,w-48,70))
 place(confirmation.card,Rect2(safe_ui.position+Vector2(30 if outside else (w-540)*.5,(h-310)*.5),Vector2(540,310)))
 layout_story()
 if is_instance_valid(journal): journal.layout(self)
 if is_instance_valid(world):
  var right := w-18
  if selection_panel.visible: right = selection_panel.position.x-12
  if roster.visible: right = minf(right,roster.position.x-12)
  var safe := Rect2(24,124,maxf(180,right-24),maxf(120,h-224))
  # The hospital floor may extend behind the dock; important patient anchors
  # use the tighter safe area. A card never participates in fitting the model.
  var operating := Rect2(24,76,w-48,h-108)
  var scale_to_render := Vector2(viewport.size)/size
  world.set_play_area(Rect2((safe.position+safe_ui.position)*scale_to_render,safe.size*scale_to_render),Rect2((operating.position+safe_ui.position)*scale_to_render,operating.size*scale_to_render))
  update_bubble()
  update_facility_callout()
 if web_inspect: publish_web_layout()

func update_facility_callout() -> void:
 facility_callout.hide()
 if journal.visible: return
 var at := Vector3(7,.6,1)
 if outside:
  if sim.expanded and world.celebration_elapsed < 0: return
  facility_label.text = "치료별관 · 운영 시작 ✓" if sim.expanded else ("이곳에 별관이 생겨요" if confirmation.visible else "치료별관 예정지 · 눌러보기")
 else:
  if not world.inside_marker.visible: return
  at = Vector3(10,3,1)
  facility_label.text = "새 치료실 · 운영 중 ✓"
 var point: Vector2 = world.camera.unproject_position(at)*size/Vector2(viewport.size)-hud.position
 var right := selection_panel.position.x-12 if selection_panel.visible and not outside else hud.size.x-18
 facility_label.add_theme_font_size_override("font_size",maxi(18,ceili(16*size.y/ui_display_size.y)))
 var width := 300.0
 var left := clampf(point.x-width*.5,18,right-width)
 if outside and confirmation.visible: left = maxf(left,confirmation.card.get_rect().end.x-hud.position.x+12)
 place(facility_callout,Rect2(left,clampf(point.y-76,122,hud.size.y-210),width,52))
 facility_callout.show()

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
 if story_panel.visible: return
 if p.is_empty() or outside or roster.visible or confirmation.visible or not world.actors.has(id): return
 var actor: Node3D = world.actors[id]
 var anchor: Vector2 = world.camera.unproject_position(actor.head.global_position+Vector3(0,.6,0))*size/Vector2(viewport.size)-hud.position
 var rect := Rect2(anchor-Vector2(66,38),Vector2(132,36))
 var safe := Rect2(world.play_area.position*size/Vector2(viewport.size)-hud.position,world.play_area.size*size/Vector2(viewport.size))
 if not safe.encloses(rect): return
 bubble_text.text = Feedback.describe(sim,p).bubble
 if story.enabled and sim.day == 1 and id == 1 and p.state in ["waiting","plan_ready"] and selected_id != 1:
  bubble_text.text = "저를 선택해 주세요"
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
 refresh()

func scene_input(event: InputEvent) -> void:
 if confirmation.visible or journal.visible: return
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
    elif not dragging and outside and world.pick_expansion_site(event.position*pixel_scale):
     open_expansion()
    dragging = false
 elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
  if (event.position*pixel_scale).distance_to(drag_start) > 8: dragging = true
  if dragging: world.pan_by(event.relative*pixel_scale)
 elif event is InputEventMagnifyGesture:
  world.zoom_by(1.0/event.factor)

func select_patient(id: int) -> void:
 if sim.get_patient(id).is_empty(): return
 selected_id = id
 if id == 1: story.acknowledge_action("select")
 roster.hide()
 world.select_patient(sim.get_patient(id))
 refresh()

func select_next_action() -> void:
 var id: int = sim.next_action_patient(selected_id)
 if id > 0: select_patient(id)

func perform_action() -> void:
 if outside: return
 var p: Dictionary = sim.get_patient(selected_id)
 if p.is_empty(): return
 if p.state == "waiting":
  if sim.admit(selected_id):
   if selected_id == 1: story.acknowledge_action("admit")
 elif p.state == "plan_ready":
  if sim.assign_plan(selected_id) and selected_id == 1: story.acknowledge_action("plan")
 refresh()

func toggle_pause() -> void:
 if outside: return
 user_paused = not (sim.paused if pause_holds.is_empty() else user_paused)
 sim.paused = user_paused or not pause_holds.is_empty()
 refresh()

func set_pause_hold(reason: String, held: bool) -> void:
 # Temporary holds never overwrite the player's pause intent, even when nested.
 if pause_holds.is_empty(): user_paused = sim.paused
 if held: pause_holds[reason] = true
 else: pause_holds.erase(reason)
 sim.paused = user_paused or not pause_holds.is_empty()

func toggle_outside() -> void:
 if not outside:
  roster.hide()
  set_pause_hold("outside",true)
  outside = true
 else:
  outside = false
  set_pause_hold("outside",false)
 world.show_outside(outside)
 guide_panel.hide()
 if not outside and annex_highlight_pending:
  world.highlight_annex_inside()
  annex_highlight_pending = false
 refresh()

func open_expansion() -> void:
 var reason: String = sim.expansion_reason()
 if not reason.is_empty(): show_notice(reason); return
 roster.hide()
 guide_panel.hide()
 world.preview_expansion(true)
 confirmation.popup_centered()
 refresh()

func confirm_expansion() -> void:
 if sim.purchase_expansion():
  world.add_wing(false)
  world.celebrate_expansion()
  annex_highlight_pending = outside
  if not outside: world.highlight_annex_inside()
  show_notice("치료실이 하나 늘었어요!\n민지 · 두 분을 함께 도울 수 있겠어요.")
  persist()
 else: show_notice(sim.expansion_reason())
 refresh()

func start_day() -> void:
 if outside or not sim.all_done(): return
 if sim.start_next_day():
  journal.hide()
  selected_id = -1
  world.show_overview()
  show_notice("%d일차를 시작해요. 자금과 별관은 유지돼요." % sim.day)
  persist()
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
  var need: bool = not p.is_empty() and sim.needs_player_action(p)
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
 refresh_story()
 refresh_admission()
 layout_hud()
 if is_instance_valid(world): world.sync(sim,selected_id,0)

func on_change() -> void:
 save_time = 2.0

func _process(delta: float) -> void:
 if not is_instance_valid(world): return
 sim.tick(delta*playback_speed)
 world.sync(sim,selected_id,delta*playback_speed if not sim.paused else 0.0)
 update_facility_callout()
 update_bubble()
 story_highlight.modulate.a = .78+.14*sin(Time.get_ticks_msec()/650.0)
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
 if not store.save(sim,story) and not store.message.is_empty(): show_notice(store.message)

func _notification(what: int) -> void:
 if not is_instance_valid(world): return
 if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
  set_pause_hold("application_focus" if what == NOTIFICATION_APPLICATION_FOCUS_OUT else "application_background",true)
  persist()
 elif what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]:
  set_pause_hold("application_focus" if what == NOTIFICATION_APPLICATION_FOCUS_IN else "application_background",false)
 if what == NOTIFICATION_WM_CLOSE_REQUEST:
  persist()

func _web_visibility(arguments: Array) -> void:
 # Safari may suspend requestAnimationFrame without a native focus notification.
 # Visibility is an independent hold and never cancels a user/outside pause.
 if arguments.is_empty(): return
 set_pause_hold("web_hidden",bool(arguments[0]))
 persist()

func publish_web_layout() -> void:
 # Opt-in, read-only QA coordinates. No remote actions or save mutation API.
 var controls := {"patients":patient_button,"first_patient":rows[0],"action":action_button,"pause":pause_button,"zoom_in":zoom_in_button,"zoom_out":zoom_out_button,"settings":guide_settings,"guide_close":guide_close,"story_next":story_next,"story_skip":story_skip,"admission_accept":admission_accept,"admission_decline":admission_decline,"admission_skip":admission_skip,"admission_toggle":admission_toggle}
 var result := {}
 var pixels := ui_display_size/size
 for key in controls:
  var c: Control = controls[key]
  var r := c.get_global_rect()
  result[key] = {"x":r.get_center().x*pixels.x,"y":r.get_center().y*pixels.y,"width":r.size.x*pixels.x,"height":r.size.y*pixels.y,"visible":c.is_visible_in_tree()}
 result["_state"] = {"paused":sim.paused,"time":sim.time,"money":sim.money,"day":sim.day}
 JavaScriptBridge.eval("window.sunshineControls="+JSON.stringify(result))
