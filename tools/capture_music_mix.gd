extends SceneTree
## Real-time capture after the live theme route (including Overworld clarity EQ).
## Usage: godot --headless --audio-driver Dummy --path . --script tools/capture_music_mix.gd -- overworld /tmp/overworld.f32le
var capture: AudioEffectCapture
var output: FileAccess
var frames := 0
var music: Node
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["menu","overworld"]:
		push_error("Pass menu|overworld and an external f32le output path.")
		quit(1)
		return
	music = root.get_node("Music")
	music.play_theme(args[0])
	music.fade.kill()
	music.player.volume_db = music.gain_for_path(music.THEMES[args[0]])
	if music.player.stream is AudioStreamWAV:
		music.player.stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	else:
		music.player.stream.loop = false
	capture = AudioEffectCapture.new()
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"),capture)
	output = FileAccess.open(args[1],FileAccess.WRITE)
	if output == null:
		quit(1)
		return
	music.player.finished.connect(done)
	print("CAPTURE_BEGIN rate=",AudioServer.get_mix_rate()," gain=",music.player.volume_db)
func _process(_delta: float) -> bool:
	if capture != null: drain()
	return false
func drain() -> void:
	var available := capture.get_frames_available()
	if available > 0:
		output.store_buffer(capture.get_buffer(available).to_byte_array())
		frames += available
func done() -> void:
	await create_timer(.2).timeout
	drain()
	output.close()
	var dropped := capture.get_discarded_frames()
	print("CAPTURE_END frames=",frames," dropped=",dropped)
	music.play_theme("")
	quit(0 if dropped == 0 and frames > 0 else 1)
