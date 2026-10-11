extends Node

# Modal Windows own their input viewport; route their X events to the same
# context-sensitive handler used by Session in the main viewport.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_back") and not event.is_echo() and Session.back_outside_battle():
		get_viewport().set_input_as_handled()
