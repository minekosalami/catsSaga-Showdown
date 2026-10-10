extends CanvasLayer

# Per-playthrough state. No inventory or disk save system is introduced.
var area_id: String = "entrance"
var entry_marker: String = "Start"
var return_position: Vector2
var restore_position: bool = false
var evil_bart_defeated: bool = false
var encounter_active: bool = false
var busy: bool = false
var curtain: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	curtain = ColorRect.new()
	curtain.color = Color.BLACK
	add_child(curtain)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.hide()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()

func toggle_fullscreen() -> void:
	var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)

func new_game() -> void:
	if busy:
		return
	area_id = "entrance"
	entry_marker = "Start"
	restore_position = false
	evil_bart_defeated = false
	encounter_active = false
	await transition_to("res://scenes/world/overworld.tscn")

func travel(destination: String, marker: String) -> void:
	if busy:
		return
	area_id = destination
	entry_marker = marker
	restore_position = false
	await transition_to("res://scenes/world/overworld.tscn")

func begin_battle(position_before_battle: Vector2) -> void:
	if busy or evil_bart_defeated:
		return
	return_position = position_before_battle
	encounter_active = true
	await transition_to("res://scenes/combat_host.tscn")

func return_to_forest() -> void:
	if busy or not evil_bart_defeated:
		return
	restore_position = true
	encounter_active = false
	await transition_to("res://scenes/world/overworld.tscn")

func main_menu() -> void:
	if busy:
		return
	encounter_active = false
	await transition_to("res://scenes/main_menu.tscn")

func transition_to(scene_path: String) -> bool:
	if busy:
		return false
	busy = true
	get_tree().paused = false
	curtain.show()
	curtain.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(curtain, "modulate:a", 1.0, 0.18)
	await fade.finished
	# Stop old streams before the next scene can start its soundtrack.
	for audio in get_tree().get_nodes_in_group("combat_music"):
		audio.stop()
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Transition could not load " + scene_path)
	else:
		await get_tree().scene_changed
	fade = create_tween()
	fade.tween_property(curtain, "modulate:a", 0.0, 0.18)
	await fade.finished
	curtain.hide()
	busy = false
	return error == OK
