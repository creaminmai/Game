class_name HospitalCapacityDialog
extends Control
signal confirmed(count: int)
var game: Control
var card: Panel
var heading: Label
var explanation: Label
var greeting: Label
var four: Button
var six: Button
var cancel_button: Button
var start_button: Button
var draft := 4

func build(owner_game: Control) -> void:
 game = owner_game
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter = Control.MOUSE_FILTER_STOP
 var shade := ColorRect.new()
 shade.color = Color(.12,.21,.18,.35)
 shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(shade)
 card = Panel.new(); card.add_theme_stylebox_override("panel",HospitalUiSkin.frame()); add_child(card)
 heading = game.label_text("내일의 예약",28,game.TEAL); card.add_child(heading)
 explanation = game.label_text("모든 일정 완료 시 예상 수입 · 추가 비용 없음",22); card.add_child(explanation)
 four = game.button("",choose.bind(4)); six = game.button("",choose.bind(6))
 for b in [four,six]:
  b.add_theme_font_size_override("font_size",24); card.add_child(b)
 greeting = game.label_text("",23,game.TEAL)
 greeting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; card.add_child(greeting)
 cancel_button = game.button("일지로 돌아가기",hide)
 start_button = game.button("다음 날 시작",commit,true)
 for b in [cancel_button,start_button]:
  b.add_theme_font_size_override("font_size",24); card.add_child(b)
 hide()

func present() -> void:
 if not game.sim.all_done() or not game.sim.expanded: return
 draft = game.sim.schedule.preferred_count
 choose(draft); show(); layout()

func choose(count: int) -> void:
 draft = count
 four.text = ("✓ " if draft == 4 else "")+"여유 있게 운영 · 4명\n예상 진료 수입 800만"
 six.text = ("✓ " if draft == 6 else "")+"예약 확대 · 6명\n예상 진료 수입 1200만"
 for b in [four,six]:
  var selected: bool = (b == four and draft == 4) or (b == six and draft == 6)
  b.add_theme_stylebox_override("normal",game.style(Color("e1eee3") if selected else Color("fffdf5"),game.TEAL if selected else Color("ddcfb7")))
 heading.text = "%d일차 예약을 정해요" % (game.sim.day+1)
 greeting.text = "시작을 누르면 내일 예약이 확정돼요.\n오늘의 일정과 보유 자금은 바뀌지 않아요."
 if draft == 6 and not game.sim.schedule.six_seen and game.story.enabled:
  greeting.text = "민지 · 내일은 여섯 분을 맞이하네요.\n치료실과 대기 순서를 함께 살펴봐요."

func commit() -> void:
 if not visible: return
 hide(); confirmed.emit(draft)

func layout() -> void:
 var touch := maxf(62,ceilf(44*game.size.y/game.ui_display_size.y))
 var dimensions := Vector2(620,350+touch)
 game.place(card,Rect2(game.safe_ui.position+(game.safe_ui.size-dimensions)*.5,dimensions))
 game.place(heading,Rect2(24,16,572,42))
 game.place(explanation,Rect2(24,62,572,32))
 for i in range(2):
  var b: Button = [four,six][i]
  b.custom_minimum_size.y = 86
  game.place(b,Rect2(24+i*292,108,280,100))
 game.place(greeting,Rect2(28,228,564,90))
 for b in [cancel_button,start_button]: b.custom_minimum_size.y = touch
 game.place(cancel_button,Rect2(24,326,280,touch))
 game.place(start_button,Rect2(316,326,280,touch))

func _unhandled_key_input(event: InputEvent) -> void:
 if visible and event.is_action_pressed("ui_cancel"):
  hide(); get_viewport().set_input_as_handled()
