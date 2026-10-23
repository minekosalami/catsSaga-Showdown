extends SceneTree
var samples: Array[float] = []
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280,720)
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://benchmark-overhaul.json"
	await session.new_game()
	await session.travel("deep_forest","FromEntrance")
	current_scene.player.position = Vector2(2440,1200)
	current_scene.player.get_node("Camera2D").reset_smoothing()
	for i in range(35):await process_frame
	var previous := Time.get_ticks_usec()
	for i in range(120):
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now-previous)/1000.0)
		previous = now
	samples.sort()
	print("BENCHMARK ",JSON.stringify({"median_frame_ms":samples[60],"p95_frame_ms":samples[114],"nodes":get_node_count(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"static_memory_mb":OS.get_static_memory_usage()/1048576.0,"renderer":RenderingServer.get_video_adapter_name()}))
	await session.main_menu()
	root.get_node("Music").play_theme("")
	quit()
