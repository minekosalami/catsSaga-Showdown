extends SceneTree
const Cue = preload("res://scripts/blankkitten/timeline.gd")
var checks := 0
var failures := 0
var session: Node
func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(1))
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+message)
func press(key: Key, down := true, echo := false, seek := false) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = down
	event.echo = echo
	event.ctrl_pressed = seek
	event.shift_pressed = seek
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func code(word: String) -> void:
	for letter in word:
		press(letter.unicode_at(0))
		press(letter.unicode_at(0),false)
func freeze() -> Node:
	var game: Node = current_scene.battle
	for node in [game,game.player,game.hazards]: node.set_physics_process(false)
	return game
func run() -> void:
	session = root.get_node("Session")
	session.saves.save_path = "user://validation-sequence-overhaul.json"
	session.story_flags = {}
	session.encounter_active = true
	session.encounter_id = "blankkitten"
	await session.transition_to("res://scenes/blankkitten/combat_host.tscn",true)
	var game: Node = freeze()
	check(game.Cue.STARTS == [0.0,13.71,34.28,61.71,68.57,89.14,102.85,130.28] and game.Cue.END == 145.71,"exact timestamps unchanged")
	check(game.music_player.stream.resource_path.ends_with("catVibes - 004.mp3") and game.music_player.pitch_scale == 1,"original soundtrack and playback speed")
	code("CA")
	press(KEY_T,true,true)
	check(not game.player.invincible and game.player.cheat_progress == 2,"key echo cannot advance CATA")
	code("TA")
	check(game.player.invincible,"actual root CATA input toggles invincibility in Sequence")
	for stage in [1,2,4,5,6]:
		game.rebuild_clock(Cue.STARTS[stage]+1)
		var hp: int = game.player.health
		game.player.invulnerability = 0
		game.player.take_damage()
		check(game.player.health == hp,"CATA blocks damage in stage "+str(stage))
	code("CATA")
	check(not game.player.invincible,"second CATA toggles established behavior off")
	code("CA")
	press(KEY_LEFT)
	press(KEY_LEFT,false)
	code("TA")
	check(not game.player.invincible,"nonletter resets the cheat sequence")
	for stage in range(8):
		game.rebuild_clock(Cue.STARTS[stage])
		for direction in [Vector2.ONE,-Vector2.ONE,Vector2(1,-1),Vector2(-1,1)]:
			game.player.step(10,direction)
			var bounds: Rect2 = game.arena_rect.grow(-game.player.INNER_EDGE-game.player.RADIUS)
			check(game.player.position.x >= bounds.position.x and game.player.position.x <= bounds.end.x and game.player.position.y >= bounds.position.y and game.player.position.y <= bounds.end.y,"full visible star clamps inside stage "+str(stage))
		if Cue.GRAVITY[stage]:
			check(is_equal_approx(game.player.position.y+game.player.RADIUS,game.arena_rect.end.y-1),"bottom silhouette rests on inner floor surface")
	for wall_index in range(1,5):
		game.rebuild_clock(36)
		game.player.health = 5
		game.player.invulnerability = 0
		var shape: Dictionary = game.hazards.shapes_at(36)[wall_index]
		game.player.position = shape.rect.get_center()
		game.player.previous_position = game.player.position
		game.hazards.last_clock = 36
		game.hazards.advance(36,true)
		check(game.player.health == 4,"wall "+str(wall_index)+" contact deals immediate damage")
		game.hazards.advance(36.016,true)
		check(game.player.health == 4,"wall overlap shares standard post-hit invulnerability")
	game.rebuild_clock(36)
	game.player.position = game.hazards.ball_position(36)-Vector2(game.hazards.BALL_RADIUS+game.player.RADIUS+4,0)
	game.player.previous_position = game.player.position
	game.player.invulnerability = 0
	game.hazards.last_clock = 36
	var grazes: int = game.feedback.graze_count
	game.hazards.advance(36,true)
	check(game.feedback.graze_count == grazes+1,"real near miss emits cosmetic rainbow feedback")
	game.hazards.advance(36.01,true)
	check(game.feedback.graze_count == grazes+1,"near miss cooldown prevents per-frame bursts")
	game.rebuild_clock(68.57)
	game.advance_clock(68.80)
	check(game.ui.phase_title.label.text == "LASERS!" and game.ui.phase_title.label.visible and game.ui.phase_title.label.get_rect().end.y < game.arena_rect.position.y,"LASERS! announcement is exact and above the arena")
	game.rebuild_clock(89.14)
	for pair in game.hazards.jump_pairs():
		var warnings: Array = game.hazards.shapes_at(pair.start-.8).filter(func(p): return p.get("pair",-1) == pair.id and p.warning)
		check(warnings.size() == 2,"paired edge warnings appear a full 800ms before launch")
		var crossing: float = pair.start+(game.arena_rect.size.x/2+20)/pair.speed
		var pieces: Array = game.hazards.shapes_at(crossing).filter(func(p): return p.get("pair",-1) == pair.id)
		check(pieces.size() == 2,"one paired attack has exactly a floor and ceiling obstacle")
		if pieces.size() == 2:
			check(pieces[0].rect.position.x == pieces[1].rect.position.x and pieces[0].rect.size.x == pieces[1].rect.size.x,"pair shares horizontal position and travel speed")
			var gap: float = pieces[0].rect.position.y-pieces[1].rect.end.y
			check(is_equal_approx(gap,pair.gap),"rendered opening equals the authored collision opening")
	var flags: Dictionary = session.story_flags.duplicate(true)
	check(not game.seek_timestamp(-1) and not game.seek_timestamp(Cue.END),"seek rejects invalid timestamps")
	press(KEY_7,true,false,true)
	press(KEY_7,false,false,true)
	check(game.development_run and game.stage == 6 and is_equal_approx(game.elapsed_time,102.85),"Ctrl Shift 7 development shortcut seeks final stage")
	check(game.presentation.distortion == 3 and game.presentation.fire_strength == 1 and game.arena_rect == Cue.BOXES[6],"seek synchronizes art, fire, arena and stage")
	check(game.hazards.stage == 6 and game.hazards.ghosts.is_empty() and game.feedback.particles.is_empty(),"seek removes stale hazards and transient effects")
	game.advance_clock(Cue.END)
	check(game.victory_started and session.story_flags == flags and not game.ui.return_button.visible,"development preview cannot award progression")
	# Actual optional practice selector starts a new battle through the existing host.
	var old_id: int = current_scene.get_instance_id()
	session.set_meta("blankkitten_seen_stages",{4:true})
	game.ui.show_result(true)
	check(game.ui.practice_choice.get_selected_id() == 4,"practice selector identifies the encountered laser stage")
	game.ui.practice_button.pressed.emit()
	while current_scene == null or current_scene.get_instance_id() == old_id or session.busy: await process_frame
	game = freeze()
	check(game.practice_mode and game.stage == 4 and game.player.health == 5 and game.elapsed_time >= 68.57,"practice launches fresh full-health chosen stage")
	check(game.ui.stage_label.text.begins_with("PRACTICE"),"practice is clearly marked")
	check(not game.seek_timestamp(13.71,true),"practice refuses an unencountered stage")
	game.advance_clock(game.practice_end)
	check(game.victory_started and game.ui.result_label.text == "PRACTICE COMPLETE()" and session.story_flags == flags,"practice ends at stage boundary without rewards")
	check(not game.hazards.damaging and not game.ui.return_button.visible,"practice ending clears damage and uses appropriate navigation")
	check(game.ui.practice_choice.item_count == 1 and game.ui.practice_button.visible,"result shows only encountered practice stages")
	# Retry returns to a fresh ordinary encounter, with no lingering practice/debug state.
	old_id = current_scene.get_instance_id()
	game.ui.retry_button.pressed.emit()
	while current_scene == null or current_scene.get_instance_id() == old_id or session.busy: await process_frame
	game = freeze()
	check(not game.practice_mode and not game.development_run and game.stage == 0 and game.player.health == 5,"Retry restores ordinary full fight")
	game.ui.effects_toggle.button_pressed = true
	check(game.reduced_effects and bool(session.get_meta("blankkitten_reduced_effects",false)),"Reduced FX control updates encounter and session preference")
	game.advance_clock(105)
	check(game.presentation.background_viewport.size == Vector2i(135,225),"Reduced FX downsamples only soft atmosphere, keeping native collision / artwork / HUD")
	check(game.presentation.fire_material.get_shader_parameter("strength") < 1 and game.hazards.damaging,"Reduced FX lowers presentation without changing damaging hazards")
	game.rebuild_clock(120)
	var max_particles := 0
	for i in 100:
		game.feedback.impact(Vector2(270,740),1,120+i*.01)
		max_particles = maxi(max_particles,game.feedback.particles.size())
	check(max_particles <= 192 and game.feedback.cracks.size() <= 20 and game.feedback.voices.size() == 4,"particles / cracks / sound voices remain bounded")
	game.rebuild_clock(140)
	check(game.feedback.particles.is_empty() and game.feedback.cracks.is_empty() and not game.hazards.damaging,"ending seek clears all temporary damage and debris")
	game.advance_clock(Cue.END-.001)
	check(not game.victory_started,"full-fight ending never completes early")
	game.advance_clock(Cue.END)
	check(game.player.player_tint(Cue.END) == game.player.player_tint(Cue.END+1),"ending star settles into one stable vivid color")
	check(game.presentation.fire_strength == 0 and game.presentation.smoke_strength < .1,"ending resolves inferno and smoke")
	await session.main_menu()
	root.get_node("Music").play_theme("")
	await create_timer(.2).timeout
	print("SEQUENCE OVERHAUL: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
