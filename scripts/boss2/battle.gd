extends Node2D

@export var end_time := 140.80
@export_multiline var introductory_dialogue := "[Automatic introductory dialogue placeholder — replace in the Inspector.]"
@export_range(0.0,1.0,0.05) var effect_intensity := 0.25
var player: Area2D
var music_player: AudioStreamPlayer
var timeline: Node2D
var ui: CanvasLayer
var elapsed_time := 0.0
var game_over := false
var victory_started := false
var shake_time := 0.0
var shake_strength := 0.0
var background_material: ShaderMaterial
var audio_fade: Tween
var visual_intensity := 0.0

func _ready() -> void:
	add_to_group("combat_root")
	player = preload("res://scenes/player.tscn").instantiate()
	player.set_script(preload("res://scripts/boss2/player.gd"))
	player.position = Vector2(270,780)
	add_child(player)
	player.game_over.connect(_defeat)
	music_player = $Music
	music_player.add_to_group("combat_music")
	timeline = $Boss2Timeline
	# Timeline needs the player initialized to derive its two-sprite-wide gap.
	timeline.initialize()
	ui = $UI

	background_material = ShaderMaterial.new()
	background_material.shader = preload("res://shaders/battle_background.gdshader")
	$Background.material = background_material
	music_player.play(0.0)
	timeline.advance(0.0)
	ui.update(0.0)

func _physics_process(delta: float) -> void:
	if game_over or victory_started:
		return
	# Audio is the sole encounter clock. No delta accumulation or per-phase timers.
	if music_player.playing:
		var audio_time := music_player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
		elapsed_time = maxf(elapsed_time,maxf(0,audio_time))
	timeline.advance(minf(elapsed_time,end_time))
	if elapsed_time >= end_time:
		finish_survival()
	if not game_over and not victory_started:
		ui.update(elapsed_time)
	var intensity := 0.08
	if timeline.phase == 2:
		intensity = 0.4
	elif timeline.phase == 4:
		intensity = 0.75
	background_material.set_shader_parameter("clock",elapsed_time)
	visual_intensity = move_toward(visual_intensity,intensity * effect_intensity,delta * 0.3)
	background_material.set_shader_parameter("intensity",visual_intensity)
	background_material.set_shader_parameter("atmosphere",Color("#5099C9"))
	shake_time = maxf(0,shake_time-delta)
	# Shake only background scenery; actors and lasers retain exact coordinates.
	$Background.position = Vector2(270,450) + (Vector2(randf_range(-1,1),randf_range(-1,1)) * minf(2,shake_strength) if shake_time > 0 else Vector2.ZERO)

func finish_survival() -> void:
	if victory_started or game_over or player.health <= 0 or elapsed_time < end_time:
		return
	victory_started = true
	timeline.clear_hostiles()
	_freeze_player()
	get_tree().current_scene.record_victory()
	_fade_music()
	ui.show_result(true)

func _defeat() -> void:
	if game_over or victory_started:
		return
	game_over = true
	timeline.clear_hostiles()
	_freeze_player()
	_fade_music()
	ui.show_result(false)

func _freeze_player() -> void:
	player.get_node("HitboxDebug").hide()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	for child in get_children():
		if child.get_script() == preload("res://scripts/rainbow_beam.gd"):
			child.queue_free()

func _fade_music() -> void:
	audio_fade = create_tween()
	audio_fade.tween_property(music_player,"volume_db",-60.0,0.8)
	audio_fade.tween_callback(music_player.stop)

func _exit_tree() -> void:
	if is_instance_valid(audio_fade):
		audio_fade.kill()
	if is_instance_valid(music_player):
		music_player.stop()
