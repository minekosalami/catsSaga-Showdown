extends SceneTree
var directory := "/tmp/boss2-overhaul-review"
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+text)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): directory = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(directory)
	create_timer(90).timeout.connect(func(): quit(1))
	call_deferred("run")
func snapshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(name+".png")) == OK,"capture "+name)
func run() -> void:
	root.size = Vector2i(1280,720)
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-boss2-overhaul-render.json"
	await session.new_game()
	session.evil_bart_defeated = true
	session.grant_flooded_key()
	session.key_notification_pending = false
	await session.travel("flooded_forest","FromDeep")
	await session.begin_boss2_battle(Vector2(1840,450))
	var battle: Node = current_scene.battle
	battle.player.invincible = true
	battle.set_physics_process(false)
	await create_timer(0.65).timeout
	check(battle.ui.top_margin.size.y < 120,"compact HUD fits above boss")
	for shot in [[0.8,"introduction"],[20.4,"opening"],[38.6,"blue-warning"],[40.4,"blue-active"],[64.1,"ricochet-dialogue"],[70.55,"lasers-slam"],[71.5,"cross-charge"],[80.0,"cross-18rpm"],[89.60,"cross-glass"],[89.80,"shard-fade"],[90.12,"finale"]]:
		battle.timeline.advance(shot[0])
		battle.ui.update(shot[0])
		battle.timeline.boss.apply_clock(shot[0])
		battle.background_material.set_shader_parameter("clock",shot[0])
		battle.background_material.set_shader_parameter("intensity",0.1875 if battle.timeline.phase == 4 else (0.10 if battle.timeline.phase == 2 else 0.02))
		await create_timer(0.07).timeout
		await snapshot(shot[1])
	battle.timeline.clear_hostiles()
	await physics_frame
	battle.timeline.phase = -1
	for cue in [64.0,65.6,67.2,68.8]: battle.timeline.advance(cue)
	battle.ui.update(68.8)
	await create_timer(0.07).timeout
	check(get_nodes_in_group("boss2_ricochets").size() == 28,"all twenty-eight ricochets render within bounded pool")
	await snapshot("ricochet-28")
	var started := Time.get_ticks_usec()
	for frame in range(120): await RenderingServer.frame_post_draw
	print("RICOCHET SOFTWARE RENDER: 28 ricochets, 120 frames, mean wall time ",(Time.get_ticks_usec()-started)/120000.0," ms")
	battle.timeline.clear_hostiles()
	await physics_frame
	battle.timeline.advance(42.0)
	battle.timeline.clear_hostiles()
	await physics_frame
	for i in range(240):
		var bullet: Node = load("res://scenes/boss2/projectile.tscn").instantiate()
		bullet.position = Vector2(35+(i%16)*31,290+(i/16)*28)
		bullet.bullet_color = Color("#FF259C") if i%2 == 0 else Color("#20B9FF")
		bullet.direction = Vector2.DOWN.rotated(i*0.7)
		battle.add_child(bullet)
		bullet.set_physics_process(false)
	check(get_nodes_in_group("boss2_projectiles").size() == 240,"maximum normal projectile budget renders without accumulation")
	started = Time.get_ticks_usec()
	for frame in range(120): await RenderingServer.frame_post_draw
	print("NORMAL SOFTWARE RENDER: 240 enhanced projectiles, 120 frames, mean wall time ",(Time.get_ticks_usec()-started)/120000.0," ms")
	await snapshot("normal-240-stress")
	battle.timeline.clear_hostiles()
	await physics_frame
	battle.timeline.advance(20.4)
	var event := InputEventKey.new()
	event.keycode = KEY_RIGHT
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.keycode = KEY_X
	event.pressed = true
	Input.parse_input_event(event)
	await create_timer(0.18).timeout
	await snapshot("sprint-afterimages")
	for code in [KEY_RIGHT,KEY_X]:
		event = InputEventKey.new()
		event.keycode = code
		event.pressed = false
		Input.parse_input_event(event)
	battle.player.invincible = false
	battle.player.sprint_protection = 0
	battle.player.take_damage(1)
	await snapshot("damage-feedback")
	check(battle.player.health == 2,"rendered damage feedback uses real health")
	await session.main_menu()
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	print("BOSS2 OVERHAUL GRAPHICAL VALIDATION: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
