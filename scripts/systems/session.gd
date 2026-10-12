extends CanvasLayer

signal transition_finished

# Progression remains in one Session; save storage is a reusable helper.
var area_id: String = "entrance"
var entry_marker: String = "Start"
var return_position: Vector2
var restore_position: bool = false
var evil_bart_defeated: bool = false
var encounter_active: bool = false
var encounter_id := "bart"
var key_notification_pending := false
var busy: bool = false
var battle_entry_pending: bool = false
@export var battle_wipe_duration: float = 1.2
@export var battle_reveal_duration: float = 0.3
@export_range(0.3, 0.5) var transition_duration: float = 0.36
@export var region_fade_duration: float = 0.3
var story_flags: Dictionary = {}
var exploration := preload("res://scripts/maps/exploration.gd").new()
var map_reveal_cheat := false
var unrestricted_region_access := false # Debug only; deliberately absent from saves.
var show_coordinates := false # Session-only visualization; never saved.
var reveal_all_locations := false
var coordinate_overlay: Label
var saves := preload("res://scripts/systems/save_manager.gd").new()
var pause_menu: CanvasLayer
var developer_menu: CanvasLayer
var developer_cheats := preload("res://scripts/systems/developer_cheats.gd").new()
var options_dialog: AcceptDialog
var confirmation: ConfirmationDialog
var suspended_modes: Dictionary = {}
var last_save_message: String = ""
var curtain: ColorRect
var battle_walls: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	curtain = ColorRect.new()
	curtain.color = Color.BLACK
	add_child(curtain)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.hide()
	battle_walls = Control.new()
	battle_walls.name = "BattleWalls"
	battle_walls.set_script(preload("res://scripts/ui/black_wall_entry.gd"))
	add_child(battle_walls)
	pause_menu = CanvasLayer.new()
	pause_menu.set_script(preload("res://scripts/ui/pause_menu.gd"))
	add_child(pause_menu)
	developer_menu = preload("res://scripts/ui/developer_menu.gd").new()
	developer_menu.name = "DeveloperMenu"
	add_child(developer_menu)
	coordinate_overlay = preload("res://scripts/ui/coordinate_overlay.gd").new()
	coordinate_overlay.name = "CoordinateOverlay"
	add_child(coordinate_overlay)

func _input(event: InputEvent) -> void:
	if developer_menu.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if developer_menu.opened: return
	if event.is_action_pressed("menu_back") and not event.is_echo() and back_outside_battle():
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if pause_menu.opened:
			if not is_instance_valid(confirmation) and not (is_instance_valid(options_dialog) and options_dialog.visible):
				close_pause()
				get_viewport().set_input_as_handled()
		elif can_pause():
			open_pause()
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()

func back_outside_battle() -> bool:
	var scene := get_tree().current_scene
	# X belongs exclusively to SATURATE in combat, including combat pause.
	if busy or scene == null or scene.has_method("record_victory"):
		return false
	if is_instance_valid(confirmation) and confirmation.visible:
		confirmation.hide()
		confirmation.canceled.emit()
		return true
	if is_instance_valid(options_dialog) and options_dialog.visible:
		options_dialog.hide()
		if pause_menu.opened:
			pause_menu.buttons.Options.grab_focus()
		elif scene.name == "Mainmenu":
			scene.menu_container.get_node("OptionsButton").grab_focus()
		return true
	if pause_menu.opened:
		close_pause()
		return true
	if scene.name == "Mainmenu" and scene.info_container.visible:
		scene._back_to_menu()
		return true
	# Branching dialogue has no safe history/back operation; never skip it.
	return false

func _attach_menu_back(window: Window) -> void:
	var input_handler := Node.new()
	input_handler.set_script(preload("res://scripts/ui/menu_back_input.gd"))
	window.add_child(input_handler)

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
	story_flags.clear()
	exploration.reset()
	map_reveal_cheat = false
	key_notification_pending = false
	encounter_active = false
	if await transition_to("res://scenes/world/overworld.tscn"):
		save_current()

func travel(destination: String, marker: String, cave_motion: bool = false) -> void:
	if busy:
		return
	area_id = destination
	entry_marker = marker
	restore_position = false
	if await transition_to("res://scenes/world/overworld.tscn", false, true, cave_motion):
		if destination == "underground_cave":
			story_flags["underground_cave_discovered"] = true
		save_current()

func region_access_allowed(normal_access: bool) -> bool:
	return unrestricted_region_access or normal_access

func begin_battle(position_before_battle: Vector2) -> void:
	if busy or evil_bart_defeated:
		return
	return_position = position_before_battle
	encounter_id = "bart"
	encounter_active = true
	await transition_to("res://scenes/combat_host.tscn", true)

func grant_flooded_key() -> void:
	if not evil_bart_defeated:
		return
	story_flags["bart_defeated"] = true
	if not story_flags.get("flooded_forest_key_obtained", false):
		story_flags["flooded_forest_key_obtained"] = true
		key_notification_pending = true
		call_deferred("_show_key_notification")

func begin_boss2_battle(position_before_battle: Vector2) -> void:
	if busy or area_id != "flooded_forest" or not story_flags.get("flooded_forest_key_obtained", false) or story_flags.get("boss2_defeated", false):
		return
	return_position = position_before_battle
	encounter_id = "boss2"
	encounter_active = true
	await transition_to("res://scenes/boss2/combat_host.tscn", true)

## Future encounters use this entry point without duplicating the curtain.
func begin_encounter(identifier: String, host_path: String, before: Vector2, completed_flag: String) -> void:
	if busy or story_flags.get(completed_flag, false):
		return
	return_position = before
	encounter_id = identifier
	encounter_active = true
	if not await transition_to(host_path, true):
		encounter_active = false

func begin_blankkitten_battle(before: Vector2) -> void:
	await begin_encounter("blankkitten", "res://scenes/blankkitten/combat_host.tscn", before, "blankkitten_defeated")

func return_from_blankkitten() -> void:
	if busy or not story_flags.get("blankkitten_defeated", false):
		return
	restore_position = true
	encounter_active = false
	if await transition_to("res://scenes/world/overworld.tscn"):
		save_current()

func return_to_flooded_forest() -> void:
	if busy or not story_flags.get("boss2_defeated", false):
		return
	area_id = "flooded_forest"
	restore_position = true
	encounter_active = false
	if await transition_to("res://scenes/world/overworld.tscn"):
		save_current()

func return_to_forest() -> void:
	if busy or not evil_bart_defeated:
		return
	restore_position = true
	encounter_active = false
	if await transition_to("res://scenes/world/overworld.tscn"):
		save_current()

func main_menu() -> void:
	if busy:
		return
	encounter_active = false
	await transition_to("res://scenes/main_menu.tscn")

func transition_to(scene_path: String, white_wipe: bool = false, region_travel: bool = false, cave_motion: bool = false) -> bool:
	if busy:
		return false
	busy = true
	developer_menu.close_menu()
	close_pause()
	get_tree().paused = false
	battle_entry_pending = white_wipe
	var fade_duration := region_fade_duration if region_travel else transition_duration * 0.5
	Music.prepare_transition(scene_path, battle_wipe_duration if white_wipe else fade_duration)
	# white_wipe is retained as the existing call-site compatibility flag.
	# All boss hosts now enter through the same black-wall presentation.
	curtain.color = Color.BLACK
	curtain.position = Vector2.ZERO
	var fade: Tween
	if cave_motion:
		var world := get_tree().current_scene
		world.player.movement_locked = true
		world.player.velocity = Vector2.ZERO
		var sprite: Sprite2D = world.player.sprite
		var motion := create_tween().set_parallel(true)
		var descending := area_id == "underground_cave"
		if world.nearest_npc != null:
			motion.tween_property(world.player,"position",world.nearest_npc.position,.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		motion.tween_property(sprite,"position:y",32.0 if descending else -44.0,.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		motion.tween_property(sprite,"scale",sprite.scale*.55,.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		motion.tween_property(sprite,"modulate:a",0.0,.28)
		await motion.finished
	if white_wipe:
		battle_walls.duration = battle_wipe_duration
		await battle_walls.close_walls()
		curtain.modulate.a = 1.0
		curtain.show()
		battle_walls.hide()
	else:
		curtain.modulate.a = 0.0
		curtain.show()
		fade = create_tween()
		fade.tween_property(curtain, "modulate:a", 1.0, fade_duration)
		await fade.finished
	# Stop old streams before the next scene can start its soundtrack.
	for audio in get_tree().get_nodes_in_group("combat_music"):
		audio.stop()
	var error := ERR_FILE_NOT_FOUND
	if ResourceLoader.exists(scene_path):
		error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		last_save_message = "Transition could not load " + scene_path
		Music.sync_scene()
	else:
		await get_tree().scene_changed
		if region_travel:
			# Register destination bodies/camera while the curtain is fully black.
			await get_tree().physics_frame
			await get_tree().physics_frame
			var camera: Camera2D = get_tree().current_scene.player.get_node("Camera2D")
			camera.reset_smoothing()
			camera.force_update_scroll()
	fade = create_tween()
	fade.tween_property(curtain, "modulate:a", 0.0, battle_reveal_duration if white_wipe else fade_duration)
	await fade.finished
	curtain.hide()
	curtain.position.y = 0.0
	curtain.color = Color.BLACK
	if white_wipe and error == OK:
		get_tree().current_scene.finish_entry()
	battle_entry_pending = false
	busy = false
	transition_finished.emit.call_deferred()
	return error == OK

func snapshot(area: String, point: Vector2) -> Dictionary:
	return saves.validate({"version": 1, "area": area, "position": [point.x, point.y], "evil_bart_defeated": evil_bart_defeated, "story_flags": story_flags.duplicate(), "exploration": exploration.snapshot()})

func save_current() -> bool:
	var world := get_tree().current_scene
	if busy or world == null or world.name != "Overworld" or world.dialogue.active:
		saves.last_error = "Save unavailable during dialogue, transitions or combat."
		return false
	world.update_map_exploration()
	var ok := saves.write_save(snapshot(area_id, world.player.position))
	last_save_message = "Saved." if ok else saves.last_error
	return ok

func save_boss_victory() -> void:
	# Save only the known overworld return point, never combat runtime objects.
	var completed: bool = evil_bart_defeated if encounter_id == "bart" else story_flags.get(encounter_id + "_defeated", false)
	if encounter_active and completed:
		var ok := saves.write_save(snapshot(area_id, return_position))
		last_save_message = "Progress saved." if ok else saves.last_error

func has_unsaved_progress() -> bool:
	var world := get_tree().current_scene
	if world == null:
		return false
	if world.name == "Overworld":
		return snapshot(area_id, world.player.position) != saves.read_save()
	if encounter_active:
		return snapshot(area_id, return_position) != saves.read_save()
	return false

func load_game() -> bool:
	if busy:
		return false
	var data := saves.read_save()
	if data.is_empty():
		if pause_menu.opened:
			pause_menu.status.text = saves.last_error
		return false
	area_id = data.area
	return_position = Vector2(data.position[0], data.position[1])
	restore_position = true
	evil_bart_defeated = data.evil_bart_defeated
	story_flags = data.story_flags.duplicate()
	exploration.restore(data.exploration)
	map_reveal_cheat = false
	encounter_active = false
	return await transition_to("res://scenes/world/overworld.tscn")

func world_menu_open() -> bool:
	var world := get_tree().current_scene
	var map_modal: bool = world != null and world.has_method("map_modal_open") and world.map_modal_open()
	return developer_menu.opened or map_modal or (is_instance_valid(confirmation) and confirmation.visible) or (is_instance_valid(options_dialog) and options_dialog.visible) or pause_menu.opened

func can_pause() -> bool:
	var scene := get_tree().current_scene
	if busy or scene == null or get_tree().paused:
		return false
	if scene.name == "Overworld":
		return not scene.dialogue.active and not scene.map_modal_open()
	if scene.has_method("record_victory"):
		return not scene.battle.game_over and not scene.battle.victory_started
	return false

func open_pause() -> void:
	if not can_pause() or pause_menu.opened:
		return
	var scene := get_tree().current_scene
	var in_combat := scene.has_method("record_victory")
	if in_combat:
		_suspend_always(scene.battle)
	else:
		scene.hide_interaction()
	get_tree().paused = true
	pause_menu.show_menu(in_combat)

func _suspend_always(node: Node) -> void:
	if node.process_mode == Node.PROCESS_MODE_ALWAYS:
		suspended_modes[node] = node.process_mode
		node.process_mode = Node.PROCESS_MODE_PAUSABLE
	for child in node.get_children():
		_suspend_always(child)

func close_pause() -> void:
	if pause_menu != null:
		pause_menu.hide_menu()
	restore_suspended_modes()
	get_tree().paused = false

func restore_suspended_modes() -> void:
	for node in suspended_modes:
		if is_instance_valid(node):
			node.process_mode = suspended_modes[node]
	suspended_modes.clear()

func open_options() -> void:
	if not is_instance_valid(options_dialog):
		options_dialog = AcceptDialog.new()
		options_dialog.set_script(preload("res://scripts/ui/options_dialog.gd"))
		add_child(options_dialog)
		_attach_menu_back(options_dialog)
	options_dialog.open()

func confirm_action(message: String, action: Callable) -> void:
	if is_instance_valid(confirmation):
		return
	confirmation = ConfirmationDialog.new()
	confirmation.process_mode = Node.PROCESS_MODE_ALWAYS
	confirmation.theme = preload("res://scripts/ui/sketch_theme.gd").create()
	confirmation.title = "Confirm"
	confirmation.dialog_text = message
	add_child(confirmation)
	var dialog := confirmation
	var return_focus := get_viewport().gui_get_focus_owner()
	_attach_menu_back(dialog)
	dialog.confirmed.connect(func():
		confirmation = null
		dialog.queue_free()
		action.call()
	)
	dialog.canceled.connect(func():
		confirmation = null
		dialog.queue_free()
		if is_instance_valid(return_focus):
			return_focus.grab_focus()
	)
	dialog.popup_centered(Vector2i(440, 180))

func request_main_menu() -> void:
	if has_unsaved_progress():
		confirm_action("Return to the main menu and discard unsaved progress?", main_menu)
	else:
		main_menu()

func _show_key_notification() -> void:
	if not key_notification_pending:
		return
	key_notification_pending = false
	show_notification("Obtained: Flooded Forest Key", "KeyRewardNotification")

func show_notification(message: String, notification_name := "DebugNotification") -> void:
	var previous := get_node_or_null(NodePath(notification_name))
	if previous != null:
		remove_child(previous)
		previous.queue_free()
	var label := Label.new()
	label.name = notification_name
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 76
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = message
	label.add_theme_font_override("font", preload("res://assets/ui/fonts/DejaVuSansMono.ttf"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	var fade := label.create_tween()
	fade.tween_interval(3.0)
	fade.tween_property(label,"modulate:a",0.0,0.5)
	fade.tween_callback(label.queue_free)
