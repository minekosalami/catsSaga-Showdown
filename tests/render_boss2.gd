extends SceneTree
var directory := "/tmp/boss2-review"
var checks := 0
var failures := 0
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			directory = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(directory)
	create_timer(55).timeout.connect(func(): quit(1))
	call_deferred("run")
func snapshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(directory.path_join(name+".png"))
	checks += 1
	if error != OK:
		failures += 1
	print(("PASS: capture " if error == OK else "FAIL: capture ")+name)
func run() -> void:
	root.size = Vector2i(1280,720)
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-boss2-render.json"
	await session.new_game()
	session.evil_bart_defeated = true
	session.grant_flooded_key()
	await session.travel("flooded_forest","FromDeep")
	var world: Node = current_scene
	var camera: Camera2D = world.player.get_node("Camera2D")
	camera.zoom = Vector2.ONE * 0.43
	world.player.position = Vector2(1024,768)
	camera.reset_smoothing()
	await create_timer(0.2).timeout
	await snapshot("flooded-forest-overview")
	camera.zoom = Vector2.ONE
	world.player.position = Vector2(1840,460)
	camera.reset_smoothing()
	await create_timer(0.2).timeout
	await snapshot("boss2-clearing")
	await session.begin_boss2_battle(world.player.position)
	var battle: Node = current_scene.battle
	battle.player.invincible = true
	battle.set_physics_process(false)
	await snapshot("survival-introduction")
	for cue in [[18.0,"opening"],[38.4,"laser-warning"],[43.0,"laser-assault"],[64.0,"ricochet"],[70.4,"cross-warning"],[85.0,"cross-max-speed"],[90.0,"finale"]]:
		battle.timeline.clear_hostiles()
		await physics_frame
		battle.music_player.seek(cue[0])
		battle.timeline.advance(cue[0])
		battle.ui.update(cue[0])
		if cue[0] not in [64.0,38.4,70.4]:
			for i in range(3):
				battle.timeline.attack(i)
		await create_timer(0.45).timeout
		await snapshot(cue[1])
	battle.elapsed_time = battle.end_time
	battle.finish_survival()
	await create_timer(0.5).timeout
	await snapshot("survival-victory")
	battle.music_player.stop()
	battle.music_player.stream = null
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	print("BOSS2 GRAPHICAL VALIDATION: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
