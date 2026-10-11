extends SceneTree
## Presentation benchmark only; no claim about gameplay or target hardware FPS.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-sequence-profile.json"
	await session.transition_to("res://scenes/blankkitten/combat_host.tscn",true)
	var game: Node = current_scene.battle
	for node in [game,game.player,game.hazards]: node.set_physics_process(false)
	var modes := {}
	for reduced in [false,true]:
		game.reduced_effects = reduced
		game.rebuild_clock(110)
		var times: Array[float] = []
		var peak := 0
		for i in 150:
			var began := Time.get_ticks_usec()
			game.advance_clock(110+i/60.0)
			await process_frame
			await RenderingServer.frame_post_draw
			if i >= 30: times.append((Time.get_ticks_usec()-began)/1000.0)
			peak = maxi(peak,game.feedback.particles.size())
		times.sort()
		modes[str(reduced)] = {"median_ms":times[times.size()/2],"p95_ms":times[int(times.size()*.95)],"peak_particles":peak,"objects":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}
	print("SEQUENCE RENDER PROFILE (software renderer): ",JSON.stringify(modes))
	await session.main_menu()
	root.get_node("Music").play_theme("")
	await create_timer(.2).timeout
	quit()
