# Actual viewport captures, plus mouse routing and window-mode checks.
# godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
#   --script res://tests/render_ui.gd -- --output=/tmp/catsSaga-review
extends SceneTree

var output_directory: String = "user://ui-review"
var failures: int = 0
var session: Node

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("UI screenshots require a graphical display")
		quit(2)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_directory = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output_directory)
	create_timer(55.0).timeout.connect(func(): quit(1))
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if ok:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func snapshot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output_directory.path_join(filename + ".png"))
	check(error == OK, "capture " + filename)

func map_overview(filename: String) -> void:
	var world: Node = current_scene
	var camera: Camera2D = world.player.get_node("Camera2D")
	var previous_position: Vector2 = world.player.position
	var previous_zoom := camera.zoom
	world.player.set_physics_process(false)
	world.player.position = world.map.map_size / 2
	camera.zoom = Vector2.ONE * minf(1280.0 / world.map.map_size.x, 720.0 / world.map.map_size.y) * 0.93
	camera.reset_smoothing()
	await create_timer(0.1).timeout
	await snapshot(filename)
	world.player.position = previous_position
	camera.zoom = previous_zoom
	camera.reset_smoothing()
	world.player.set_physics_process(true)

func mouse_click(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	Input.parse_input_event(motion)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		Input.parse_input_event(event)
		await process_frame

func press(code: Key, window: Window = null) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		if window == null:
			Input.parse_input_event(event)
		else:
			window.push_input(event)
		await process_frame

func run() -> void:
	var save_manager = root.get_node("Session").saves
	save_manager.save_path = "user://validation-render_ui.json"
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_manager.save_path + suffix):
			DirAccess.remove_absolute(save_manager.save_path + suffix)
	root.size = Vector2i(1280, 720)
	session = root.get_node("Session")
	change_scene_to_file("res://scenes/main_menu.tscn")
	await create_timer(0.6).timeout
	await snapshot("rpg-menu")
	current_scene._show_info()
	await create_timer(0.3).timeout
	await snapshot("rpg-controls")
	current_scene._show_credits()
	await snapshot("rpg-credits")
	await press(KEY_X)
	check(current_scene.menu_container.visible, "graphical X returns Info to main menu")
	current_scene._open_options()
	await process_frame
	await snapshot("rpg-options")
	await press(KEY_X, current_scene.options_dialog)
	check(not current_scene.options_dialog.visible, "graphical X closes modal Options viewport")
	var fullscreen: CheckButton = current_scene.options_dialog.find_child("FullscreenToggle", true, false)
	fullscreen.button_pressed = true
	await create_timer(0.2).timeout
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Options enables fullscreen")
	fullscreen.button_pressed = false
	await create_timer(0.2).timeout
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "Options restores windowed mode")
	for expected_mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_WINDOWED]:
		var event := InputEventKey.new()
		event.keycode = KEY_F11
		event.pressed = true
		Input.parse_input_event(event)
		await process_frame
		event = InputEventKey.new()
		event.keycode = KEY_F11
		event.pressed = false
		Input.parse_input_event(event)
		await create_timer(0.2).timeout
		check(DisplayServer.window_get_mode() == expected_mode, "F11 toggles window mode")
	current_scene._start_game()
	await create_timer(0.5).timeout
	check(current_scene.name == "Overworld", "widescreen menu enters forest")
	await snapshot("qol-entrance")
	await map_overview("forest-entrance-restructured-overview")
	current_scene.player.position = Vector2(450, 335)
	await create_timer(0.5).timeout
	await snapshot("qol-indicator")
	session.open_pause()
	await create_timer(0.2).timeout
	check(paused and session.pause_menu.opened, "graphical pause overlay freezes gameplay")
	await snapshot("qol-pause")
	session.pause_menu.buttons.Save.pressed.emit()
	await snapshot("qol-saved")
	session.open_options()
	await process_frame
	await press(KEY_X, session.options_dialog)
	check(paused and not session.options_dialog.visible, "graphical X returns Options to paused parent")
	await press(KEY_X)
	check(not paused and not session.pause_menu.opened, "graphical X closes forest pause")
	current_scene.dialogue.start_lines([{"speaker": "TREE", "text": "It's a tree."}, {"speaker": "TREE", "text": "Probably."}])
	await create_timer(0.5).timeout
	await snapshot("qol-inspection")
	await session.travel("deep_forest", "FromEntrance")
	current_scene.player.position = Vector2(900, 490)
	await create_timer(0.5).timeout
	await snapshot("rpg-deep-forest")
	await map_overview("deep-forest-restructured-overview")
	# Show both denser grass-side clusters from an unobstructed path position.
	current_scene.player.position = Vector2(1150, 540)
	await create_timer(0.5).timeout
	await snapshot("forest-deep-clusters")
	current_scene.dialogue.start("forest_npc")
	await create_timer(0.9).timeout
	await snapshot("rpg-dialogue")
	await session.travel("bart_area", "FromDeep")
	current_scene.player.position = Vector2(1000, 520)
	await create_timer(0.5).timeout
	await snapshot("rpg-bart-area")
	await map_overview("bart-area-restructured-overview")
	var d: Node = current_scene.dialogue
	d.start("bart_encounter")
	d.advance()
	d.advance()
	await process_frame
	await snapshot("bart-opening-choice")
	await mouse_click(d.choice_buttons[0].get_global_rect().get_center())
	check(d.node_id == "BART_002" and d.line_index == 0, "mouse selects mandatory What? without skipping next line")
	d.advance()
	d.advance()
	await process_frame
	await mouse_click(d.choice_buttons[1].get_global_rect().get_center())
	check(not d.active and not session.busy, "mouse selects No without starting battle")
	d.start("bart_encounter")
	d.advance()
	d.advance()
	d._choose(0)
	d.advance()
	d.advance()
	d._choose(0)
	d.advance()
	await snapshot("bart-refraction")
	d.advance()
	d.advance()
	d.advance()
	d.advance()
	d.advance()
	await process_frame
	await snapshot("bart-rainbow-choices")
	check(d.text_label.get_content_height() <= d.text_label.size.y, "long dialogue fits body above choices")
	await mouse_click(d.choice_buttons[1].get_global_rect().get_center())
	check(d.node_id == "BART_004B", "mouse selects rainbow explanation choice")
	d.advance()
	await snapshot("bart-saturate-parentheses")
	d._finish("declined")
	session.begin_battle(current_scene.player.position)
	await create_timer(0.25).timeout
	await snapshot("bart-black-walls")
	await scene_changed
	await snapshot("bart-black-reveal")
	await create_timer(0.4).timeout
	var host: Node = current_scene
	var game: Node = host.battle
	game.player.invincible = true
	check(host.arena.size == Vector2i(540, 900), "graphical combat viewport stays 540x900")
	check(host.arena_container.scale == Vector2(0.8, 0.8), "graphical arena uses uniform 0.8 scale")
	await create_timer(1.0).timeout
	await snapshot("rpg-combat-opening")
	while not game.boss_spawned:
		await process_frame
	await create_timer(0.6).timeout
	await snapshot("rpg-combat-boss")
	session.open_pause()
	await create_timer(0.2).timeout
	await snapshot("qol-combat-pause")
	await press(KEY_X)
	check(paused and session.pause_menu.opened, "graphical combat pause ignores forest X back")
	session.close_pause()
	# Test resizing on a larger PC display using the configured canvas stretch.
	root.size = Vector2i(1600, 900)
	await create_timer(0.2).timeout
	check(host.arena.size == Vector2i(540, 900), "larger window never resizes combat simulation")
	check(is_equal_approx(host.arena_container.scale.x, host.arena_container.scale.y), "larger window preserves uniform arena scale")
	await snapshot("rpg-combat-large-window")
	root.size = Vector2i(1280, 720)
	await press(KEY_X)
	check(game.player.saturate_used, "graphical combat X activates SATURATE")
	await create_timer(0.65).timeout
	await snapshot("rpg-saturate")
	await create_timer(1.0).timeout
	game.boss.take_damage(game.boss.health)
	await create_timer(1.35).timeout
	await snapshot("rpg-victory")
	# This click begins in the root viewport and must be transformed into arena UI.
	var button_center: Vector2 = game.ui.victory_retry.get_global_rect().get_center()
	var root_point: Vector2 = host.arena_container.position + button_center * host.arena_container.scale
	var retry_scene_id := current_scene.get_instance_id()
	await mouse_click(root_point)
	while current_scene == null or current_scene.get_instance_id() == retry_scene_id or session.busy: await process_frame
	check(current_scene != host and current_scene.name == "CombatHost", "mouse click reaches Retry inside scaled viewport")
	host = current_scene
	game = host.battle
	check(game.player.health == 3 and not game.victory_started, "mouse Retry starts a fresh battle")
	game.player.invincible = true
	game.music_player.seek(7.0)
	await create_timer(0.2).timeout
	game.boss.take_damage(game.boss.health)
	await create_timer(1.35).timeout
	button_center = game.ui.victory_continue.get_global_rect().get_center()
	root_point = host.arena_container.position + button_center * host.arena_container.scale
	await mouse_click(root_point)
	await create_timer(0.5).timeout
	check(current_scene.name == "Overworld", "mouse return-to-forest reaches overworld")
	await create_timer(1.8).timeout
	await snapshot("rpg-returned-forest")
	check(current_scene.dialogue.active and current_scene.dialogue.lines[0].text.begins_with("You were more powerful"), "victory return shows one-time dialogue")
	current_scene.queue_free()
	await create_timer(0.3).timeout
	print("GRAPHICAL VALIDATION: ", failures, " failures")
	# Allow the audio server to retire looping playback before test shutdown.
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	quit(0 if failures == 0 else 1)
