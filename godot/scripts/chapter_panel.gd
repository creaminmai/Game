class_name HospitalChapterPanel
extends Panel
signal closed
var heading: Label
var first: Label
var second: Label
var conditions: Array[Label] = []
var close_button: Button
var history_button: Button
var show_history := false
var current_sim: HospitalSimulation

func build(game: Control) -> void:
 add_theme_stylebox_override("panel",HospitalUiSkin.frame())
 heading = game.label_text("병원 성장 기록",24,game.TEAL); add_child(heading)
 first = game.label_text("",20); add_child(first)
 second = game.label_text("",21,game.TEAL); add_child(second)
 close_button = game.button("닫기",func(): hide(); closed.emit(),true); add_child(close_button)
 history_button = game.button("",func(): show_history = not show_history; refresh(current_sim); layout(game))
 add_child(history_button)
 for n in range(3):
  var label: Label = game.label_text("",20)
  label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  add_child(label); conditions.append(label)
 hide()

func refresh(sim: HospitalSimulation) -> void:
 current_sim = sim
 var c := sim.chapters
 history_button.visible = c.chapter_two_day > 0
 history_button.text = "3장 목표" if show_history else "1·2장 기록"
 first.text = "1장 · 다시 켜진 간판  " + ("✓ 완료" if c.chapter_one_day > 0 else "%d/4 귀가" % sim.count_state("complete"))
 first.tooltip_text = "%d일차 완료" % c.chapter_one_day if c.chapter_one_day > 0 else "첫날 네 분 모두 귀가하면 완료해요"
 second.text = "2장 · 기다리는 의자들" + ("  ✓ 완료" if c.chapter_two_day > 0 else "")
 conditions[0].text = "치료별관 마련  " + ("✓" if sim.expanded else "· 미달성") + "\n" + ("추가 치료실 운영 가능" if sim.expanded else "병원 밖 → 예정지 · 600만")
 conditions[1].text = "두 치료실 함께 운영  " + ("✓" if c.dual_experienced else "· 미달성") + "\n" + ("서로 다른 환자의 동시 치료 기록" if c.dual_experienced else "두 환자의 계획을 맡겨 주세요")
 conditions[2].text = "방문 일정 완료  %d/12%s\n귀가 완료 누적 · 오늘 %d회" % [mini(c.total(),12),"  ✓" if c.total() >= 12 else "",sim.count_state("complete")]

 if c.chapter_two_day > 0 and not show_history:
  var ops := sim.operations
  first.text = "1·2장 완료 ✓"
  second.text = "3장 · 민지의 긴 하루" + (" ✓" if ops.chapter_three_day > 0 else "")
  conditions[0].text = "운영 교육  " + ("✓ 완료\n계획 지시 위임 가능" if ops.trained else "· 미완료\n업무 관리 · 500만")
  conditions[1].text = "위임 방문 일정  %d/4%s\n접수·계획 지시를 모두 맡긴 방문" % [mini(ops.total(),4)," ✓" if ops.total() >= 4 else ""]
  conditions[2].text = "귀가 완료 시 누적 · 날짜 제한 없음\n직접 도와도 진료는 정상 진행해요"

func layout(game: Control) -> void:
 var scale_to_pixels: float = game.ui_display_size.y/game.size.y
 var touch := maxf(44,ceilf(44/scale_to_pixels))
 var font := maxi(20,ceili(14/scale_to_pixels))
 for label in conditions: label.add_theme_font_size_override("font_size",font)
 var row_height := conditions[0].get_line_height()*2+conditions[0].get_theme_constant("line_spacing")+4
 var start := 112.0
 game.place(self,Rect2(18,71,500,start+row_height*3+8))
 game.place(heading,Rect2(18,10,300,36))
 close_button.custom_minimum_size.y = touch
 game.place(close_button,Rect2(342,12,140,touch))
 first.add_theme_font_size_override("font_size",20)
 game.place(first,Rect2(18,45,316,30))
 game.place(second,Rect2(18,79,316 if history_button.visible else 464,32))
 history_button.custom_minimum_size.y = touch
 game.place(history_button,Rect2(342,84,140,touch))
 for i in range(3):
  conditions[i].add_theme_font_size_override("font_size",font)
  game.place(conditions[i],Rect2(18,start+row_height*i,300 if i == 0 and history_button.visible else 464,row_height))
