extends Node2D
const Cue = preload("res://scripts/blankkitten/timeline.gd")
enum State { ENTERING, INTRODUCTION, ACTIVE_MINIGAME, ARENA_TRANSITION, BREAK, FINAL_PHASE, ENDING, VICTORY, DEFEAT }
@export var cue_sheet: Resource = preload("res://resources/blankkitten/timeline.tres")
var state := State.ENTERING
var player: Node2D
var music_player: AudioStreamPlayer
var hazards: Node2D
var presentation: Node2D
var ui: CanvasLayer
var arena_rect := Cue.BOXES[0]
var arena_clip: Control
var elapsed_time := 0.0
var stage := 0
var morph_target := -1
var morph_from := arena_rect
var star_from := Vector2.ZERO
var game_over := false
var victory_started := false
var audio_fade: Tween
var clock_initialized := false
var last_audio_position := 0.0
var audio_error := ""
var stage_history: Array[int] = [0]

func _ready() -> void:
	process_physics_priority = -20
	add_to_group("combat_root")
	presentation = $CinematicArena
	music_player = $Music
	music_player.add_to_group("combat_music")
	ui = $UI
	player = Node2D.new()
	player.name = "RainbowStar"
	player.z_index = 2
	player.set_script(preload("res://scripts/blankkitten/star.gd"))
	player.position = arena_rect.get_center()
	add_child(player)
	player.defeated.connect(_defeat)
	arena_clip = Control.new()
	arena_clip.name = "HazardClip"
	arena_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena_clip.clip_contents = true
	add_child(arena_clip)
	hazards = Node2D.new()
	hazards.name = "Hazards"
	hazards.set_script(preload("res://scripts/blankkitten/hazards.gd"))
	hazards.battle = self
	arena_clip.add_child(hazards)
	presentation.attach_title(ui.root)
	hazards.configure(0)
	advance_clock(0)
	if Session.battle_entry_pending:
		state = State.ENTERING
	if music_player.stream == null:
		call_deferred("_audio_failure","Soundtrack unavailable. Retry after restoring catVibes - 004.mp3.")
	elif not Session.battle_entry_pending:
		music_player.play(0)
		state = State.INTRODUCTION

func _physics_process(_delta: float) -> void:
	if game_over or victory_started:
		return
	if not music_player.playing:
		if state != State.ENTERING:
			_audio_failure("Audio playback stopped. Retry starts at 0:00.")
		return
	var raw := music_player.get_playback_position()
	var audible := maxf(0,raw+AudioServer.get_time_since_last_mix()-AudioServer.get_output_latency())
	# Mix positions can briefly jitter. A backward seek >100 ms is a genuine
	# discontinuity; reconstruct state from the cue sheet, not a stale maximum.
	if clock_initialized and raw < last_audio_position-0.1:
		rebuild_clock(audible)
	else:
		advance_clock(maxf(elapsed_time,audible))
	last_audio_position = raw
	clock_initialized = true

func rebuild_clock(time: float) -> void:
	# Explicit seek/reload support. No pending attack/spin/fade callbacks exist.
	hazards.clear()
	stage = Cue.stage_at(time)
	stage_history = [stage]
	ui.phase_title.cue_time = -10
	ui.phase_title.label.text = ""
	hazards.impact_log.clear()
	morph_target = -1
	arena_rect = Cue.BOXES[stage]
	player.gravity_mode = Cue.GRAVITY[stage]
	player.grounded = player.gravity_mode
	player.velocity = Vector2.ZERO
	player.position = safe_point(arena_rect,player.gravity_mode)
	player.previous_position = player.position
	player.invulnerability = player.hit_grace
	hazards.configure(stage)
	hazards.last_clock = time
	advance_clock(time)

func safe_point(rect: Rect2, gravity_mode: bool) -> Vector2:
	return Vector2(rect.get_center().x,rect.end.y-player.RADIUS) if gravity_mode else rect.get_center()

func advance_clock(time: float) -> void:
	if game_over or victory_started:
		return
	elapsed_time = clampf(time,0,Cue.END)
	var next_stage := Cue.stage_at(elapsed_time)
	if next_stage != stage:
		# Cross any skipped boundaries exactly once, but only create the current
		# stage's hazards. Do not replay old attacks after a slow frame or seek.
		for index in range(stage+1,next_stage+1):
			stage_history.append(index)
		stage = next_stage
		arena_rect = Cue.BOXES[stage]
		player.gravity_mode = Cue.GRAVITY[stage]
		player.position = safe_point(arena_rect,player.gravity_mode)
		player.previous_position = player.position
		player.velocity = Vector2.ZERO
		player.grounded = player.gravity_mode
		morph_target = -1
		hazards.configure(stage)
		ui.stage_changed(stage,elapsed_time)
	var target := Cue.morph_at(elapsed_time)
	player.transition_safe = target >= 0 or stage in [0,3,7]
	player.movement_locked = target >= 0
	if target >= 0:
		if target != morph_target:
			morph_target = target
			morph_from = arena_rect
			star_from = player.position
			hazards.stop_damage()
		var blend := smoothstep(0,1,(elapsed_time-(Cue.STARTS[target]-Cue.MORPH))/Cue.MORPH)
		arena_rect = Rect2(morph_from.position.lerp(Cue.BOXES[target].position,blend),morph_from.size.lerp(Cue.BOXES[target].size,blend))
		player.position = star_from.lerp(safe_point(Cue.BOXES[target],Cue.GRAVITY[target]),blend)
		player.previous_position = player.position
		state = State.ARENA_TRANSITION
	else:
		state = State.INTRODUCTION if stage == 0 else (State.BREAK if stage == 3 else (State.FINAL_PHASE if stage == 6 else (State.ENDING if stage == 7 else State.ACTIVE_MINIGAME)))
	arena_clip.position = arena_rect.position
	arena_clip.size = arena_rect.size
	hazards.position = -arena_rect.position
	hazards.advance(elapsed_time)
	presentation.update_clock(elapsed_time)
	ui.update_clock(elapsed_time)
	if elapsed_time >= Cue.END:
		finish_survival()

func finish_survival() -> void:
	if victory_started or game_over or player.health <= 0 or elapsed_time < Cue.END:
		return
	victory_started = true
	state = State.VICTORY
	hazards.clear()
	player.movement_locked = true
	get_tree().current_scene.record_victory()
	_fade_music(0.15)
	ui.show_result(true)

func _defeat() -> void:
	if game_over or victory_started:
		return
	game_over = true
	state = State.DEFEAT
	hazards.clear()
	player.movement_locked = true
	player.velocity = Vector2.ZERO
	music_player.stop()
	ui.show_result(false,audio_error)

func _audio_failure(reason: String) -> void:
	if game_over or victory_started:
		return
	audio_error = reason
	_defeat()

func _on_music_finished() -> void:
	if game_over or victory_started:
		return
	if music_player.stream != null and music_player.stream.get_length() >= Cue.END and elapsed_time >= Cue.END-0.15:
		advance_clock(Cue.END)
	else:
		_audio_failure("Audio ended early. Retry starts at 0:00.")

func _fade_music(duration: float) -> void:
	audio_fade = create_tween()
	audio_fade.tween_property(music_player,"volume_db",-60.0,duration)
	audio_fade.tween_callback(music_player.stop)

func _exit_tree() -> void:
	if is_instance_valid(audio_fade):
		audio_fade.kill()
	if is_instance_valid(music_player):
		music_player.stop()
