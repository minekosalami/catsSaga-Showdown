extends Node

# Modal Windows own their input viewport; route their X events to the same
# context-sensitive handler used by Session in the main viewport.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and ((event.alt_pressed and event.keycode==KEY_ENTER) or event.keycode==KEY_F11):
		get_node("/root/GameSettings")._input(event)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("menu_back") and not event.is_echo() and Session.back_outside_battle():
		get_viewport().set_input_as_handled()
