extends SceneTree
var directory := "/tmp/cross-laser-review"
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ")+text)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			directory = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(directory)
	create_timer(90).timeout.connect(func(): quit(1))
	call_deferred("run")
func snapshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(name+".png")) == OK,"capture "+name)
func run() -> void:
	root.size = Vector2i(1280,720)
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-cross-render.json"
	await session.new_game()
	session.evil_bart_defeated = true
	session.grant_flooded_key()
	session.key_notification_pending = false # Suppress instant-travel review toast only.
	await session.travel("flooded_forest","FromDeep")
	await session.begin_boss2_battle(Vector2(1840,450))
	var battle: Node = current_scene.battle
	battle.player.invincible = true
	battle.set_physics_process(false)
	await create_timer(0.65).timeout # Finish original entrance fade before synthetic seeking.
	for shot in [[70.60,"now-die"],[79.40,"cross-warning-blue-convergence"],[80.70,"cross-charging"],[81.61,"cross-activation"],[84.3,"cross-rotation"],[89.12,"cross-cracks"],[89.24,"cross-shatter"],[89.43,"cross-shard-fade"],[89.60,"clean-finale"]]:
		battle.timeline.clear_hostiles()
		await physics_frame
		battle.timeline.advance(shot[0])
		battle.ui.update(shot[0])
		battle.timeline.boss.apply_clock(shot[0])
		if shot[0] == 70.60:
			battle.ui.phase_transition.present("NOW DIE!",Color("#FF4766"),70.4,true)
			battle.ui.phase_transition.update_clock(70.6)
		await create_timer(0.08).timeout
		await snapshot(shot[1])
	# A dense synthetic mix tests rendering, not attack balance or dodgeability.
	battle.timeline.clear_hostiles()
	await physics_frame
	for i in range(240):
		var bullet: Node = load("res://scenes/enemybullet.tscn").instantiate()
		bullet.visual_style = i%4
		bullet.bullet_color = [Color("#A694FF"),Color("#6DDEFF"),Color("#F5B7FF"),Color("#FFD484")][i%4]
		battle.add_child(bullet)
		bullet.position = Vector2(36+(i%16)*31,300+(i/16)*29)
		bullet.set_physics_process(false)
	var started := Time.get_ticks_usec()
	for i in range(120):
		var clock := 82.0+i/120.0
		battle.timeline.cross.sample(clock)
		battle.ui.update(clock)
		await RenderingServer.frame_post_draw
	print("CROSS DENSITY SOFTWARE RENDER: 240 projectiles + cross, 120 frames, mean wall time ",(Time.get_ticks_usec()-started)/120000.0," ms")
	check(get_nodes_in_group("enemy_bullets").size() == 240,"dense cross sampling keeps all 240 projectiles")
	await snapshot("cross-dense-bullets")
	check(battle.player.health == 3,"dense visual sampling preserves test player health")
	await session.main_menu()
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	print("CROSS GRAPHICAL VALIDATION: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
