extends SceneTree
var failures := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func clear_bullets() -> void:
	for bullet in get_nodes_in_group("enemy_bullets"):
		bullet.queue_free()
	await physics_frame
	await physics_frame

func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	call_deferred("run")

func run() -> void:
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-bart-overhaul.json"
	await session.new_game()
	await session.travel("bart_area", "FromDeep")
	await session.begin_battle(Vector2(1000,520))
	var game: Node = current_scene.battle
	game.music_player.seek(7)
	await create_timer(0.1).timeout
	var boss: Node = game.boss
	var hud: Node = game.ui
	var presentation: Node = game.presentation
	check(boss.max_health == 300 and boss.health == 300 and hud.boss_bar.max_value == 300 and hud.boss_value.text == "300 / 300", "new fight starts exactly 300/300 with matching HUD")
	check(not game.player.invincible and not game.player.unlimited_saturate, "CATA and BEAM are disabled on new fight")
	check(boss.DROP_TIME == 6.85 and boss.SECOND_INSTRUMENT_TIME == 20.57 and boss.CALM_TIME == 48.0 and boss.FINAL_CLIMAX_TIME == 61.71 and boss.SHOWDOWN_TIME == 89.14 and boss.SONG_END_TIME == 123, "all authoritative attack timestamps remain exact")
	for cue in [[21.0,2,2],[34.4,2,3],[49.0,4,4],[62.0,5,5],[90.0,3,6],[116.1,3,7]]:
		game.music_player.seek(cue[0])
		await create_timer(0.08).timeout
		check(boss.song_section == cue[1] and presentation.cue_index == cue[2] and absf(boss.elapsed - game.music_player.get_playback_position()) < 0.15, "clock, attacks and presentation align at " + str(cue[0]) + "s")
		check(game.music_player.playing and not paused, "phase presentation never pauses soundtrack")
	check(hud.phase_label.text == "FinalSequence()", "116-second final sequence is presentation inside original Showdown phase")
	game.music_player.seek(90)
	await create_timer(0.06).timeout
	check(hud.phase_label.text == "Showdown()", "Showdown() dramatic title uses exact spelling")
	game.set_process(false)
	boss.set_process(false)
	await clear_bullets()
	game.player.position = Vector2(270,780)
	game.player.velocity = Vector2.ZERO
	var marker: Node2D = game.player.get_node("HitboxDebug")
	key(KEY_SHIFT, true)
	key(KEY_D, true)
	await create_timer(0.1).timeout
	check(marker.visible and marker.global_position.is_equal_approx(game.player.get_node("CollisionShape2D").global_position) and marker.display_radius == game.player.get_node("CollisionShape2D").shape.radius, "Shift marker exactly follows real damage circle")
	check(game.player.velocity.length() <= game.player.focus_speed + 0.1 and game.player.velocity.length() > 0, "Shift retains existing focus movement speed")
	key(KEY_D, false)
	key(KEY_SHIFT, false)
	await create_timer(0.12).timeout
	check(not marker.visible, "focus marker hides immediately after releasing Shift")
	game.player.set_physics_process(false)
	var player_point: Vector2 = game.player.get_node("CollisionShape2D").global_position
	var boss_point: Vector2 = boss.get_node("CollisionShape2D").global_position
	game.shake_time = 0.2
	game.shake_strength = 8
	game._update_screen_shake(0.01)
	presentation.update_clock(90)
	check(game.position == game.original_position and game.player.get_node("CollisionShape2D").global_position == player_point and boss.get_node("CollisionShape2D").global_position == boss_point, "shake and distortion leave player/boss collision coordinates unchanged")
	presentation.effect_intensity = 0
	presentation.shake_intensity = 0
	presentation.update_clock(90)
	presentation.apply_shake(Vector2(4,4))
	check(presentation.shader.get_shader_parameter("intensity") == 0 and presentation.background.position == presentation.background_origin, "Inspector intensity controls can disable distortion and scenery shake")
	presentation.effect_intensity = 0.45
	for style in range(4):
		var bullet: Node = load("res://scenes/enemybullet.tscn").instantiate()
		bullet.visual_style = style
		bullet.speed = 0
		bullet.bullet_color = Color("#55E8FF")
		game.add_child(bullet)
		bullet.position = Vector2(30,400)
		check(bullet.body_radius == bullet.RADII[style] and bullet.get_node("CollisionShape2D").shape.radius == bullet.body_radius and bullet.get_child_count() == 1, "bullet style " + str(style) + " has exact body/collider radius and no per-bullet visual nodes")
		bullet.queue_free()
	await clear_bullets()
	boss.elapsed = 90
	boss.position = Vector2(270,240)
	boss.fire_gapped_ring(24,180,0,Color.WHITE)
	var gap_ok := true
	var gap: float = PI/2 + sin(boss.elapsed * 0.2) * 0.35
	for bullet in get_nodes_in_group("enemy_bullets"):
		gap_ok = gap_ok and absf(wrapf(bullet.direction.angle() - gap, -PI, PI)) > 0.30
	check(gap_ok and get_nodes_in_group("enemy_bullets").size() < 24, "gapped ring keeps explicit navigable angular corridor")
	await clear_bullets()
	boss.fire_flower(24,185,6,0,Color("#FF596F"))
	var speeds := {}
	var types := {}
	for bullet in get_nodes_in_group("enemy_bullets"):
		speeds[roundi(bullet.speed)] = true
		types[bullet.visual_style] = true
	check(get_nodes_in_group("enemy_bullets").size() == 24 and speeds.size() > 1 and types.has(2) and types.has(3), "flower uses radial petals, varying speeds and heavy/diamond identities")
	await clear_bullets()
	boss.fire_wave(15,210,0)
	var wave_ok := true
	for bullet in get_nodes_in_group("enemy_bullets"):
		wave_ok = wave_ok and absf(bullet.direction.angle() - PI/2) >= 0.14 and bullet.visual_style == 1
	check(wave_ok, "geometric wave preserves center escape gap with distinct fast projectiles")
	await clear_bullets()
	var curved: Node = load("res://scenes/enemybullet.tscn").instantiate()
	curved.speed = 0
	curved.angular_velocity = 0.16
	game.add_child(curved)
	curved.position = Vector2(30,400)
	curved.set_physics_process(false)
	for i in range(120):
		curved._physics_process(1.0/60)
	check(absf(curved.direction.angle() - PI/2 - 0.16 * curved.turn_duration) < 0.001, "curved bullet stops turning after bounded duration")
	curved.queue_free()
	await clear_bullets()
	var start := Time.get_ticks_usec()
	for i in range(400):
		boss.fire_bullet(Vector2.DOWN,150,Color.WHITE)
	check(get_nodes_in_group("enemy_bullets").size() == 320, "projectile budget caps dense emission at 320")
	print("Dense emission CPU microseconds: ", Time.get_ticks_usec() - start)
	await clear_bullets()
	for i in range(40):
		preload("res://scripts/ui/battle_burst.gd").spawn(game, Vector2(30,400), Color.WHITE)
	check(get_nodes_in_group("battle_bursts").size() <= 24, "shared particle bursts obey 24-effect budget")
	await create_timer(0.45).timeout
	check(get_nodes_in_group("battle_bursts").is_empty(), "transient effects clean themselves up")
	game.music_player.seek(7)
	boss.elapsed = 7
	var shot: Node = load("res://scenes/bullet.tscn").instantiate()
	game.add_child(shot)
	shot.position = boss.position
	for i in range(4):
		await physics_frame
	await create_timer(0.2).timeout
	check(boss.health == 299 and hud.boss_value.text == "299 / 300" and absf(hud.boss_bar.value - 299) < 0.1, "real player shot subtracts one HP and updates health bar")
	game.player.activate_saturate()
	await create_timer(1.65).timeout
	check(boss.health == 269 and game.player.saturate_used and absf(hud.boss_bar.value - 269) < 0.1, "real SATURATE sweep subtracts exactly 30 once and updates bar")
	game.player.activate_saturate()
	check(game.get_children().filter(func(child): return child.scene_file_path == "res://scenes/rainbow_beam.tscn").is_empty(), "normal SATURATE stays once per battle")
	boss.take_damage(59)
	check(boss.health == 210 and boss.phase == 2 and boss.move_speed == 90, "300 HP configuration preserves phase-two threshold at 70 percent")
	boss.take_damage(105)
	check(boss.health == 105 and boss.phase == 3 and boss.move_speed == 110, "phase-three threshold remains 35 percent of maximum")
	key(KEY_SHIFT, true)
	await process_frame
	await process_frame
	var victories := [0]
	boss.defeated.connect(func(): victories[0] += 1)
	boss.take_damage(9999)
	boss.take_damage(9999)
	check(boss.health == 0 and victories[0] == 1 and game.victory_started, "overkill clamps to zero and triggers exactly one early victory")
	check(not marker.visible, "victory immediately hides focus marker before locking player")
	key(KEY_SHIFT, false)
	await create_timer(0.85).timeout
	check(hud.victory_screen.visible, "300 HP boss completes existing defeat and victory screen")
	var retry_scene_id := current_scene.get_instance_id()
	hud.victory_retry.pressed.emit()
	while current_scene == null or current_scene.get_instance_id() == retry_scene_id or root.get_node("Session").busy: await process_frame
	game = current_scene.battle
	game.music_player.seek(7)
	await create_timer(0.1).timeout
	boss = game.boss
	check(boss.health == 300 and boss.max_health == 300 and game.player.health == 3, "Retry starts fresh boss at exactly 300/300")
	game.set_process(false)
	boss.elapsed = 123
	boss._process(0.01)
	var count := get_nodes_in_group("enemy_bullets").size()
	boss.attack()
	check(boss.attacks_stopped and get_nodes_in_group("enemy_bullets").size() == count and not game.victory_started and boss.health == 300, "123-second cutoff stops attacks without automatically awarding victory")
	presentation = game.presentation
	presentation.update_clock(123)
	check(presentation.cue_index == 8 and presentation.shader.get_shader_parameter("intensity") == 0, "123-second ending settles scenery without affecting boss health")
	boss.take_damage(1)
	check(boss.health == 299, "boss remains damageable after scripted attack cutoff")
	boss.take_damage(9999)
	await create_timer(0.85).timeout
	await session.return_to_forest()
	await process_frame
	check(session.evil_bart_defeated and current_scene.dialogue.active and current_scene.dialogue.lines[0].text == "You were more powerful than I thought... You'll do great out there!", "victory return preserves one-time post-battle dialogue and progression")
	while current_scene.dialogue.active:
		current_scene.dialogue.advance()
	check(session.story_flags.get("bart_victory_dialogue_seen",false), "completed post-victory dialogue still marks saved progression")
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	print("BART OVERHAUL VALIDATION: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
