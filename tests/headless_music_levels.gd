extends SceneTree
var failures := 0
var checks := 0
var music: Node
var session: Node
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: "+message)
func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	run.call_deferred()
func run() -> void:
	music = root.get_node("Music")
	session = root.get_node("Session")
	session.saves.save_path = "user://validation-music-levels.json"
	for path: String in music.TRACK_GAIN_DB:
		var stream: AudioStream = load(path)
		check(stream != null and stream.get_length() > 1.0, "audited stream imports: "+path)
		var voice := AudioStreamPlayer.new()
		voice.stream = stream
		music.apply_gain(voice)
		check(is_equal_approx(voice.volume_db,music.TRACK_GAIN_DB[path]), "central gain applies: "+path)
		voice.free()
	change_scene_to_file("res://scenes/main_menu.tscn")
	await create_timer(.4).timeout
	var menu_stream: AudioStream = music.player.stream
	var before: float = music.player.get_playback_position()
	music.prepare_transition("res://scenes/world/overworld.tscn",.15)
	await create_timer(.05).timeout
	music.sync_scene() # Simulate failed/cancelled transition back to the same scene.
	await create_timer(.4).timeout
	check(music.player.playing and music.player.stream == menu_stream and music.player.get_playback_position() > before,"cancelled transition recovers without restarting or stopping menu")
	check(is_equal_approx(music.player.volume_db,music.gain_for_path(music.THEMES.menu)),"cancelled fade restores normalized level")
	await session.new_game()
	await create_timer(.3).timeout
	check(music.current_theme == "overworld" and music.player.playing,"new game starts overworld music")
	check(is_equal_approx(music.player.volume_db,music.gain_for_path(music.THEMES.overworld)),"overworld normalization includes existing EQ route")
	var overworld_stream: AudioStream = music.player.stream
	before = music.player.get_playback_position()
	session.area_id = "wonderland_forest"
	music.sync_scene()
	await create_timer(.3).timeout
	check(music.player.stream == overworld_stream and music.player.get_playback_position() > before,"Wonderland keeps assigned overworld song and position")
	session.area_id = "underground_cave"
	music.sync_scene()
	check(not music.player.playing,"cave retains intentional ambience-only soundtrack assignment")
	for encounter in [
		["bart","res://scenes/combat_host.tscn"],
		["boss2","res://scenes/boss2/combat_host.tscn"],
		["blankkitten","res://scenes/blankkitten/combat_host.tscn"]
	]:
		session.encounter_id = encounter[0]
		await session.transition_to(encounter[1],true)
		var battle: Node = current_scene.battle
		var audio: AudioStreamPlayer = battle.music_player
		check(audio.playing and audio.pitch_scale == 1.0, encounter[0]+" starts on original entry cue at original playback rate")
		check(is_equal_approx(audio.volume_db,music.gain_for_path(audio.stream.resource_path)), encounter[0]+" plays at measured gain")
		check(not music.player.playing and get_nodes_in_group("combat_music").size() == 1,encounter[0]+" has no overlapping music players")
		if encounter[0] == "blankkitten":
			check(battle.seek_timestamp(36.0),"Sequence debug seek remains available")
			check(is_equal_approx(audio.volume_db,music.gain_for_path(audio.stream.resource_path)),"Sequence seek restores normalized level")
		else:
			audio.seek(7.0)
		await create_timer(.15).timeout
		check(absf(battle.elapsed_time-audio.get_playback_position()) < .2, encounter[0]+" encounter clock stays synchronized after seek")
		await session.transition_to("res://scenes/main_menu.tscn")
		await create_timer(.3).timeout
		check(music.current_theme == "menu" and music.player.playing and get_nodes_in_group("combat_music").is_empty(),encounter[0]+" return restores menu and removes combat audio")
	check(not session.story_flags.get("incarna_defeated",false),"audio test does not grant boss progression")
	print("MUSIC LEVELS: ",checks," checks, ",failures," failures")
	music.play_theme("")
	quit(1 if failures else 0)
