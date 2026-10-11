extends SceneTree
var directory := "/tmp/battle-visuals-review"
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ")+message)
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			directory = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(directory)
	create_timer(55).timeout.connect(func(): quit(1))
	call_deferred("run")
func snapshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(name+".png")) == OK,"capture "+name)
func run() -> void:
	root.size = Vector2i(1280,720)
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-visual-density.json"
	await session.new_game()
	session.evil_bart_defeated = true
	session.grant_flooded_key()
	await session.travel("flooded_forest","FromDeep")
	await session.begin_boss2_battle(Vector2(1840,450))
	var battle: Node = current_scene.battle
	battle.player.invincible = true
	battle.set_physics_process(false)
	battle.timeline.advance(70.4)
	battle.ui.update(70.6)
	battle.ui.phase_transition.update_clock(70.6)
	battle.timeline.boss.apply_clock(70.6)
	await create_timer(0.2).timeout
	await snapshot("convergence-transition")
	battle.timeline.clear_hostiles()
	await physics_frame
	battle.timeline.advance(85)
	battle.timeline.clear_hostiles()
	await physics_frame
	battle.ui.update(85)
	for i in range(240):
		var bullet: Node = load("res://scenes/enemybullet.tscn").instantiate()
		bullet.visual_style = i%4
		bullet.bullet_color = [Color("#A694FF"),Color("#6DDEFF"),Color("#F5B7FF"),Color("#FFD484")][i%4]
		battle.add_child(bullet)
		bullet.position = Vector2(36+(i%16)*31,300+(i/16)*29)
		bullet.set_physics_process(false)
	check(get_nodes_in_group("enemy_bullets").size() == 240,"240 projectiles render without extra visual nodes")
	var start := Time.get_ticks_usec()
	for i in range(120):
		await RenderingServer.frame_post_draw
	print("SOFTWARE RENDER: 240 projectiles, 120 frames, mean frame wall time ",(Time.get_ticks_usec()-start)/120000.0," ms (not a hardware benchmark)")
	await snapshot("projectile-style-density")
	check(battle.player.health == 3,"render sampling does not alter player health")
	await session.main_menu()
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	print("BATTLE VISUAL GRAPHICAL VALIDATION: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
