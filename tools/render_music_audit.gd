extends SceneTree
## Offline decode of the actual Godot-imported streams, for external LUFS checks.
## Does not write or re-encode any source asset. Output is interleaved stereo f32le.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Pass an output directory after -- (outside the repository).")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(args[0])
	var music := root.get_node("Music")
	var manifest := []
	for path: String in music.TRACK_GAIN_DB:
		var stream: AudioStream = load(path)
		if stream == null:
			quit(1)
			return
		var playback := stream.instantiate_playback()
		playback.start()
		var filename := path.get_file().get_basename()+".f32le"
		var file := FileAccess.open(args[0].path_join(filename), FileAccess.WRITE)
		var remaining := ceili(stream.get_length()*AudioServer.get_mix_rate())
		while remaining > 0:
			var frames := mini(4096, remaining)
			file.store_buffer(playback.mix_audio(1.0, frames).to_byte_array())
			remaining -= frames
		playback.stop()
		file.close()
		manifest.append({"path":path.trim_prefix("res://"),"file":filename,"sample_rate":AudioServer.get_mix_rate(),"duration":stream.get_length()})
		print("DECODED: ",path)
	var output := FileAccess.open(args[0].path_join("manifest.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify(manifest,"\t")+"\n")
	output.close()
	quit()
