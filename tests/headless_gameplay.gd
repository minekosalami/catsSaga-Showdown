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
	create_timer(65.0).timeout.connect(func():
		push_error("Gameplay validation timed out")
		quit(1)
	)
	call_deferred("run")

func run() -> void:
	# --script with the headless dummy display starts at 64x64.
	# Apply the configured dimensions to exercise gameplay in its intended viewport.
	var save_manager = root.get_node("Session").saves
	save_manager.save_path = "user://validation-headless_gameplay.json"
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_manager.save_path + suffix):
			DirAccess.remove_absolute(save_manager.save_path + suffix)
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
	check(root.size == Vector2i(1280, 720), "1280x720 widescreen display")
	var menu := current_scene
	check(menu.name == "Mainmenu" and menu.menu_container.get_child_count() == 7, "main menu controls initialize")
	await create_timer(0.1).timeout
	check(menu.size == Vector2(1280, 720), "menu root fills viewport")
	check(menu.get_node("Background").size == menu.size, "background fills menu")
	check(menu.get_node("CenterContainer").size == menu.size, "center container fills menu")
	var menu_center: Vector2 = menu.menu_container.get_global_rect().get_center()
	check(menu_center.distance_to(Vector2(640, 360)) <= 1.0, "menu content centered")
	check(menu.get_child_count() == 2, "existing menu UI is not duplicated")
	root.size = Vector2i(1920, 1080)
	await create_timer(0.1).timeout
	check(menu.size == Vector2(1280, 720), "widescreen stretch keeps UI logical size on larger window")
	root.size = Vector2i(1280, 720)
	await create_timer(0.1).timeout
	check(menu.menu_container.get_node_or_null("Emblem") == null, "menu has no decorative cat picture")
	check(menu.title_label.get_theme_font("font") == load("res://assets/ui/fonts/DejaVuSansMono.ttf"), "menu title uses bundled coding font")
	menu.menu_container.get_node("InfoButton").pressed.emit()
	await create_timer(0.25).timeout
	check(menu.info_container.visible and not menu.menu_container.visible, "Info opens within the menu")
	check(menu.controls_panel.visible and not menu.info_content.visible, "Controls uses one dedicated layout")
	var control_text := ""
	for grid in menu.controls_grids:
		check(grid.columns == 2 and grid.get_theme_constant("v_separation") >= 18, "control rows have two columns and generous spacing")
		for label in grid.get_children():
			control_text += label.text + " "
	check(control_text == "WASD / ARROWS Move SHIFT Focus movement Z Shoot X SATURATE ", "Controls describes actual script keybindings")
	check(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(menu.info_container.get_global_rect()), "Controls and Back fit inside widescreen")
	for grid in menu.controls_grids:
		check(grid.get_child(2).position.y - grid.get_child(0).position.y >= 50, "control rows do not overlap")
	menu.info_container.get_node("CreditsButton").pressed.emit()
	check(menu.info_content.visible and not menu.controls_panel.visible and menu.info_content.text.contains("LLiosette — Creator") and menu.info_content.text.contains("Basic Caves & Dungeons — schwarnhild"), "Credits preserves LLiosette and credits the documented cave pack creator")
	menu.info_container.get_node("BackButton").pressed.emit()
	check(menu.menu_container.visible and not menu.info_container.visible, "Info Back returns to primary menu")
	menu._show_info()
	key(KEY_ESCAPE, true)
	await process_frame
	key(KEY_ESCAPE, false)
	check(menu.menu_container.visible, "Escape returns from Info")
	var start: Button = menu.menu_container.get_node("StartButton")
	start.grab_focus()
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
	await create_timer(0.45).timeout
	check(current_scene.name == "Overworld", "menu Start transitions to overworld")
	await root.get_node("Session").transition_to("res://scenes/combat_host.tscn")
	var host := current_scene
	check(host.arena.size == Vector2i(540, 900), "combat viewport remains exactly 540x900")
	check(host.arena_container.scale.is_equal_approx(Vector2(0.8, 0.8)), "arena scales uniformly to 0.8")
	check(host.arena_container.position.is_equal_approx(Vector2(424, 0)), "432x720 arena is horizontally centered")
	var game: Node = current_scene.battle
	check(game.name == "Main", "host instances the original battle")
	var player := get_first_node_in_group("player")
	check(player != null, "player initialized")
	var hud = game.get_node("UI")
	await process_frame
	check(hud.health_label.text.count("●") == 3, "HUD shows initial health")
	check(hud.saturate_label.text.contains("READY"), "HUD shows SATURATE ready")
	check(not hud.boss_panel.visible, "boss HUD hidden before spawn")
	check(not game.victory_started and not hud.victory_screen.visible, "opening gameplay has no victory screen")
	check(hud.health_label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "HUD leaves playfield pointer input unobstructed")
	check(game.health_label == hud.health_label and game.time_label == hud.timer_label, "game uses existing HUD references")
	check(game.music_player == game.get_node("MusicPlayer"), "script finds the existing music node")
	check(game.music_player is AudioStreamPlayer and game.music_player.playing, "music playback starts")
	check(game.music_player.stream != null, "original music stream remains assigned")
	check(game.music_player.stream.resource_path == "res://assets/fight.v.scale - catsSaga version.mp3", "correct soundtrack remains assigned")
	var master := AudioServer.get_bus_index("Master")
	check(master >= 0 and not AudioServer.is_bus_mute(master), "Master audio bus is not muted")
	check(is_equal_approx(game.music_player.volume_db, root.get_node("Music").gain_for_path(game.music_player.stream.resource_path)) and game.music_player.bus == &"Master", "music uses measured normalization gain and audible Master routing")
	var capture := AudioEffectCapture.new()
	AudioServer.add_bus_effect(master, capture)
	await create_timer(0.2).timeout
	var samples := capture.get_buffer(capture.get_frames_available())
	var peak := 0.0
	for sample in samples:
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	check(peak > 0.001, "music produces non-silent samples at the Master bus")
	AudioServer.remove_bus_effect(master, AudioServer.get_bus_effect_count(master) - 1)
	check(absf(player.position.x - 270.0) < 1.0 and absf(player.position.y - 780.0) < 1.0, "player starts at bottom center")
	var player_sprite: Sprite2D = player.get_node("Sprite2D")
	var player_bounds := player_sprite.global_transform * player_sprite.get_rect()
	check(Rect2(Vector2.ZERO, Vector2(540, 900)).encloses(player_bounds), "full player sprite starts inside playfield")
	player.take_damage(1)
	await process_frame
	await process_frame
	check(hud.health_label.text.contains("2 / 3") and hud.health_label.text.count("●") == 2, "HUD responds to actual player damage")
	player.invulnerability_timer = 0.0
	for code in [KEY_C, KEY_A, KEY_T, KEY_A]:
		key(code, true)
		await process_frame
		key(code, false)
	check(player.invincible, "typing CATA enables invincibility")
	player.take_damage(1)
	check(player.health == 2, "CATA prevents collision damage")
	for code in [KEY_C, KEY_A, KEY_T, KEY_A]:
		key(code, true)
		await process_frame
		key(code, false)
	check(not player.invincible, "typing CATA again disables invincibility")
	player.invincible = true
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
	check(get_nodes_in_group("opening_enemies").size() > 0, "opening enemies exist before the music drop")
	# Observe the real music-triggered spawn rather than triggering it manually.
	while not game.boss_spawned:
		await process_frame
	var entrance_time: float = game.elapsed_time
	check(entrance_time >= 6.85 and entrance_time < 6.95, "boss entrance triggers at the first music drop")
	check(get_nodes_in_group("opening_enemies").is_empty(), "all opening enemies are removed immediately")
	check(hud.entrance_flash.modulate.a > 0.0, "white entrance flash starts on spawn")
	check(game.boss.entrance_tween.is_running(), "boss bounce starts on spawn")
	var entering_sprite: Sprite2D = game.boss.get_node("Sprite2D")
	var entering_bounds := entering_sprite.global_transform * entering_sprite.get_rect()
	check(entering_bounds.position.y > 146.0, "entrance artwork stays below the boss HUD")
	await create_timer(0.55).timeout
	check(hud.entrance_flash.modulate.a == 0.0, "entrance flash ends without repeats")
	check(absf(game.boss.get_node("Sprite2D").scale.x - 0.10603448) < 0.001, "entrance restores sprite scale")
	check(hud.boss_panel.modulate.a == 1.0, "boss health bar finishes smooth reveal")
	game._spawn_enemies(10.0)
	check(get_nodes_in_group("opening_enemies").is_empty(), "regular enemies cannot spawn during boss fight")
	check(hud.boss_caption.text.begins_with("EVIL BART"), "HUD names Evil Bart beside health bar")
	check(game.boss_spawned and is_instance_valid(game.boss), "boss spawns after drop time")
	var boss = game.boss
	check(boss.song_section == 1, "boss enters arrival section")
	check(absf(boss.position.y - 240.0) < 1.0, "boss spawns below top HUD")
	var boss_sprite: Sprite2D = boss.get_node("Sprite2D")
	var boss_bounds := boss_sprite.global_transform * boss_sprite.get_rect()
	check(boss_bounds.position.y > hud.boss_panel.get_global_rect().end.y + 16.0, "boss sprite clears health bar")
	var saved_position: Vector2 = boss.position
	var saved_direction: float = boss.move_direction
	var saved_velocity: float = boss.horizontal_velocity
	var saved_movement_time: float = boss.movement_time
	boss.position.x = 0.0
	boss.move_boss(0.0)
	boss_bounds = boss_sprite.global_transform * boss_sprite.get_rect()
	check(boss_bounds.position.x >= 7.0, "boss remains fully visible at left movement bound")
	boss.position.x = 540.0
	boss.move_boss(0.0)
	boss_bounds = boss_sprite.global_transform * boss_sprite.get_rect()
	check(boss_bounds.end.x <= 533.0, "boss remains fully visible at right movement bound")
	boss.position = saved_position
	boss.move_direction = saved_direction
	boss.horizontal_velocity = saved_velocity
	# Exercise many direction reversals with small, deterministic movement steps.
	var reversals := 0
	var previous_velocity: float = boss.horizontal_velocity
	var previous_direction: float = boss.move_direction
	var smooth_motion := true
	var bounded_motion := true
	for step in range(1800):
		boss.move_boss(1.0 / 60.0)
		if absf(boss.horizontal_velocity - previous_velocity) > 4.01:
			smooth_motion = false
		var rect: Rect2 = boss_sprite.global_transform * boss_sprite.get_rect()
		if rect.position.x < 7.0 or rect.end.x > 533.0:
			bounded_motion = false
		if boss.move_direction != previous_direction:
			reversals += 1
		previous_velocity = boss.horizontal_velocity
		previous_direction = boss.move_direction
	check(smooth_motion and reversals >= 2, "boss eases through repeated direction changes without velocity jumps")
	check(bounded_motion, "boss remains visible throughout smooth movement")
	boss.position = saved_position
	boss.move_direction = saved_direction
	boss.horizontal_velocity = saved_velocity
	boss.movement_time = saved_movement_time
	check(hud.boss_panel.visible and hud.boss_bar.max_value == boss.max_health, "boss bar binds to spawned boss")
	boss.take_damage(10)
	await create_timer(0.25).timeout
	check(absf(hud.boss_bar.value - boss.health) < 0.1, "boss bar animates to signaled health")
	check(hud.boss_bar.size.y >= 12 and hud.boss_bar.size.y <= 16, "boss bar is readable without covering the boss")
	check(hud.timer_label.text != "00:00", "HUD timer follows gameplay time")
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
	for section in [[49.0, 4], [62.0, 5], [90.0, 3]]:
		game.music_player.seek(section[0])
		await create_timer(0.15).timeout
		check(boss.song_section == section[1], "music seek reaches attack section %d" % section[1])
	game.music_player.seek(21.0)
	await create_timer(0.15).timeout
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
	var health_before_sweep: int = boss.health
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
	check(is_instance_valid(boss) and boss.health == health_before_sweep - 30, "normal SATURATE deals exactly 30 damage once per target")
	check(not is_instance_valid(target_bullet), "SATURATE sweep clears enemy projectile")
	for code in [KEY_B, KEY_E, KEY_A, KEY_M]:
		key(code, true)
		await process_frame
		key(code, false)
	check(player.unlimited_saturate, "typing BEAM enables unlimited SATURATE")
	await process_frame
	check(hud.saturate_label.text.contains("UNLIMITED"), "HUD distinguishes BEAM from normal availability")
	for use in range(2):
		var health_before_repeat: int = boss.health
		key(KEY_X, true)
		await process_frame
		key(KEY_X, false)
		await create_timer(1.8).timeout
		check(boss.health == health_before_repeat - 30, "BEAM permits repeat SATURATE use %d with 30 damage" % (use + 1))
	for code in [KEY_B, KEY_E, KEY_A, KEY_M]:
		key(code, true)
		await process_frame
		key(code, false)
	check(not player.unlimited_saturate, "typing BEAM again disables unlimited use")
	key(KEY_X, true)
	await process_frame
	key(KEY_X, false)
	var normal_beams := 0
	for child in game.get_children():
		if child.scene_file_path == "res://scenes/rainbow_beam.tscn":
			normal_beams += 1
	check(normal_beams == 0, "disabling BEAM restores normal spent SATURATE limit")
	check(not game.victory_started and not hud.victory_screen.visible, "regular gameplay and nonlethal damage never trigger victory")
	game._on_boss_defeated()
	check(not game.victory_started, "positive boss health rejects accidental victory callback")
	var defeat_count := [0]
	boss.defeated.connect(func(): defeat_count[0] += 1)
	boss.fire_ring(3, 0.0, 0.0, Color.WHITE)
	boss.take_damage(boss.health)
	check(game.victory_started and boss.attacks_stopped and boss.spiral_remaining == 0, "zero boss health starts victory and stops attacks")
	check(is_instance_valid(boss) and not hud.victory_screen.visible, "boss remains for brief defeat animation before victory screen")
	check(game.music_player.playing, "music continues during start of defeat fade")
	boss.take_damage(1)
	game._on_boss_defeated()
	check(defeat_count[0] == 1, "defeat triggers exactly once")
	player.invincible = false
	player.invulnerability_timer = 0.0
	var surviving_health: int = player.health
	player.take_damage(3)
	check(player.health == surviving_health and not paused, "queued lethal collision cannot interrupt victory")
	await process_frame
	await process_frame
	check(get_nodes_in_group("enemy_bullets").is_empty(), "victory clears every enemy projectile safely")
	var ending_position: Vector2 = player.position
	key(KEY_D, true)
	key(KEY_Z, true)
	key(KEY_X, true)
	await create_timer(0.3).timeout
	key(KEY_D, false)
	key(KEY_Z, false)
	key(KEY_X, false)
	check(player.position == ending_position, "victory disables player movement")
	check(game.music_player.playing and game.music_player.volume_db < -1.0, "soundtrack fades instead of abruptly stopping")
	await create_timer(1.0).timeout
	check(not is_instance_valid(boss) and hud.victory_screen.visible and hud.victory_screen.modulate.a == 1.0, "defeat animation ends in fully revealed victory screen")
	check(not hud.boss_panel.visible and not hud.end_screen.visible, "victory hides boss HUD without showing game over")
	check(not game.music_player.playing, "soundtrack stops only after graceful fade")
	check(hud.victory_retry.has_focus(), "victory Retry receives keyboard focus")
	check(Rect2(Vector2.ZERO, Vector2(540, 900)).encloses(hud.victory_retry.get_global_rect()), "victory navigation fits viewport")
	var retry_scene_id := current_scene.get_instance_id()
	hud.victory_retry.pressed.emit()
	hud.victory_retry.pressed.emit()
	check(game.victory_navigation, "victory navigation guards repeated activation")
	while current_scene == null or current_scene.get_instance_id() == retry_scene_id or root.get_node("Session").busy: await process_frame
	game = current_scene.battle
	hud = game.get_node("UI")
	player = game.player
	check(not game.victory_started and player.health == 3 and game.music_player.playing, "victory Retry creates a fresh playable run")
	check(not player.unlimited_saturate and not player.invincible, "victory Retry resets cheats")

	player.invincible = false
	player.take_damage(3)
	await create_timer(0.35).timeout
	check(paused and hud.end_screen.visible, "game-over UI appears while gameplay is paused")
	check(hud.health_label.text.count("●") == 0, "HUD shows depleted health")
	var retry: Button = game.restart_button
	check(retry.visible and retry.has_focus(), "existing Retry button remains accessible while paused")
	game.music_player.stop()
	retry.pressed.emit()
	while root.get_node("Session").busy: await process_frame
	game = current_scene.battle
	hud = game.get_node("UI")
	await process_frame
	check(not paused and not game.game_over, "Retry restarts existing gameplay")
	check(not hud.end_screen.visible and hud.saturate_label.text.contains("READY"), "Retry resets HUD state")
	check(not game.player.unlimited_saturate and not game.player.invincible, "Retry resets both cheats")
	# Reach a second victory to exercise its Main Menu button.
	game.player.invincible = true
	game.music_player.seek(7.0)
	await create_timer(0.2).timeout
	game.boss.health = 30
	game.player.activate_saturate()
	await create_timer(2.7).timeout
	check(game.victory_started and hud.victory_screen.visible, "lethal SATURATE also completes the victory sequence")
	hud.victory_menu.pressed.emit()
	await create_timer(0.65).timeout
	check(current_scene.name == "Mainmenu" and current_scene.menu_container.visible, "victory Main Menu returns to original menu")
	check(current_scene.menu_container.get_node("StartButton").has_focus(), "returned menu restores keyboard navigation")
	current_scene._start_game()
	check(root.get_node("Session").confirmation != null, "new game asks before replacing save")
	root.get_node("Session").confirmation.confirmed.emit()
	await create_timer(0.45).timeout
	check(current_scene.name == "Overworld", "Start works again after victory Main Menu")
	await root.get_node("Session").transition_to("res://scenes/combat_host.tscn")
	game = current_scene.battle

	await create_timer(0.1).timeout
	# Let the audio mixer release the active MP3 playback before shutting down.
	game.music_player.stop()
	current_scene.queue_free()
	await create_timer(0.25).timeout
	print("FUNCTIONAL VALIDATION: ", failures, " failures")
	quit(0 if failures == 0 else 1)
