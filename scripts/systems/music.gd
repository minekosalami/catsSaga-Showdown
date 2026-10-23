extends Node

# One persistent player for non-combat themes; battle owns its original soundtrack.
const THEMES := {
	"menu": "res://assets/soundtrack/Menu - 001.wav",
	"overworld": "res://assets/soundtrack/Overworld - 002.mp3"
}
# Static gain only: measured EBU R128 loudness, capped at -1.1 dBTP.
# Overworld includes its existing clarity EQ and -1.2 dB bus (see audit).
const TRACK_GAIN_DB := {
	"res://assets/soundtrack/Menu - 001.wav": 1.24,
	"res://assets/soundtrack/Overworld - 002.mp3": 0.76, # +EQ, then -1.2 dB Overworld bus: final -1.1 dBTP.
	"res://assets/soundtrack/SyNaPse - 003.mp3": -6.16,
	"res://assets/soundtrack/catVibes - 004.mp3": -4.61,
	"res://assets/soundtrack/NatoKyofu - 005.mp3": -2.24, # Unassigned; do not change soundtrack assignments.
	"res://assets/soundtrack/Malware - 006.mp3": -2.88,
	"res://assets/fight.v.scale - catsSaga version.mp3": -9.69,
}
var player: AudioStreamPlayer
var current_theme := ""
var streams: Dictionary = {}
var fade: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	player = AudioStreamPlayer.new()
	player.name = "ThemePlayer"
	player.volume_db = 0.0
	player.add_to_group("background_music")
	add_child(player)
	get_tree().scene_changed.connect(sync_scene)
	# Initial engine startup does not emit scene_changed. Wait until the main
	# scene is installed, then use the same idempotent path as later navigation.
	get_tree().process_frame.connect(sync_scene, CONNECT_ONE_SHOT)

func theme_for(path: String) -> String:
	if path == "res://scenes/main_menu.tscn":
		return "menu"
	if path == "res://scenes/world/overworld.tscn":
		return "" if Session.area_id == "underground_cave" else "overworld"
	return ""

func prepare_transition(path: String, duration: float) -> void:
	if theme_for(path) == current_theme:
		return # Preserve playback position across forest transitions.
	if is_instance_valid(fade):
		fade.kill()
	if player.playing:
		fade = create_tween()
		fade.tween_property(player, "volume_db", -60.0, duration)
		fade.tween_callback(player.stop)

func sync_scene() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	play_theme(theme_for(scene.scene_file_path))

func play_theme(theme: String) -> void:
	if is_instance_valid(fade):
		fade.kill()
	if theme == current_theme and player.playing:
		# Recover an interrupted transition without restarting the composition.
		fade = create_tween()
		fade.tween_property(player, "volume_db", gain_for_path(THEMES[theme]), 0.25)
		return
	player.stop()
	current_theme = theme
	if theme.is_empty():
		player.stream = null
		return
	if not streams.has(theme):
		var stream: AudioStream = load(THEMES[theme]).duplicate()
		if stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
		elif stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
			stream.loop = true
		streams[theme] = stream
	player.bus = "Overworld" if theme == "overworld" else "Music"
	player.stream = streams[theme]
	player.volume_db = -60.0
	player.play()
	fade = create_tween()
	fade.tween_property(player, "volume_db", gain_for_path(THEMES[theme]), 0.25)

func gain_for_path(path: String) -> float:
	return TRACK_GAIN_DB.get(path, 0.0)

func apply_gain(audio: AudioStreamPlayer) -> void:
	# Apply before play(), leaving each encounter's clock, seek and fades intact.
	audio.bus = "Music"
	if audio.stream != null:
		audio.volume_db = gain_for_path(audio.stream.resource_path)

func _exit_tree() -> void:
	if is_instance_valid(fade):
		fade.kill()
	player.stop()
	player.stream = null
	streams.clear()
