extends SceneTree
const Robot = preload("res://tests/blankkitten_robot.gd")
const Cue = preload("res://scripts/blankkitten/timeline.gd")
var checks := 0
var failures := 0
class Pilot extends Node:
	var game: Node
	var stages := {}
	func _physics_process(delta: float) -> void:
		if game.game_over or game.victory_started: return
		if not stages.has(game.stage):
			stages[game.stage] = game.player.health
			print("REAL AUDIO STAGE ",game.stage," at ",game.elapsed_time," HP=",game.player.health)
		game.player.step(delta,Robot.steer(game,game.elapsed_time))
		game.hazards.advance(game.elapsed_time,true)
func _initialize() -> void:
	create_timer(180).timeout.connect(func(): quit(1))
	call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+text)
func run() -> void:
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-blank-full-audio.json"
	session.area_id = "bart_area"
	session.encounter_active = true
	session.encounter_id = "blankkitten"
	await session.transition_to("res://scenes/blankkitten/combat_host.tscn",true)
	var game: Node = current_scene.battle
	game.player.set_physics_process(false)
	game.hazards.set_physics_process(false)
	var pilot := Pilot.new()
	pilot.game = game
	game.add_child(pilot)
	var began := Time.get_ticks_msec()
	while not game.game_over and not game.victory_started: await process_frame
	var duration := (Time.get_ticks_msec()-began)/1000.0
	check(game.victory_started and not game.game_over,"complete actual MP3 playback survives without clock overrides or cheats")
	# Victory can level up and refill HP; count actual damage instead of comparing
	# post-reward HP with the pre-fight maximum (or the old five-hit health model).
	check(current_scene.rpg_ui.score.hits == 0,"real physics/audio movement-only route takes no damage")
	var audible: float = game.music_player.get_playback_position()+AudioServer.get_time_since_last_mix()-AudioServer.get_output_latency()
	check(absf(audible-Cue.END) < 0.1 and game.elapsed_time == Cue.END,"victory follows actual playback at 145.71 s; audio "+str(audible)+", host runtime "+str(duration))
	check(game.stage_history == [0,1,2,3,4,5,6,7],"real audio visits every stage exactly once")
	check(session.story_flags.get("blankkitten_defeated",false),"real encounter saves completion")
	await create_timer(0.2).timeout
	check(not game.music_player.playing,"actual MP3 tail fades and stops after victory")
	await session.main_menu()
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	print("BLANKKITTEN FULL AUDIO: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
