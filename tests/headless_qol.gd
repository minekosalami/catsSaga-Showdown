extends SceneTree

var failures: int = 0
var checks: int = 0
var session: Node

func check(ok: bool, description: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func key(code: Key, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)

func press(code: Key) -> void:
	key(code, true)
	await process_frame
	key(code, false)
	await process_frame

func _initialize() -> void:
	create_timer(60.0).timeout.connect(func(): quit(1))
	call_deferred("run")

func finish(dialogue: Node) -> void:
	while dialogue.active:
		await press(KEY_ENTER)

func write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()

func run() -> void:
	root.size = Vector2i(1280, 720)
	session = root.get_node("Session")
	session.saves.save_path = "user://validation-qol.json"
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(session.saves.save_path + suffix):
			DirAccess.remove_absolute(session.saves.save_path + suffix)
	check(session.saves.read_save().is_empty(), "missing save is handled gracefully")
	change_scene_to_file("res://scenes/main_menu.tscn")
	await process_frame
	await process_frame
	check(current_scene.menu_container.get_node("ContinueButton").disabled, "Continue disabled without valid save")
	await session.new_game()
	var world: Node = current_scene
	check(FileAccess.file_exists(session.saves.save_path), "new game creates one JSON save slot")
	check(session.saves.read_save().area == "entrance", "area-entry autosave records entrance")
	check(not session.has_unsaved_progress(), "autosaved entry has no unsaved progress")
	var player: CharacterBody2D = world.player
	check(player.sprite_texture == null and player.get_node("VisualPlaceholder").visible, "inaccessible custom sprite is not replaced by another artwork")
	key(KEY_D, true)
	await create_timer(0.3).timeout
	check(is_equal_approx(player.velocity.length(), player.speed), "normal overworld speed preserved")
	key(KEY_SHIFT, true)
	await create_timer(0.3).timeout
	check(is_equal_approx(player.velocity.length(), player.speed * 1.5), "Shift sprints at adjustable 1.5 multiplier")
	key(KEY_S, true)
	await create_timer(0.3).timeout
	check(is_equal_approx(player.velocity.length(), player.speed * player.sprint_multiplier), "sprinting diagonals remain normalized")
	key(KEY_D, false)
	key(KEY_S, false)
	key(KEY_SHIFT, false)
	key(KEY_A, true)
	await create_timer(0.1).timeout
	check(player.facing_left and not player.sprite.flip_h, "left movement preserves artwork's left facing")
	key(KEY_A, false)
	await create_timer(0.3).timeout
	check(player.facing_left, "standing preserves last facing direction")
	key(KEY_D, true)
	await create_timer(0.1).timeout
	key(KEY_D, false)
	check(not player.facing_left and player.sprite.flip_h, "right movement flips only sprite horizontally")
	await create_timer(0.3).timeout
	check(not player.facing_left, "right facing persists at rest")
	player.position = Vector2(450, 445)
	player.velocity = Vector2.ZERO
	await process_frame
	await process_frame
	check(world.nearest_npc.name == "InspectableTree" and world.interaction_indicator.visible, "shared interaction selects inspectable and shows [E]")
	check(world.interaction_indicator.text == "[E]", "indicator uses requested minimal label")
	await press(KEY_E)
	check(world.dialogue.active and world.dialogue.speaker_label.text == "> TREE", "inspectable uses terminal dialogue and object name")
	check(world.dialogue.lines.size() == 2 and world.dialogue.lines[1].text == "Probably.", "Inspector descriptions support multiple lines")
	check(not world.interaction_indicator.visible, "indicator hides during inspection")
	check(world.dialogue.audio.stream == null, "dialogue stays silent with optional sound slot empty")
	await press(KEY_ESCAPE)
	check(not paused and not session.pause_menu.opened, "pause cannot open during dialogue")
	var locked: Vector2 = player.position
	key(KEY_D, true)
	key(KEY_SHIFT, true)
	await create_timer(0.15).timeout
	check(player.position == locked, "sprint disabled during inspection")
	key(KEY_D, false)
	key(KEY_SHIFT, false)
	check(not session.save_current(), "manual save rejected during dialogue")
	await finish(world.dialogue)
	check(session.story_flags.get("inspected_tree", false), "inspection completion flag recorded")
	player.position = Vector2(280, 450)
	await process_frame
	check(not world.interaction_indicator.visible, "indicator disappears out of range")
	await press(KEY_ESCAPE)
	check(paused and session.pause_menu.opened, "Escape opens one reusable pause menu")
	check(session.pause_menu.buttons.Resume.has_focus(), "Resume receives keyboard focus")
	check(not world.interaction_indicator.visible, "pause hides interaction indicator")
	key(KEY_ESCAPE, true, true)
	await process_frame
	key(KEY_ESCAPE, false)
	check(session.pause_menu.opened, "echo events do not duplicate or toggle pause menu")
	var pause_position: Vector2 = player.position
	key(KEY_D, true)
	key(KEY_SHIFT, true)
	await create_timer(0.2).timeout
	check(player.position == pause_position, "gameplay and sprint stop while paused")
	key(KEY_D, false)
	key(KEY_SHIFT, false)
	session.pause_menu.buttons.Save.pressed.emit()
	check(session.pause_menu.status.text == "Saved.", "pause manual save displays confirmation")
	check(session.saves.read_save().story_flags.inspected_tree, "story flags serialize in save")
	session.pause_menu.buttons.Options.pressed.emit()
	check(session.options_dialog.visible and paused, "pause reuses options UI while paused")
	session.options_dialog.hide()
	await press(KEY_ESCAPE)
	check(not paused and not session.pause_menu.opened, "Escape resumes exploration")
	player.position += Vector2(60, 0)
	await process_frame
	check(session.has_unsaved_progress(), "movement beyond saved position marks progress unsaved")
	await press(KEY_ESCAPE)
	session.pause_menu.buttons.Load.pressed.emit()
	check(session.confirmation != null and paused, "Load asks before discarding unsaved progress")
	session.confirmation.canceled.emit()
	await process_frame
	check(paused and session.pause_menu.opened, "cancel load keeps exploration paused safely")
	session.pause_menu.buttons.Load.pressed.emit()
	session.confirmation.confirmed.emit()
	await create_timer(0.45).timeout
	world = current_scene
	player = world.player
	check(not paused and not session.pause_menu.opened, "confirmed load restores normal pause state")
	check(player.position.is_equal_approx(pause_position), "load restores exact saved position")
	check(session.story_flags.inspected_tree, "load restores progression flags")
	player.position += Vector2(40, 0)
	await process_frame
	session.request_main_menu()
	check(session.confirmation != null and current_scene.name == "Overworld", "Main Menu asks before discarding unsaved progress")
	session.confirmation.canceled.emit()
	await process_frame
	check(current_scene.name == "Overworld", "cancel Main Menu preserves current scene")
	session.request_main_menu()
	session.confirmation.confirmed.emit()
	await create_timer(0.45).timeout
	check(current_scene.name == "Mainmenu" and not paused, "confirmed Main Menu safely returns")
	check(not current_scene.menu_container.get_node("ContinueButton").disabled, "Continue enabled for valid save")
	current_scene._start_game()
	check(session.confirmation != null and not current_scene.transitioning, "Start Game confirms before overwriting save")
	session.confirmation.canceled.emit()
	await process_frame
	current_scene.menu_container.get_node("ContinueButton").pressed.emit()
	await create_timer(0.45).timeout
	check(current_scene.name == "Overworld" and session.story_flags.inspected_tree, "Continue restores saved game instead of resetting flags")
	check(not await session.transition_to("res://scenes/missing-qol-test.tscn"), "missing destination fails gracefully")
	check(not session.busy and not session.curtain.visible and not paused, "transition failure restores screen and controls")
	# One temporary overlapping target with an unmet condition must not steal E.
	world = current_scene
	player = world.player
	var tree: Node = world.map.get_node("Characters/InspectableTree")
	var other := Node2D.new()
	other.set_script(load("res://scripts/world/npc.gd"))
	other.required_flag = "not_yet"
	other.position = tree.position + Vector2(0, 20)
	world.map.get_node("Characters").add_child(other)
	player.position = tree.position + Vector2(0, 50)
	await process_frame
	await process_frame
	check(world.nearest_npc == tree, "unmet interaction conditions exclude closer target")
	other.required_flag = ""
	await process_frame
	await process_frame
	check(world.nearest_npc == other, "closest eligible object wins one shared interaction target")
	other.queue_free()
	await process_frame
	await press(KEY_E)
	check(world.dialogue.active and world.dialogue.speaker_label.text == "> TREE", "single E triggers only selected object")
	await finish(world.dialogue)
	# Save storage validation and recovery.
	var data: Dictionary = session.snapshot("entrance", Vector2(300, 450))
	check(session.saves.write_save(data), "safe JSON save writes and validates")
	data.position = [340.0, 450.0]
	check(session.saves.write_save(data), "replacement save succeeds")
	check(FileAccess.file_exists(session.saves.save_path + ".bak") and not FileAccess.file_exists(session.saves.save_path + ".tmp"), "safe replacement preserves backup and consumes temporary file")
	write_text(session.saves.save_path, "{broken")
	check(session.saves.read_save().position == [300.0, 450.0], "corrupt primary recovers previous valid backup")
	DirAccess.remove_absolute(session.saves.save_path + ".bak")
	check(session.saves.read_save().is_empty(), "corrupt save without backup fails safely")
	for invalid in [
		{"version": 999, "area": "entrance", "position": [280, 450]},
		{"version": 1, "area": "unknown", "position": [280, 450]},
		{"version": 1, "area": "entrance", "position": [-1, 450]},
		{"version": 1, "area": "entrance", "position": ["280", 450]},
		{"version": 1, "area": "entrance", "position": [280, 450], "story_flags": {"bad": "yes"}},
		{"version": 1, "area": "entrance", "position": [280, 450], "evil_bart_defeated": 1}
	]:
		check(session.saves.validate(invalid).is_empty(), "invalid schema/area/position/progression rejected")
	var minimal: Dictionary = session.saves.validate({"version": 1, "area": "entrance", "position": [280, 450]})
	check(not minimal.evil_bart_defeated and minimal.story_flags.is_empty(), "new optional save fields have safe defaults")
	check(session.saves.write_save(data), "valid save restores storage after corruption")
	await session.travel("bart_area", "FromDeep")
	check(session.saves.read_save().area == "bart_area", "area transitions autosave destination")
	session.begin_battle(Vector2(1000, 520))
	check(not session.save_current(), "manual save prevented during transition")
	await create_timer(0.45).timeout
	var host: Node = current_scene
	var game: Node = host.battle
	check(host.arena.size == Vector2i(540, 900), "combat viewport remains 540x900")
	var battle_speed: float = game.player.speed
	key(KEY_SHIFT, true)
	await process_frame
	check(game.player.speed == battle_speed and game.player.focus_speed == 150, "sprint does not alter combat speed or Shift focus")
	key(KEY_SHIFT, false)
	game.player.invincible = true
	game.music_player.seek(7)
	await create_timer(0.2).timeout
	game.player.activate_saturate()
	await create_timer(0.1).timeout
	var beam: Node
	for child in game.get_children():
		if child.scene_file_path == "res://scenes/rainbow_beam.tscn":
			beam = child
	await press(KEY_ESCAPE)
	check(paused and session.pause_menu.opened, "Escape pauses combat through same menu")
	check(session.pause_menu.buttons.Save.disabled and session.pause_menu.buttons.Load.disabled, "combat saving excludes runtime battle state")
	var boss_time: float = game.boss.elapsed
	var beam_time: float = beam.elapsed
	var music_time: float = game.music_player.get_playback_position()
	await create_timer(0.25).timeout
	check(game.boss.elapsed == boss_time and beam.elapsed == beam_time, "boss and ALWAYS-process SATURATE both freeze during manual pause")
	check(absf(game.music_player.get_playback_position() - music_time) < 0.06, "music playback pauses with battle")
	await press(KEY_ESCAPE)
	await create_timer(0.15).timeout
	check(not paused and game.boss.elapsed > boss_time and beam.elapsed > beam_time, "combat and SATURATE resume without resetting")
	check(absf(game.boss.elapsed - game.music_player.get_playback_position()) < 0.15, "boss music synchronization preserved after resume")
	game.boss.take_damage(game.boss.health)
	await create_timer(1.35).timeout
	check(session.saves.read_save().evil_bart_defeated, "boss defeat autosaves before leaving victory screen")
	check(not session.can_pause(), "manual pause never overrides victory behavior")
	game.ui.victory_continue.pressed.emit()
	await create_timer(0.45).timeout
	check(current_scene.player.position == Vector2(1000, 520), "victory return position remains exact")
	check(session.saves.read_save().area == "bart_area", "victory autosave preserves return area")
	# A separate manager reads actual disk state rather than Session memory.
	var fresh := preload("res://scripts/systems/save_manager.gd").new()
	fresh.save_path = session.saves.save_path
	check(fresh.read_save().evil_bart_defeated, "fresh save manager restores boss completion from disk")
	var old_path: String = session.saves.save_path
	session.saves.save_path = "user://nonexistent-qol-directory/save.json"
	check(not session.save_current() and not session.saves.last_error.is_empty(), "write failure reports useful error without crashing")
	session.saves.save_path = old_path
	current_scene.queue_free()
	await create_timer(0.25).timeout
	print("QOL VALIDATION: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
