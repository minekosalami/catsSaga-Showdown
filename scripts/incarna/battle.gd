extends Node2D
const Cfg = preload("res://scripts/incarna/config.gd")
var player: Area2D
var music_player: AudioStreamPlayer
var rig: Node2D
var timeline: Node2D
var ui: CanvasLayer
var elapsed_time := 0.0
var game_over := false
var victory_started := false
var reduced_effects := false
var effects: Node2D
var audio_fade: Tween
var last_audio := 0.0
var veil: ColorRect
var atmosphere: ColorRect

func _ready() -> void:
	process_physics_priority = -20
	add_to_group("combat_root")
	reduced_effects = bool(Session.get_meta("incarna_reduced_fx",false))
	var black := ColorRect.new()
	black.size = Vector2(Cfg.SIZE)
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.z_index = -10
	add_child(black)
	veil = ColorRect.new()
	veil.size = Vector2(Cfg.SIZE)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.z_index = -9
	add_child(veil)
	atmosphere = ColorRect.new()
	atmosphere.size = Vector2(1280,414)
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmosphere.z_index = -8
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/incarna_backdrop.gdshader")
	atmosphere.material = material
	add_child(atmosphere)
	rig = preload("res://scripts/incarna/rig.gd").new()
	rig.name = "Incarna"
	rig.scale = Vector2.ONE*1.1
	add_child(rig)
	effects = preload("res://scripts/boss2/effects.gd").new()
	effects.name = "Effects"
	effects.z_index = 22
	add_child(effects)
	# Reuse particles/afterimages; omit the old boss-specific aura.
	effects.aura_canvas.hide()
	effects.z_index = 22
	player = preload("res://scenes/player.tscn").instantiate()
	player.set_script(preload("res://scripts/incarna/player.gd"))
	player.position = Cfg.SPAWN-player.get_node("CollisionShape2D").position
	player.process_physics_priority = -10
	player.z_index = 21
	add_child(player)
	player.game_over.connect(_defeat)
	music_player = $Music
	music_player.add_to_group("combat_music")
	ui = preload("res://scripts/incarna/hud.gd").new()
	ui.name = "UI"
	ui.battle = self
	add_child(ui)
	timeline = preload("res://scripts/incarna/timeline.gd").new()
	timeline.name = "IncarnaTimeline"
	timeline.z_index = 20
	add_child(timeline)
	timeline.initialize(self,rig)
	update_clock(0.0)
	if not Session.battle_entry_pending: music_player.play(0.0)

func _physics_process(_delta: float) -> void:
	if game_over or victory_started: return
	if not music_player.playing: return
	var raw := music_player.get_playback_position()
	var audible := maxf(0,raw+AudioServer.get_time_since_last_mix()-AudioServer.get_output_latency())
	if raw < last_audio-.1:
		timeline.reset_clock(audible)
		elapsed_time = audible
	last_audio = raw
	update_clock(maxf(elapsed_time,audible))

func update_clock(time: float) -> void:
	if game_over or victory_started: return
	elapsed_time = clampf(time,0,Cfg.END)
	player.entrance_locked = elapsed_time < Cfg.EMERGENCE
	if player.entrance_locked: player.velocity = Vector2.ZERO
	timeline.advance(elapsed_time)
	# Slow measure-length red breathing; the creature itself remains monochrome.
	var pulse := pow(.5-.5*cos(TAU*elapsed_time/Cfg.MEASURE),2)
	var strength := .045 if elapsed_time < 27.42 else .095
	if elapsed_time >= 96: strength *= .65
	var answer := exp(-maxf(0,elapsed_time-82.28)*3) if elapsed_time >= 82.28 else 0.0
	veil.color = Color(.65,0.015,0.025,(strength*pulse+answer*.11)*(.28 if reduced_effects else 1))
	atmosphere.material.set_shader_parameter("clock",elapsed_time)
	atmosphere.material.set_shader_parameter("strength",0.0 if reduced_effects else smoothstep(41.14,45,elapsed_time)*(1-smoothstep(102.85,Cfg.END,elapsed_time)))
	ui.update_clock(elapsed_time)
	if elapsed_time >= Cfg.END: finish_survival()

func notify_hit(point: Vector2) -> void:
	effects.burst(point,Color("#FF655B"),14,180,.35)
	rig.push_impulse(elapsed_time,.35)

func finish_survival() -> void:
	if victory_started or game_over or elapsed_time < Cfg.END or player.health <= 0: return
	victory_started = true
	timeline.clear()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.get_node("HitboxDebug").hide()
	get_tree().current_scene.record_victory()
	_fade_music(.35)
	var exit := create_tween().set_parallel(true)
	exit.tween_property(rig,"modulate:a",0.0,1.0)
	exit.tween_property(veil,"color:a",0.0,1.0)
	ui.show_result(true)

func _defeat() -> void:
	if game_over or victory_started: return
	game_over = true
	timeline.clear()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	_fade_music(.45)
	ui.show_result(false)

func _fade_music(duration: float) -> void:
	audio_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	audio_fade.tween_property(music_player,"volume_db",-60.0,duration)
	audio_fade.tween_callback(music_player.stop)

func _exit_tree() -> void:
	if is_instance_valid(audio_fade): audio_fade.kill()
	if is_instance_valid(music_player): music_player.stop()
