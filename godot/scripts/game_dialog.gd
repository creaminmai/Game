class_name HospitalGameDialog
extends Control
signal confirmed
signal canceled
var ok_button: Button
var cancel_button: Button
var card: PanelContainer

func popup_centered() -> void:
 show()
 ok_button.grab_focus()

func get_ok_button() -> Button:
 return ok_button

func get_cancel_button() -> Button:
 return cancel_button

func accept() -> void:
 hide()
 confirmed.emit()

func cancel() -> void:
 hide()
 canceled.emit()

func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.pressed:
  if not card.get_global_rect().has_point(get_global_mouse_position()): cancel()

func _unhandled_key_input(event: InputEvent) -> void:
 if visible and event.is_action_pressed("ui_cancel"):
  cancel()
  get_viewport().set_input_as_handled()
