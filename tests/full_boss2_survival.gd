extends SceneTree
var seen: Array[int] = []
var peak := 0
var failures := 0
var last_phase := -1
func _initialize() -> void:
	create_timer(160).timeout.connect(func(): quit(1))
	call_deferred("run")
func run() -> void:
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-boss2-full-song.json"
	await session.new_game()
	session.evil_bart_defeated = true
	session.grant_flooded_key()
	await session.travel("flooded_forest","FromDeep")
	await session.begin_boss2_battle(Vector2(1840,450))
	var battle: Node = current_scene.battle
	# Explicit test invincibility observes the full uninterrupted timeline, not skill.
	battle.player.invincible = true
	while not battle.victory_started:
		await physics_frame
		peak = maxi(peak,get_nodes_in_group("boss2_projectiles").size())
		if battle.timeline.phase != last_phase:
			last_phase = battle.timeline.phase
			seen.append(last_phase)
			print("FULL SONG: phase ",last_phase," at ",battle.elapsed_time)
		if battle.timeline.phase == 3 and (get_nodes_in_group("boss2_projectiles").size() > 0 or battle.timeline.lasers[0].active):
			failures += 1
		if battle.game_over or peak > 240:
			failures += 1
			break
	print("PASS: full uninterrupted audio clock" if seen == [0,1,2,3,4,5,6] else "FAIL: missing phase")
	if seen != [0,1,2,3,4,5,6]:
		failures += 1
	print("PASS: survival victory at 140.80" if battle.victory_started and battle.elapsed_time >= 140.80 else "FAIL: ending")
	if not battle.victory_started or battle.elapsed_time < 140.80:
		failures += 1
	print("PASS: intermission and projectile cap" if failures == 0 else "FAIL: safety/cap")
	print("FULL SONG PEAK PROJECTILES: ",peak)
	await create_timer(0.85).timeout
	await session.main_menu()
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	print("FULL SURVIVAL VALIDATION: 3 checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
