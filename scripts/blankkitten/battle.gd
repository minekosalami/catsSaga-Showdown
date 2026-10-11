extends Node2D
const Cue = preload("res://scripts/blankkitten/timeline.gd")
enum State { ENTERING, INTRODUCTION, ACTIVE_MINIGAME, ARENA_TRANSITION, BREAK, FINAL_PHASE, ENDING, VICTORY, DEFEAT }
@export var cue_sheet: Resource = preload("res://resources/blankkitten/timeline.tres")
@export var reduced_effects := false
var practice_mode := false
var development_run := false
var practice_stage := 0
var practice_end := 0.0
var feedback: Node2D
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
	reduced_effects = bool(Session.get_meta("blankkitten_reduced_effects",false))
	feedback = Node2D.new()
	feedback.name = "SequenceFeedback"
	feedback.set_script(preload("res://scripts/blankkitten/feedback.gd"))
	add_child(feedback)
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
	feedback.clear()
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
	ui.stage_changed(stage,time)
	advance_clock(time)

func safe_point(rect: Rect2, gravity_mode: bool) -> Vector2:
	return Vector2(rect.get_center().x,rect.end.y-player.RADIUS-player.INNER_EDGE) if gravity_mode else rect.get_center()

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
		remember_stage(stage)
		if stage == 6:
			feedback.cue("glitch",elapsed_time)
			feedback.burst(Vector2(270,230),Color("#FFBB85"),28,elapsed_time,.8,true)
			feedback.shake_start = elapsed_time
			feedback.shake_amount = 1.7
	var target := Cue.morph_at(elapsed_time)
	player.transition_safe = target >= 0 or stage in [0,3,7]
	player.movement_locked = target >= 0
	if target >= 0:
		if target != morph_target:
			morph_target = target
			morph_from = arena_rect
			star_from = player.position
			hazards.stop_damage()
			feedback.cue("morph",elapsed_time)
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
	# The same inset protects the visible silhouette, including during morphs.
	player.position = player.position.clamp(arena_rect.position+Vector2.ONE*(player.RADIUS+player.INNER_EDGE),arena_rect.end-Vector2.ONE*(player.RADIUS+player.INNER_EDGE))
	player.clock = elapsed_time
	player.queue_redraw()
	feedback.update_clock(elapsed_time)
	presentation.update_clock(elapsed_time)
	ui.update_clock(elapsed_time)
	if practice_mode and elapsed_time >= practice_end:
		finish_practice()
	elif elapsed_time >= Cue.END:
		finish_survival()

func finish_survival() -> void:
	if victory_started or game_over or player.health <= 0 or elapsed_time < Cue.END:
		return
	victory_started = true
	state = State.VICTORY
	hazards.clear()
	player.movement_locked = true
	if not development_run:
		get_tree().current_scene.record_victory()
	_fade_music(0.15)
	ui.show_result(true)
	if development_run:
		ui.result_label.text = "PREVIEW COMPLETE()"
		ui.return_button.hide()
		ui.retry_button.grab_focus()

func _defeat() -> void:
	if game_over or victory_started:
		return
	game_over = true
	state = State.DEFEAT
	ui.update_clock(elapsed_time)
	hazards.clear()
	player.movement_locked = true
	player.velocity = Vector2.ZERO
	_fade_music(.18)
	if player.health <= 0:
		feedback.die(player.position)
	else:
		ui.show_result(false,audio_error)

func _audio_failure(reason: String) -> void:
	if game_over or victory_started:
		return
	audio_error = reason
	_defeat()

func remember_stage(index: int) -> void:
	if development_run or practice_mode: return
	var seen: Dictionary = Session.get_meta("blankkitten_seen_stages",{})
	if index in [1,2,4,5,6]: seen[index] = true
	Session.set_meta("blankkitten_seen_stages",seen)

func seek_timestamp(time: float, practice := false) -> bool:
	if not practice and not OS.is_debug_build(): return false
	if time < 0 or time >= Cue.END or game_over or victory_started: return false
	var index := Cue.stage_at(time)
	if practice:
		var seen: Dictionary = Session.get_meta("blankkitten_seen_stages",{})
		if not seen.has(index) or index not in [1,2,4,5,6]: return false
	practice_mode = practice
	development_run = not practice
	practice_stage = index
	practice_end = Cue.STARTS[index+1]-Cue.MORPH if practice else Cue.END
	music_player.volume_db = -12
	music_player.play(time)
	rebuild_clock(time)
	clock_initialized = false
	return true

func finish_practice() -> void:
	if game_over or victory_started: return
	victory_started = true
	state = State.VICTORY
	hazards.clear()
	player.movement_locked = true
	_fade_music(.3)
	ui.show_result(true)
	ui.result_label.text = "PRACTICE COMPLETE()"
	ui.result_label.add_theme_font_size_override("font_size",24)
	ui.return_button.hide()
	ui.retry_button.grab_focus()

func apply_launch() -> void:
	var launch: Dictionary = Session.get_meta("blankkitten_launch",{})
	Session.remove_meta("blankkitten_launch")
	if not launch.is_empty():
		seek_timestamp(float(launch.time),bool(launch.practice))
		return
	if OS.is_debug_build():
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--blankkitten-seek="):
				var value := arg.trim_prefix("--blankkitten-seek=")
				if value.is_valid_float(): seek_timestamp(value.to_float())

func _input(event: InputEvent) -> void:
	if not OS.is_debug_build() or game_over or victory_started: return
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed and event.shift_pressed:
		if event.keycode >= KEY_1 and event.keycode <= KEY_8:
			seek_timestamp(Cue.STARTS[event.keycode-KEY_1])

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
