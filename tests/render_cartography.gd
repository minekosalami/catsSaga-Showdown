extends SceneTree

var directory := "/tmp/cartography-review"
var failures := 0
var session: Node

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): directory = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(directory)
	create_timer(65).timeout.connect(func(): quit(1))
	call_deferred("run")

func check(ok: bool, message: String) -> void:
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

func run() -> void:
	root.size = Vector2i(1280,720)
	session = root.get_node("Session")
	session.saves.save_path = "user://validation-cartography-render.json"
	await session.new_game()
	await create_timer(0.15).timeout
	var world: Node = current_scene
	await capture("entrance-minimap")
	await press(KEY_M)
	await create_timer(0.08).timeout
	await capture("world-map-fog")
	check(world.map_ui.full_map.center_world == world.map_ui.minimap.player_world,"rendered map initially centers on player")
	await press(KEY_M)
	for letter in "thefogisleaving": await press(letter.to_upper().unicode_at(0))
	check(session.map_reveal_cheat,"real keyboard sequence toggles map visibility")
	await press(KEY_M)
	world.map_ui.full_map.center_world = Vector2(260,186)
	world.map_ui.target_zoom = 1.45
	world.map_ui.full_map.zoom = 1.45
	await create_timer(0.08).timeout
	await capture("world-map-revealed")
	var started := Time.get_ticks_usec()
	for frame in 120: await RenderingServer.frame_post_draw
	print("MAP SOFTWARE RENDER: 120 frames, mean wall time ",(Time.get_ticks_usec()-started)/120000.0," ms")
	await press(KEY_M)
	session.evil_bart_defeated = true
	session.grant_flooded_key()
	session.key_notification_pending = false
	await press(KEY_SPACE)
	await capture("inventory-key")
	await press(KEY_SPACE)
	await session.travel("deep_forest","FromEntrance")
	current_scene.player.position = current_scene.map.get_node("Discoveries/SouthernGrove").position
	current_scene.player.get_node("Camera2D").reset_smoothing()
	await create_timer(0.12).timeout
	await capture("deep-forest-minimap")
	started = Time.get_ticks_usec()
	for frame in 120: await RenderingServer.frame_post_draw
	print("FOREST SOFTWARE RENDER: dense Deep Forest, 120 frames, mean wall time ",(Time.get_ticks_usec()-started)/120000.0," ms")
	await session.travel("flooded_forest","FromDeep")
	await create_timer(0.08).timeout
	await capture("flooded-minimap")
	await press(KEY_M)
	await capture("flooded-map-position")
	await press(KEY_M)
	await session.main_menu()
	current_scene._show_info()
	await create_timer(0.25).timeout
	check(root.get_visible_rect().encloses(current_scene.info_container.get_global_rect()),"updated controls fit 1280x720 viewport")
	await capture("controls-map-bindings")
	current_scene.queue_free()
	await create_timer(0.25).timeout
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(session.saves.save_path+suffix)
	print("CARTOGRAPHY RENDER VALIDATION: ",failures," failures")
	quit(0 if failures == 0 else 1)
