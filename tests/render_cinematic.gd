extends SceneTree
var directory := "/tmp/cinematic-review"
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+message)
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): directory = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(directory)
	create_timer(120).timeout.connect(func(): quit(1))
	call_deferred("run")
func snapshot(battle: Node, name: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(name+"-wide.png")) == OK,"capture "+name+" wide")
	check(current_scene.arena.get_texture().get_image().save_png(directory.path_join(name+".png")) == OK,"capture "+name+" internal 540x900")
	check(current_scene.arena.size == Vector2i(540,900),"internal resolution stays 540x900")
	check(battle.ui.get_child(0).size == Vector2(540,900),"HUD aligns to internal arena")
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func freeze(battle: Node, clock: float) -> void:
	battle.set_process(false)
	battle.set_physics_process(false)
	battle.elapsed_time = clock
	battle.get_node("CinematicArena").update_clock(clock)
	if "presentation" in battle: battle.presentation.update_clock(clock)
	else: battle.ui.update(clock)
func clear_bullets() -> void:
	for bullet in get_nodes_in_group("enemy_bullets"): bullet.queue_free()
	await physics_frame
func run() -> void:
	root.size = Vector2i(1280,720)
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-render-cinematic.json"
	await session.new_game()
	await session.travel("bart_area","FromDeep")
	await session.begin_battle(Vector2(1000,520))
	var game: Node = current_scene.battle
	game.player.invincible = true
	freeze(game,0.7)
	await create_timer(0.08).timeout
	check(game.get_node("CinematicArena").title.label.text == "Showdown: Evil Bart","Bart introduction exact text")
	await snapshot(game,"bart-introduction")
	game.elapsed_time = 7.2
	game._update_boss()
	game.boss.set_process(false)
	await create_timer(0.55).timeout
	freeze(game,8.8)
	await clear_bullets()
	game.boss.fire_gapped_ring(18,145,0,Color("#FF55BB"))
	await create_timer(1).timeout
	await snapshot(game,"bart-forest")
	await clear_bullets()
	freeze(game,37)
	game.boss.fire_flower(24,170,5,0,Color("#55A4FF"))
	await create_timer(0.8).timeout
	await snapshot(game,"bart-distortion")
	await clear_bullets()
	freeze(game,92)
	game.boss.fire_flower(24,185,6,0,Color("#55E8FF"))
	await create_timer(0.8).timeout
	key(KEY_SHIFT,true)
	await create_timer(0.16).timeout
	await snapshot(game,"bart-showdown")
	key(KEY_SHIFT,false)
	await clear_bullets()
	game.boss.take_damage(300)
	await create_timer(0.85).timeout
	await snapshot(game,"bart-victory")
	await session.new_game()
	session.evil_bart_defeated = true
	session.grant_flooded_key()
	await session.travel("flooded_forest","FromDeep")
	await session.begin_boss2_battle(Vector2(1840,450))
	game = current_scene.battle
	game.player.invincible = true
	freeze(game,0.7)
	await create_timer(0.65).timeout
	check(game.get_node("CinematicArena").title.label.text == "Showdown: Doppelcat","Doppelcat introduction exact text")
	check(game.ui.top_margin.size.y < 120,"survival HUD remains compact above the boss")
	await snapshot(game,"doppelcat-introduction")
	for shot in [[22.0,"doppelcat-flooded"],[38.8,"doppelcat-warning"],[42.0,"doppelcat-lasers"],[70.55,"doppelcat-cross-warning"],[80.0,"doppelcat-cross"],[92.0,"doppelcat-showdown"]]:
		freeze(game,shot[0])
		game.timeline.advance(shot[0])
		game.ui.update(shot[0])
		await create_timer(0.15).timeout
		await snapshot(game,shot[1])
	check(game.timeline.cross.maximum_rpm == 18,"cinematic lasers preserve 18 RPM")
	await clear_bullets()
	freeze(game,92)
	for i in range(240):
		var bullet: Node = load("res://scenes/boss2/projectile.tscn").instantiate()
		bullet.position = Vector2(38+(i%16)*30,310+(i/16)*28)
		bullet.bullet_color = Color("#FF259C") if i%2 else Color("#20B9FF")
		bullet.direction = Vector2.DOWN.rotated(i*0.7)
		game.add_child(bullet)
		bullet.set_physics_process(false)
	var began := Time.get_ticks_usec()
	for i in range(120): await RenderingServer.frame_post_draw
	print("CINEMATIC SOFTWARE RENDER: 240 bullets/36 motes, 120 frames, mean wall ms ",(Time.get_ticks_usec()-began)/120000.0," (not a hardware benchmark)")
	await snapshot(game,"doppelcat-density")
	check(get_nodes_in_group("boss2_projectiles").size() == 240,"dense rendering does not create extra projectiles")
	await clear_bullets()
	game.elapsed_time = game.end_time
	game.finish_survival()
	await create_timer(0.45).timeout
	await snapshot(game,"doppelcat-victory")
	await session.begin_boss2_battle(Vector2(1840,450))
	# Start Retry directly; repeat encounter progression guards remain unchanged.
	current_scene.retry()
	while session.busy: await process_frame
	game = current_scene.battle
	game.player.invincible = false
	game.player.take_damage(3)
	await create_timer(0.45).timeout
	await snapshot(game,"doppelcat-defeat")
	await session.main_menu()
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	print("CINEMATIC GRAPHICAL VALIDATION: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
