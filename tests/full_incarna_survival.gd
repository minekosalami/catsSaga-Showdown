extends SceneTree
const Cfg = preload("res://scripts/incarna/config.gd")
var failures := 0
var peak := 0
func _initialize() -> void:
	create_timer(130).timeout.connect(func(): quit(1))
	call_deferred("run")
func run() -> void:
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-incarna-full-song.json"
	session.encounter_id = "incarna"
	session.encounter_active = true
	session.area_id = "underground_cave"
	session.return_position = preload("res://scripts/world/cave_layout.gd").SHORTCUT_JUNCTION+Vector2(0,160)
	await session.transition_to("res://scenes/incarna/combat_host.tscn",true)
	var game: Node = current_scene.battle
	# Explicit invincible observer validates the unmodified soundtrack, not skill.
	game.player.invincible = true
	var last := -1
	while not game.victory_started:
		await physics_frame
		peak = maxi(peak,game.timeline.shots.size())
		if game.timeline.section != last:
			last = game.timeline.section
			print("INCARNA SONG: cue ",last," at ",game.elapsed_time)
		if game.timeline.shots.size() > Cfg.MAX_SHOTS or game.timeline.zones.size() > Cfg.MAX_ZONES: failures += 1
		if game.elapsed_time < 10 and not game.player.entrance_locked: failures += 1
		if game.elapsed_time < 20.57 and not game.timeline.shots.is_empty(): failures += 1
	if absf(game.elapsed_time-Cfg.END) > .001 or not session.story_flags.get("incarna_defeated",false): failures += 1
	if game.timeline.cue_log != [20.57,27.42,41.14,82.28,96.0,102.85,113.14]: failures += 1
	await create_timer(.4).timeout
	if game.music_player.playing: failures += 1
	await session.main_menu()
	print("INCARNA FULL SONG: peak ",peak," projectiles; ",failures," failures")
	quit(1 if failures else 0)
