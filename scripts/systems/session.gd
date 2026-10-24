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
@export_range(0.3, 0.5) var transition_duration: float = 0.36
@export var region_fade_duration: float = 0.3
var story_flags: Dictionary = {}
var story_progress := preload("res://scripts/story/progress.gd").new()
var exploration := preload("res://scripts/maps/exploration.gd").new()
var map_reveal_cheat := false
var unrestricted_region_access := false # Debug only; deliberately absent from saves.
var show_coordinates := false # Session-only visualization; never saved.
var reveal_all_locations := false
var cave_event_active := false
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
var battle_transition: Control
var active_slot := 1
var playtime := 0.0
var manual_checkpoint: Dictionary = {}
var fresh_run := false
var save_point_active := false
var standalone_settings_pause := false
var migration_message := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	migration_message = saves.migrate_legacy()
	active_slot = maxi(1,saves.most_recent_slot())
	saves.select_slot(active_slot)
	curtain = ColorRect.new()
	curtain.color = Color.BLACK
	add_child(curtain)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.hide()
	var entry_layer := CanvasLayer.new()
	entry_layer.layer = 200 # Above cave desaturation, HUD and developer overlays.
	add_child(entry_layer)
	battle_transition = preload("res://scripts/ui/battle_entry.gd").new()
	entry_layer.add_child(battle_transition)
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
	if busy and battle_entry_pending:
		get_viewport().set_input_as_handled()
		return
	if developer_menu.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if developer_menu.opened: return
	if event.is_action_pressed("menu_back") and not event.is_echo() and back_outside_battle():
		get_viewport().set_input_as_handled()
		return
	var pause_pressed: bool = (event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE) or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_START)
	# B remains the combat ability. It backs out only while a menu is open.
	if (pause_pressed or (pause_menu.opened and event.is_action_pressed("ui_cancel"))) and not event.is_echo():
		if pause_menu.opened:
			if not is_instance_valid(confirmation) and not (is_instance_valid(options_dialog) and options_dialog.visible):
				close_pause()
				get_viewport().set_input_as_handled()
		elif can_pause():
			open_pause()
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
			scene.menu_container.get_node("SettingsButton").grab_focus()
		return true
	if pause_menu.opened:
		close_pause()
		return true
	if scene.name == "Mainmenu" and scene.has_method("go_back"):
		return scene.go_back()
	# Branching dialogue has no safe history/back operation; never skip it.
	return false

func _attach_menu_back(window: Window) -> void:
	var input_handler := Node.new()
	input_handler.set_script(preload("res://scripts/ui/menu_back_input.gd"))
	window.add_child(input_handler)

func toggle_fullscreen() -> void:
	get_node("/root/GameSettings").toggle_fullscreen()

func _process(delta: float) -> void:
	var scene := get_tree().current_scene
	if not get_tree().paused and not busy and scene!=null and (scene.name=="Overworld" or encounter_active):playtime+=delta

func new_game(slot: int = 1) -> void:
	if busy:
		return
	if slot<1 or slot>3:return
	active_slot=slot
	saves.select_slot(slot)
	playtime=0.0
	fresh_run=true
	manual_checkpoint={}
	area_id = "entrance"
	entry_marker = "Start"
	restore_position = false
	evil_bart_defeated = false
	story_flags.clear()
	story_progress.restore({})
	story_flags[preload("res://scripts/journey/layout.gd").REVISION] = true
	exploration.reset()
	map_reveal_cheat = false
	key_notification_pending = false
	encounter_active = false
	await transition_to("res://scenes/world/overworld.tscn")

func travel(destination: String, marker: String, cave_motion: bool = false) -> void:
	if not preload("res://scripts/journey/layout.gd").active(destination): return
	if busy:
		return
	area_id = destination
	entry_marker = marker
	restore_position = false
	if await transition_to("res://scenes/world/overworld.tscn", false, true, cave_motion):
		if destination == "underground_cave":
			story_flags["underground_cave_discovered"] = true

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
	if busy or area_id != "flooded_forest" or not region_access_allowed(story_flags.get("flooded_forest_key_obtained", false)) or story_flags.get("boss2_defeated", false):
		return
	return_position = position_before_battle
	encounter_id = "boss2"
	encounter_active = true
	await transition_to("res://scenes/boss2/combat_host.tscn", true)

## Future encounters use this entry point without duplicating the curtain.
func begin_encounter(identifier: String, host_path: String, before: Vector2, completed_flag: String) -> void:
	if identifier == "incarna": return # Complete implementation retained for relocation.
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
	await transition_to("res://scenes/world/overworld.tscn")

func return_to_flooded_forest() -> void:
	if busy or not story_flags.get("boss2_defeated", false):
		return
	area_id = "flooded_forest"
	restore_position = true
	encounter_active = false
	await transition_to("res://scenes/world/overworld.tscn")

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

func transition_to(scene_path: String, white_wipe: bool = false, region_travel: bool = false, cave_motion: bool = false) -> bool:
	if scene_path.begins_with("res://scenes/incarna/") or scene_path.begins_with("res://scenes/wonderland/") or scene_path=="res://scenes/world/underground_cave.tscn": return false
	if busy:
		return false
	busy = true
	developer_menu.close_menu()
	close_pause()
	get_tree().paused = false
	battle_entry_pending = white_wipe
	if white_wipe:
		return await _battle_entry(scene_path)
	var fade_duration := region_fade_duration if region_travel else transition_duration * 0.5
	Music.prepare_transition(scene_path, fade_duration)
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
	fade.tween_property(curtain, "modulate:a", 0.0, fade_duration)
	await fade.finished
	curtain.hide()
	curtain.position.y = 0.0
	curtain.color = Color.BLACK
	battle_entry_pending = false
	busy = false
	transition_finished.emit.call_deferred()
	return error == OK

func _battle_entry(scene_path: String) -> bool:
	var previous := get_tree().current_scene
	if previous != null:
		_freeze_entry_tree(previous)
	Music.prepare_transition(scene_path, 0.20)
	battle_transition.capture(previous)
	await battle_transition.blackout()
	for audio in get_tree().get_nodes_in_group("combat_music"): audio.stop()
	var error := ERR_FILE_NOT_FOUND
	if ResourceLoader.exists(scene_path): error = get_tree().change_scene_to_file(scene_path)
	var host: Node
	if error == OK:
		await get_tree().scene_changed
		host = get_tree().current_scene
		if is_instance_valid(host) and host.has_method("finish_entry"):
			await battle_transition.arrive(host)
		else:
			error = ERR_INVALID_DATA
	# Also recover from a scene being replaced externally while the overlay runs.
	var success := error == OK and is_instance_valid(host) and host == get_tree().current_scene
	battle_transition.clear(not success)
	battle_entry_pending = false
	busy = false
	if success:
		host.finish_entry()
	else:
		restore_suspended_modes()
		encounter_active = false
		last_save_message = "Transition could not enter " + scene_path
		Music.sync_scene()
	transition_finished.emit.call_deferred()
	return success

func _freeze_entry_tree(node: Node, root_node: bool = true) -> void:
	# Explicit ALWAYS/PAUSABLE children can override a disabled parent.
	# Inheriting children freeze with their parent; retain their original modes.
	if root_node or node.process_mode != Node.PROCESS_MODE_INHERIT:
		suspended_modes[node] = node.process_mode
		node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children(): _freeze_entry_tree(child, false)

func return_to_cave() -> void:
	if busy: return
	encounter_active = false
	area_id = "flooded_forest"
	entry_marker = "Start"
	restore_position = false
	cave_event_active = false
	await transition_to("res://scenes/world/overworld.tscn")

func snapshot(area: String, point: Vector2) -> Dictionary:
	return saves.validate({"version": 1, "playtime":playtime,"area": area, "position": [point.x, point.y], "evil_bart_defeated": evil_bart_defeated, "story_flags": story_flags.duplicate(), "story_progress": story_progress.snapshot(), "exploration": exploration.snapshot()})

func save_current() -> bool:
	var world := get_tree().current_scene
	if not save_point_active or busy or encounter_active or world==null or world.name!="Overworld" or world.dialogue.active:
		saves.last_error="Save only at a save point, outside combat and dialogue."
		return false
	world.update_map_exploration()
	var data := snapshot(area_id,world.player.position)
	var ok := saves.write_save(data)
	if ok:
		manual_checkpoint=data.duplicate(true)
		fresh_run=false
		saves.mark_used(active_slot)
	last_save_message="Saved to Slot %d."%active_slot if ok else saves.last_error
	return ok

func save_boss_victory() -> void:
	# Compatibility entry point for existing hosts. Victories remain in memory
	# until the player deliberately saves at a statue; never write from combat.
	pass

func has_unsaved_progress() -> bool:
	var scene := get_tree().current_scene
	if scene==null or scene.name=="Mainmenu":return false
	return true if manual_checkpoint.is_empty() else snapshot(area_id,scene.player.position if scene.name=="Overworld" else return_position)!=manual_checkpoint

func load_game(slot: int = 0) -> bool:
	if busy:return false
	if slot==0:slot=saves.most_recent_slot()
	var data := saves.read_slot(slot)
	if data.is_empty():
		last_save_message="No valid save in Slot %d. No new game was started."%slot
		show_notification(last_save_message)
		return false
	var recovery_message: String=saves.last_error
	active_slot=slot
	saves.select_slot(slot)
	area_id=data.area
	return_position=Vector2(data.position[0],data.position[1])
	restore_position=true
	evil_bart_defeated=data.evil_bart_defeated
	story_flags=data.story_flags.duplicate()
	story_progress.restore(data.story_progress)
	exploration.restore(data.exploration)
	playtime=data.playtime
	manual_checkpoint=data.duplicate(true)
	fresh_run=false
	map_reveal_cheat=false
	key_notification_pending=false
	encounter_active=false
	var ok := await transition_to("res://scenes/world/overworld.tscn")
	if ok:
		saves.mark_used(slot)
		if not recovery_message.is_empty():show_notification(recovery_message)
	return ok

func retry_last_save() -> void:
	if busy:return
	if fresh_run:
		await new_game(active_slot)
	else:
		await load_game(active_slot)

func open_save_point(statue: Node2D) -> void:
	var world := get_tree().current_scene
	if busy or encounter_active or get_tree().paused or world==null or world.name!="Overworld" or world.dialogue.active or world.checking_spawn or world_menu_open() or statue.global_position.distance_to(world.player.global_position)>statue.interaction_radius:return
	world.hide_interaction()
	save_point_active=true
	get_tree().paused=true
	confirm_action("Save current progress to Slot %d?"%active_slot,func():
		var ok := save_current()
		save_point_active=false
		get_tree().paused=false
		show_notification(last_save_message if ok else saves.last_error)
	)
	confirmation.get_ok_button().text="Save"
	confirmation.canceled.connect(func():save_point_active=false;get_tree().paused=false)

func world_menu_open() -> bool:
	var world := get_tree().current_scene
	var map_modal: bool = world != null and world.has_method("map_modal_open") and world.map_modal_open()
	return cave_event_active or developer_menu.opened or map_modal or (is_instance_valid(confirmation) and confirmation.visible) or (is_instance_valid(options_dialog) and options_dialog.visible) or pause_menu.opened

func can_pause() -> bool:
	var scene := get_tree().current_scene
	if busy or cave_event_active or scene == null or get_tree().paused:
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
		# Confirm/cancel buttons must not carry into attack/sprint after resuming.
		if pause_menu.opened:
			for action in ["attack","interact","ability"]:
				if InputMap.has_action(action):Input.action_release(action)
		pause_menu.hide_menu()
	restore_suspended_modes()
	get_tree().paused = false

func restore_suspended_modes() -> void:
	for node in suspended_modes:
		# A replaced host may still be alive while detached and awaiting deletion.
		if is_instance_valid(node) and node.is_inside_tree():
			node.process_mode = suspended_modes[node]
	suspended_modes.clear()

func open_options() -> void:
	if battle_entry_pending:return
	if not pause_menu.opened and can_pause():
		open_pause()
		standalone_settings_pause=true
	if not is_instance_valid(options_dialog):
		options_dialog = AcceptDialog.new()
		options_dialog.set_script(preload("res://scripts/ui/options_dialog.gd"))
		add_child(options_dialog)
		_attach_menu_back(options_dialog)
		options_dialog.visibility_changed.connect(func():
			if not options_dialog.visible and standalone_settings_pause:
				standalone_settings_pause=false
				close_pause()
		)
	options_dialog.open()

func confirm_action(message: String, action: Callable) -> void:
	if is_instance_valid(confirmation):
		return
	confirmation = ConfirmationDialog.new()
	confirmation.process_mode = Node.PROCESS_MODE_ALWAYS
	confirmation.theme = preload("res://scripts/ui/menu/theme.gd").create()
	confirmation.title = "Confirm"
	confirmation.dialog_text = message
	var modal_parent: Node=options_dialog if is_instance_valid(options_dialog) and options_dialog.visible else self
	modal_parent.add_child(confirmation)
	var dialog := confirmation
	var return_focus: Control=options_dialog.gui_get_focus_owner() if modal_parent==options_dialog else get_viewport().gui_get_focus_owner()
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
	dialog.popup_centered(Vector2i(480, 200))

func request_main_menu() -> void:
	if cave_event_active: return
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
