extends Node
## Loaded only by test_native_music_startup.py's temporary override.cfg.
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var watchdog := Timer.new()
	watchdog.wait_time = 15.0
	watchdog.one_shot = true
	add_child(watchdog)
	watchdog.timeout.connect(func(): get_tree().quit(1))
	watchdog.start()
	run.call_deferred()
func run() -> void:
	await get_tree().create_timer(0.7).timeout
	var music := get_node("/root/Music")
	check(get_tree().current_scene.scene_file_path == "res://scenes/main_menu.tscn", "real initial scene is the menu")
	check(music.current_theme == "menu" and music.player.playing, "native launch starts menu music without a scene change")
	check(music.player.get_playback_position() > 0.1, "native menu playback advances")
	check(is_equal_approx(music.player.volume_db, music.gain_for_path(music.THEMES.menu)), "native menu reaches normalized gain")
	var master := AudioServer.get_bus_index("Master")
	check(not AudioServer.is_bus_mute(master) and AudioServer.get_bus_volume_db(master) == 0.0, "menu route is audible")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1.0
	AudioServer.add_bus_effect(master, capture)
	music.player.seek(20.0)
	await get_tree().create_timer(0.5).timeout
	var peak := 0.0
	for sample in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	check(peak > 0.001 and peak < 1.0, "imported menu WAV produces non-silent, unclipped mixer samples")
	AudioServer.remove_bus_effect(master, AudioServer.get_bus_effect_count(master)-1)
	music.player.seek(music.player.stream.get_length()-0.15)
	await get_tree().create_timer(0.5).timeout
	check(music.player.playing and music.player.get_playback_position() < 1.0, "native menu wraps its WAV loop")
	print("NATIVE MUSIC: ", checks, " checks, ", failures, " failures")
	music.play_theme("")
	get_tree().quit.call_deferred(1 if failures else 0)
