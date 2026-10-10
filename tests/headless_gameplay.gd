# Run: godot --headless --path . --script res://tests/headless_gameplay.gd
extends SceneTree

var failures: int = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		failures += 1
	else:
		print("PASS: " + message)

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# --script with the headless dummy display starts at 64x64.
	# Apply the configured dimensions to exercise gameplay in its intended viewport.
	root.size = Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	var presets := ConfigFile.new()
	check(presets.load("res://export_presets.cfg") == OK, "export config parses without invented presets")
	var directory := DirAccess.open("res://scenes")
	for filename in directory.get_files():
		if filename.ends_with(".tscn"):
			var scene := load("res://scenes/" + filename) as PackedScene
			check(scene != null and scene.can_instantiate(), filename + " loads")
			var instance := scene.instantiate()
			check(instance != null, filename + " instantiates")
			instance.free()
	check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene")) == OK, "configured startup scene loads")
	await process_frame
	await process_frame
	check(root.size == Vector2i(540, 900), "540x900 display")
	var menu := current_scene
	check(menu.name == "Mainmenu" and menu.menu_container.get_child_count() == 7, "main menu controls initialize")
	await create_timer(0.1).timeout
	check(menu.size == Vector2(540, 900), "menu root fills viewport")
	check(menu.get_node("Background").size == menu.size, "background fills menu")
	check(menu.get_node("CenterContainer").size == menu.size, "center container fills menu")
	var menu_center: Vector2 = menu.menu_container.get_global_rect().get_center()
	check(menu_center.distance_to(Vector2(270, 450)) <= 1.0, "menu content centered")
	check(menu.get_child_count() == 2, "existing menu UI is not duplicated")
	root.size = Vector2i(600, 1000)
	await create_timer(0.1).timeout
	check(menu.size == Vector2(600, 1000), "menu follows viewport resize")
	root.size = Vector2i(540, 900)
	await create_timer(0.1).timeout
	var start: Button = menu.menu_container.get_child(3)
	check(start.text == "START GAME", "start button exists")
	check(start.has_focus(), "start receives keyboard focus")
	await create_timer(0.2).timeout
	check(start.scale.x > 1.0, "selection animation highlights focused button")
	menu._open_options()
	var dialog: AcceptDialog = menu.options_dialog
	menu._open_options()
	check(menu.options_dialog == dialog and dialog.visible, "Options reuses one visible dialog")
	dialog.hide()
	start.pressed.emit()
	check(menu.transitioning and start.disabled, "transition prevents duplicate activation")
	await create_timer(0.3).timeout
	var game := current_scene
	check(game.name == "Main", "menu button transitions to gameplay")
	var player := get_first_node_in_group("player")
	check(player != null, "player initialized")
	var hud = game.get_node("UI")
	await process_frame
	check(hud.health_label.text.count("●") == 3, "HUD shows initial health")
	check(hud.saturate_label.text.contains("READY"), "HUD shows SATURATE ready")
	check(not hud.boss_panel.visible, "boss HUD hidden before spawn")
	check(hud.health_label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "HUD leaves playfield pointer input unobstructed")
	check(game.health_label == hud.health_label and game.time_label == hud.timer_label, "game uses existing HUD references")
	check(game.music_player == game.get_node("MusicPlayer"), "script finds the existing music node")
	check(game.music_player is AudioStreamPlayer and game.music_player.playing, "music playback starts")
	check(game.music_player.stream != null, "original music stream remains assigned")
	player.invincible = true
	player.position = Vector2(270, 750)
	key(KEY_D, true)
	await create_timer(0.2).timeout
	key(KEY_D, false)
	check(player.position.x > 270, "D key moves player")
	key(KEY_Z, true)
	await process_frame
	await process_frame
	check(player.shoot_timer > 0, "Z key fires through input polling")
	var found := false
	for child in game.get_children():
		if child.scene_file_path == "res://scenes/bullet.tscn":
			found = true
	check(found, "shooting creates bullet scene")
	key(KEY_Z, false)
	await create_timer(7.2).timeout
	check(game.boss_spawned and is_instance_valid(game.boss), "boss spawns after drop time")
	var boss = game.boss
	check(boss.song_section == 1, "boss enters arrival section")
	check(hud.boss_panel.visible and hud.boss_bar.max_value == boss.max_health, "boss bar binds to spawned boss")
	boss.take_damage(10)
	await create_timer(0.25).timeout
	check(absf(hud.boss_bar.value - boss.health) < 0.1, "boss bar animates to signaled health")
	check(hud.boss_bar.size.y <= 8, "boss bar stays compact")
	check(hud.timer_label.text == "00:07", "HUD timer follows gameplay time")
	var previous_elapsed: float = boss.elapsed
	await create_timer(0.3).timeout
	check(boss.elapsed > previous_elapsed, "boss timeline advances after spawn")
	check(absf(boss.elapsed - game.elapsed_time) < 0.001, "boss and main share the playback clock")
	check(absf(game.elapsed_time - game.music_player.get_playback_position()) < 0.15, "timeline tracks music playback")
	game.music_player.seek(21.0)
	await create_timer(0.15).timeout
	check(boss.elapsed >= 21.0 and boss.elapsed < 22.0, "boss follows music seek")
	check(boss.song_section == 2, "music seek selects rising pressure attack section")
	check(absf(boss.elapsed - game.elapsed_time) < 0.001, "boss stays synchronized after seek")
	boss.position = Vector2(270, 500)
	var before_attack := game.get_child_count()
	boss.fire_ring(3, 145.0, 0.0, Color.WHITE)
	check(game.get_child_count() == before_attack + 3, "boss attack creates bullets")
	check(get_nodes_in_group("enemy_bullets").size() > 0, "spawned enemy projectiles join clearing group")
	# A stationary projectile on the sweep path can only disappear through clearing.
	var target_bullet = load("res://scenes/enemybullet.tscn").instantiate()
	game.add_child(target_bullet)
	target_bullet.position = Vector2(100, 700)
	target_bullet.speed = 0.0
	check(target_bullet.is_in_group("enemy_bullets"), "shared bullet scene carries group membership")
	key(KEY_X, true)
	await process_frame
	await process_frame
	key(KEY_X, false)
	check(player.saturate_used, "X activates SATURATE")
	check(hud.saturate_label.text.contains("USED"), "HUD shows SATURATE used")
	var beam_count := 0
	for child in game.get_children():
		if child.scene_file_path == "res://scenes/rainbow_beam.tscn":
			beam_count += 1
	check(beam_count == 1, "SATURATE creates one beam")
	key(KEY_X, true)
	await process_frame
	key(KEY_X, false)
	beam_count = 0
	for child in game.get_children():
		if child.scene_file_path == "res://scenes/rainbow_beam.tscn":
			beam_count += 1
	check(beam_count == 1, "SATURATE remains single use")
	await create_timer(1.8).timeout
	check(not is_instance_valid(boss), "SATURATE sweep damages and defeats boss")
	check(not is_instance_valid(target_bullet), "SATURATE sweep clears enemy projectile")
	check(not hud.boss_panel.visible, "boss HUD hides on defeat")
	player.invincible = false
	player.take_damage(3)
	await create_timer(0.35).timeout
	check(paused and hud.end_screen.visible, "game-over UI appears while gameplay is paused")
	check(hud.health_label.text.count("●") == 0, "HUD shows depleted health")
	var retry: Button = game.restart_button
	check(retry.visible and retry.has_focus(), "existing Retry button remains accessible while paused")
	game.music_player.stop()
	retry.pressed.emit()
	await process_frame
	await process_frame
	game = current_scene
	hud = game.get_node("UI")
	await process_frame
	check(not paused and not game.game_over, "Retry restarts existing gameplay")
	check(not hud.end_screen.visible and hud.saturate_label.text.contains("READY"), "Retry resets HUD state")
	# Exercise the boss validity guard once it has been freed by SATURATE.
	await create_timer(0.1).timeout
	# Let the audio mixer release the active MP3 playback before shutting down.
	game.music_player.stop()
	game.queue_free()
	await create_timer(0.1).timeout
	print("FUNCTIONAL VALIDATION: ", failures, " failures")
	quit(0 if failures == 0 else 1)
