extends SceneTree
## Accelerated integration through all 145.71 seconds with real damage enabled.
## A movement-only robot uses the same Star.step and hazard collision routines;
## it cannot alter HP, invoke victory early, or activate cheats.
const Robot = preload("res://tests/blankkitten_robot.gd")
const Cue = preload("res://scripts/blankkitten/timeline.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+text)
func run() -> void:
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-blank-play.json"
	session.area_id = "deep_forest"
	session.encounter_active = true
	session.encounter_id = "blankkitten"
	await session.transition_to("res://scenes/blankkitten/combat_host.tscn",true)
	var game: Node = current_scene.battle
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.hazards.set_physics_process(false)
	var health_at_stages := {}
	var previous_stage := -1
	var peak_debris := 0
	for frame in ceili(Cue.END*120)+1:
		var time := minf(Cue.END,frame/120.0)
		game.advance_clock(time)
		if game.stage != previous_stage:
			health_at_stages[game.stage] = game.player.health
			previous_stage = game.stage
		if game.game_over or game.victory_started: break
		game.player.step(1.0/120,Robot.steer(game,time))
		game.hazards.advance(time,true)
		peak_debris = maxi(peak_debris,game.hazards.debris.size())
		if frame%600 == 0: await process_frame
	check(game.victory_started and not game.game_over,"movement-only robot survives the complete cue sheet: HP by stage "+str(health_at_stages))
	check(game.player.health == 5,"all stages have a zero-damage route; no invincibility or health edits")
	check(game.elapsed_time == Cue.END and game.stage_history == [0,1,2,3,4,5,6,7],"entire timeline crosses all eight stages exactly once")
	check(peak_debris <= 64,"impact debris bounded; peak "+str(peak_debris))
	await session.main_menu()
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	print("BLANKKITTEN PLAY: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
