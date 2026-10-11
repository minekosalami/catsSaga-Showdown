extends SceneTree
var directory := "/tmp/bart-overhaul-review"
var failures := 0
var checks := 0
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			directory = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(directory)
	create_timer(45).timeout.connect(func(): quit(1))
	call_deferred("run")
func snapshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(directory.path_join(name + ".png"))
	checks += 1
	if error != OK:
		failures += 1
	print("PASS: capture " + name if error == OK else "FAIL: capture " + name)
func clear_bullets() -> void:
	for bullet in get_nodes_in_group("enemy_bullets"):
		bullet.queue_free()
	await physics_frame
func run() -> void:
	root.size = Vector2i(1280,720)
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-bart-overhaul-render.json"
	await session.new_game()
	await session.travel("bart_area", "FromDeep")
	await session.begin_battle(Vector2(1000,520))
	var game: Node = current_scene.battle
	game.player.invincible = true
	game.player.set_physics_process(false)
	game.music_player.seek(7)
	await create_timer(0.6).timeout
	var boss: Node = game.boss
	boss.set_process(false)
	await clear_bullets()
	boss.fire_gapped_ring(14,145,0,Color("#FF55BB"))
	await create_timer(1.2).timeout
	await snapshot("arrival-ring-300hp")
	await clear_bullets()
	game.music_player.seek(34.4)
	await create_timer(0.3).timeout
	boss.fire_flower(20,170,5,0,Color("#559BFF"))
	await create_timer(1.1).timeout
	await snapshot("refraction-flower")
	await clear_bullets()
	game.music_player.seek(62)
	await create_timer(0.1).timeout
	boss.start_spiral(26,0.29,true,1,0.16)
	for i in range(26):
		boss.fire_spiral_step()
		await create_timer(0.025).timeout
	await create_timer(0.5).timeout
	await snapshot("final-climax-spirals")
	await clear_bullets()
	game.music_player.seek(90)
	await create_timer(0.25).timeout
	await snapshot("showdown-transition")
	boss.fire_flower(24,185,6,0,Color("#55E8FF"))
	await create_timer(1.1).timeout
	await snapshot("showdown-flower")
	await clear_bullets()
	game.music_player.seek(116.1)
	await create_timer(0.3).timeout
	boss.fire_wave(15,215,0)
	await create_timer(0.8).timeout
	await snapshot("final-sequence-wave")
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame
	await snapshot("focus-hitbox")
	event = InputEventKey.new()
	event.keycode = KEY_SHIFT
	Input.parse_input_event(event)
	await clear_bullets()
	game.music_player.seek(90)
	game.player.activate_saturate()
	await create_timer(0.15).timeout
	await snapshot("saturate-charge")
	await create_timer(0.65).timeout
	await snapshot("saturate-white-core")
	await create_timer(0.65).timeout
	await snapshot("saturate-impact")
	boss.take_damage(boss.health)
	await create_timer(0.85).timeout
	await snapshot("victory-300hp-boss")
	game.music_player.stop()
	game.music_player.stream = null
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	print("BART GRAPHICAL VALIDATION: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
