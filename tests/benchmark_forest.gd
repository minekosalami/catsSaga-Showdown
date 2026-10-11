extends SceneTree

func _initialize() -> void:
	create_timer(40).timeout.connect(func(): quit(1))
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280,720)
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-forest-benchmark.json"
	await session.new_game()
	await session.travel("deep_forest","FromEntrance")
	current_scene.player.position = current_scene.map.get_node("Discoveries/SouthernGrove").position
	current_scene.player.get_node("Camera2D").reset_smoothing()
	await create_timer(0.5).timeout
	for frame in 30: await RenderingServer.frame_post_draw
	var started := Time.get_ticks_usec()
	for frame in 240: await RenderingServer.frame_post_draw
	print("FOREST BENCHMARK: mean ms=",(Time.get_ticks_usec()-started)/240000.0,"; Godot=",Engine.get_version_info().string)
	current_scene.queue_free()
	await create_timer(0.25).timeout
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(session.saves.save_path+suffix)
	quit()
