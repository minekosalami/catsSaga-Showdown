extends SceneTree

var directory := "/tmp/region-update-review"
var failures := 0
var checks := 0
var session: Node

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): directory = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(directory)
	create_timer(80).timeout.connect(func(): quit(1))
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+message)

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(label+".png")) == OK,"capture "+label)

func press(code: int) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame

func acknowledge() -> void:
	if not current_scene.dialogue.is_revealed(): await press(KEY_Z)
	await press(KEY_Z)

func run() -> void:
	root.size = Vector2i(1280,720)
	session = root.get_node("Session")
	session.saves.save_path = "user://validation-region-render.json"
	await session.new_game()
	session.evil_bart_defeated = true
	session.grant_flooded_key()
	session.key_notification_pending = false
	await session.travel("flooded_forest","FromDeep")
	var world: Node = current_scene
	world.player.position = Vector2(1840,450)
	world.player.get_node("Camera2D").reset_smoothing()
	await create_timer(0.1).timeout
	await press(KEY_Z)
	await press(KEY_Z)
	await capture("boss2-opening")
	await press(KEY_Z)
	check(world.dialogue.choices.size() == 2,"graphical Z displays both exact choices")
	await capture("boss2-choices")
	await press(KEY_Z)
	await press(KEY_Z)
	await capture("boss2-apology")
	await acknowledge()
	check(not world.dialogue.active and not session.busy,"graphical apology returns to exploration")
	await press(KEY_Z)
	await acknowledge()
	await press(KEY_DOWN)
	await press(KEY_Z)
	while session.busy: await process_frame
	check(current_scene.has_method("record_victory"),"graphical challenge enters existing battle")
	var battle: Node = current_scene.battle
	battle.elapsed_time = battle.end_time
	battle.finish_survival()
	await create_timer(0.85).timeout
	await current_scene.return_to_forest()
	while session.busy: await process_frame
	world = current_scene
	await press(KEY_Z)
	await capture("boss2-victory-dialogue")
	await acknowledge()
	await press(KEY_Z)
	await press(KEY_Z)
	await capture("boss2-repeat-dialogue")
	await acknowledge()
	world.player.position = Vector2(1840,480)
	await process_frame
	await capture("boss2-green-minimap")
	await press(KEY_M)
	await capture("boss2-green-map")
	await press(KEY_M)
	await session.travel("entrance","Start")
	world = current_scene
	var rocks: TileMapLayer = world.map.get_node("GFXBoulders")
	var center := Vector2.ZERO
	for cell in rocks.get_used_cells():
		var point: Vector2 = rocks.to_global(rocks.map_to_local(cell))
		if point.x > 640 and point.y > 360 and point.x < world.map.map_size.x-640 and point.y < world.map.map_size.y-360:
			center = point
			break
	world.player.position = center+Vector2(100,70)
	world.player.get_node("Camera2D").reset_smoothing()
	await create_timer(0.1).timeout
	await capture("natural-rock-cluster")
	world.player.position = world.map.get_node("Portals/Exit0").position
	while not session.busy: await physics_frame
	await create_timer(0.15).timeout
	await capture("boundary-fade")
	while session.busy: await process_frame
	await capture("deep-boundary-arrival")
	check(session.area_id == "deep_forest","graphical automatic boundary reaches paired destination")
	await press(KEY_M)
	await capture("boundary-map-fog")
	await press(KEY_M)
	session.map_reveal_cheat = true
	await press(KEY_M)
	world = current_scene
	world.map_ui.full_map.center_world = Vector2(260,186)
	world.map_ui.full_map.zoom = 1.45
	world.map_ui.target_zoom = 1.45
	await process_frame
	await capture("connected-world-map")
	await press(KEY_M)
	await session.main_menu()
	current_scene.queue_free()
	await process_frame
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(session.saves.save_path+suffix)
	print("REGION RENDER VALIDATION: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
