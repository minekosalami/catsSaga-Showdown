extends Node

# One persistent player for non-combat themes; battle owns its original soundtrack.
const THEMES := {
	"menu": "res://assets/soundtrack/Menu - 001.wav",
	"overworld": "res://assets/soundtrack/Overworld - 002.mp3"
}
const MUSIC_VOLUME_DB := -12.0
var player: AudioStreamPlayer
var current_theme := ""
var streams: Dictionary = {}
var fade: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.name = "ThemePlayer"
	player.volume_db = MUSIC_VOLUME_DB
	player.add_to_group("background_music")
	add_child(player)
	get_tree().scene_changed.connect(sync_scene)

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
	if theme == current_theme and player.playing:
		return
	if is_instance_valid(fade):
		fade.kill()
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
	player.bus = "Overworld" if theme == "overworld" else "Master"
	player.stream = streams[theme]
	player.volume_db = -60.0
	player.play()
	fade = create_tween()
	fade.tween_property(player, "volume_db", MUSIC_VOLUME_DB, 0.25)

func _exit_tree() -> void:
	if is_instance_valid(fade):
		fade.kill()
	player.stop()
	player.stream = null
	streams.clear()
