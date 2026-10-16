extends SceneTree

var failures := 0
var checks := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func clear_bullets() -> void:
	for bullet in get_nodes_in_group("enemy_bullets"):
		bullet.queue_free()
	await physics_frame
	await physics_frame

func _initialize() -> void:
	create_timer(40).timeout.connect(func(): quit(1))
	call_deferred("run")

func run() -> void:
	var music: Node = root.get_node("Music")
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-music-hitbox.json"
	change_scene_to_file("res://scenes/main_menu.tscn")
	await create_timer(0.4).timeout
	check(music.current_theme == "menu" and music.player.playing, "main menu automatically plays located Menu - 001 WAV")
	check(music.player.stream is AudioStreamWAV and music.player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and music.player.stream.loop_end > 0, "menu uses native WAV frame looping")
	music.player.seek(music.player.stream.get_length() - 0.15)
	await create_timer(0.5).timeout
	check(music.player.playing and music.player.get_playback_position() < 1, "menu playback wraps at its real end without stopping")
	check(get_nodes_in_group("background_music").size() == 1, "one persistent background player prevents duplicate themes")
	await session.new_game()
	await create_timer(1.0).timeout
	check(music.current_theme == "overworld" and music.player.playing and music.player.stream is AudioStreamMP3 and music.player.stream.loop, "forest automatically plays and loops located Overworld - 002 MP3")
	var stream: AudioStream = music.player.stream
	var before: float = music.player.get_playback_position()
	await session.travel("deep_forest", "FromEntrance")
	check(music.player.stream == stream and music.player.get_playback_position() > before, "forest area transition retains same stream and advancing playback position")
	before = music.player.get_playback_position()
	await session.travel("bart_area", "FromDeep")
	check(music.player.stream == stream and music.player.get_playback_position() > before, "Bart area transition continues overworld track")
	music.player.seek(stream.get_length() - 0.15)
	await create_timer(0.5).timeout
	check(music.player.playing and music.player.get_playback_position() < 1, "overworld playback loops across its real end")
	session.begin_battle(Vector2(1000,520))
	await create_timer(0.2).timeout
	check(music.player.volume_db < music.gain_for_path(music.THEMES.overworld), "overworld theme fades during battle entrance")
	if session.busy:
		await session.transition_finished
	var game: Node = current_scene.battle
	check(not music.player.playing and music.player.stream == null and game.music_player.playing, "battle has its original soundtrack with background theme stopped")
	check(current_scene.arena.size == Vector2i(540,900), "boss arena retains internal coordinate resolution")
	game.music_player.seek(7)
	await create_timer(0.08).timeout
	check(game.boss_spawned and absf(game.boss.elapsed - game.music_player.get_playback_position()) < 0.15, "boss clock follows original battle song after spawning")
	game.set_process(false)
	game.boss.set_process(false)
	var player: Area2D = game.player
	player.position = Vector2(270,650)
	player.velocity = Vector2.ZERO
	check(not player.invincible and player.health == 3 and player.get_node("CollisionShape2D").shape.radius == 7.5, "fresh battle starts with active 7.5-pixel damage hitbox and CATA disabled")
	check(player.get_node("CollisionShape2D").position.is_equal_approx(player.get_node("Sprite2D").position), "damage circle follows visible sprite center rather than displaced root")
	check(not player.get_node("HitboxDebug").visible, "developer hitbox overlay is hidden in normal gameplay")
	if OS.is_debug_build():
		key(KEY_F3, true)
		await process_frame
		key(KEY_F3, false)
		check(player.get_node("HitboxDebug").visible, "debug builds can toggle optional hitbox visualization with F3")
		key(KEY_F3, true)
		key(KEY_F3, false)
	await clear_bullets()
	var original := player.position
	var bullet: Area2D = load("res://scenes/enemybullet.tscn").instantiate()
	bullet.speed = 0
	game.add_child(bullet)
	bullet.position = player.get_node("CollisionShape2D").position + original + Vector2(48, 0)
	key(KEY_D, true)
	await create_timer(0.25).timeout
	key(KEY_D, false)
	check(player.position.x > original.x + 30 and player.health == 2, "moving player consistently takes damage on crossing visible enemy projectile")
	check(player.invulnerability_timer > 0, "moving collision grants normal damage invulnerability")
	player.position = original
	player.velocity = Vector2.ZERO
	await clear_bullets()
	player.invulnerability_timer = 0
	bullet = load("res://scenes/enemybullet.tscn").instantiate()
	bullet.speed = 0
	game.add_child(bullet)
	bullet.position = player.get_node("CollisionShape2D").position + original + Vector2(48, 25)
	key(KEY_D, true)
	await create_timer(0.25).timeout
	key(KEY_D, false)
	check(player.health == 2, "moving player is not damaged by a visible near miss outside both circles")
	player.position = original
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	for section in [[7.0,1],[21.0,2],[49.0,4],[63.0,5],[91.0,3]]:
		await clear_bullets()
		player.health = 3
		player.invulnerability_timer = 0
		game.boss.elapsed = section[0]
		game.boss.song_section = section[1]
		game.boss.attack_index = 1
		game.boss.position = player.position + player.get_node("CollisionShape2D").position + Vector2(0,-60)
		game.boss.attack()
		check(get_nodes_in_group("enemy_bullets").all(func(projectile): return projectile.collision_mask == 2 and projectile.get_node("CollisionShape2D").shape.radius == 6.5), "song section " + str(section[1]) + " emits player-targeted bullets with matching visible cores")
		await create_timer(0.5).timeout
		check(player.health == 2, "song section " + str(section[1]) + " aimed pattern damages non-invincible player")
	for offset in [Vector2(-60,-60), Vector2(60,-60), Vector2(-60,0), Vector2(60,0)]:
		await clear_bullets()
		player.health = 3
		player.invulnerability_timer = 0
		game.boss.position = player.get_node("CollisionShape2D").global_position - game.global_position + offset
		game.boss.fire_fan(1,0,150,Color.WHITE)
		await create_timer(0.7).timeout
		check(player.health == 2, "single aimed bullet targets visible damage center from direction " + str(offset))
	game.boss.position = player.get_node("CollisionShape2D").global_position - game.global_position + Vector2(0,-60)
	await clear_bullets()
	player.health = 3
	player.invulnerability_timer = 0
	game.boss.fire_ring(12,150,0,Color.WHITE)
	await create_timer(0.5).timeout
	check(player.health == 2, "ring projectiles use same reliable damage detection")
	await clear_bullets()
	player.health = 3
	player.invulnerability_timer = 0
	game.boss.spiral_angle = PI/2
	game.boss.spiral_remaining = 1
	game.boss.fire_spiral_step()
	await create_timer(0.5).timeout
	check(player.health == 2, "spiral projectiles use same reliable damage detection")
	await clear_bullets()
	game.boss.take_damage(game.boss.health)
	await create_timer(0.8).timeout
	await session.return_to_forest()
	await create_timer(0.3).timeout
	check(music.current_theme == "overworld" and music.player.playing and get_nodes_in_group("combat_music").is_empty(), "victory return restores overworld theme without leftover boss music")
	await session.main_menu()
	check(music.current_theme == "menu" and music.player.playing and get_nodes_in_group("background_music").size() == 1, "returning to menu switches cleanly to a single menu theme")
	music.play_theme("")
	await create_timer(0.2).timeout
	print("MUSIC/HITBOX VALIDATION: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
