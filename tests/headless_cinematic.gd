extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+message)
func _initialize() -> void:
	create_timer(80).timeout.connect(func(): quit(1))
	call_deferred("run")
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func verify_presentation(battle: Node, name: String) -> void:
	var stage: Node = battle.get_node("CinematicArena")
	check(stage.look.boss_name == name,"shared profile names "+name)
	check(stage.title.label.text == "Showdown: "+name,"reusable introduction uses the profile's boss name")
	check(stage.title.mouse_filter == Control.MOUSE_FILTER_IGNORE,"introduction ignores gameplay input")
	check(stage.title.size == Vector2(540,900),"introduction anchors to the actual portrait arena")
	check(stage.motes.size() == 36,"bounded ambient motes use one background canvas")
	check(stage.z_index < 0 and stage.environment.get_child_count() == 0,"environment stays below actors and creates no physics bodies")
	var audio: AudioStreamPlayer = battle.music_player
	var physics: CollisionShape2D = battle.player.get_node("CollisionShape2D")
	var transform: Transform2D = physics.global_transform
	var radius: float = physics.shape.radius
	for time in [0.0,0.15,0.35,0.8,1.15,1.5,1.75,2.0]:
		stage.update_clock(time)
		check(stage.title.visible == (time < 1.75),"introduction visibility at "+str(time))
		check(physics.global_transform == transform and physics.shape.radius == radius,"visual sampling leaves player collision unchanged at "+str(time))
	check(is_equal_approx(stage.title.opacity,0),"title fades completely at the end")
	check(audio.playing and not paused and battle.player.process_mode != Node.PROCESS_MODE_DISABLED,"title never suspends music, movement or battle")
	var profile: Resource = stage.look
	for cue in profile.cues:
		var before: float = profile.stage_at(cue-0.001)
		var at: float = profile.stage_at(cue)
		check(absf(before-at) < 0.002,"environment transition is continuous at existing cue "+str(cue))
	stage.update_clock(profile.final_phase_time+2.1)
	check(stage.stage >= 0.899,"surreal final arena starts at the existing final phase")
	var visuals: Node = battle.player.get_node("CinematicPlayerVisual")
	var player_position: Vector2 = battle.player.position
	var velocity: Vector2 = battle.player.velocity
	key(KEY_SHIFT,true)
	visuals._process(0.16)
	check(is_equal_approx(visuals.focus_alpha,1),"focus brackets ease in over 160 ms")
	key(KEY_SHIFT,false)
	visuals._process(0.16)
	check(is_equal_approx(visuals.focus_alpha,0),"focus brackets ease out over 160 ms")
	check(battle.player.position == player_position and battle.player.velocity == velocity and physics.global_transform == transform,"idle/focus presentation only animates the artwork child")
	stage.effect_strength = 0
	stage.update_clock(profile.final_phase_time+2.1)
	check(stage.environment.stage == 0 and stage.pulse == 0,"Inspector effect intensity disables distortion and pulses")
	stage.effect_strength = 0.7
func run() -> void:
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-cinematic.json"
	await session.new_game()
	await session.travel("bart_area","FromDeep")
	await session.begin_battle(Vector2(1000,520))
	var game: Node = current_scene.battle
	game.player.invincible = true
	await process_frame
	verify_presentation(game,"Evil Bart")
	check(not game.boss_spawned,"visual introduction does not spawn Bart early")
	game.music_player.seek(7)
	await create_timer(0.15).timeout
	check(game.boss_spawned and game.boss.health == 300,"music still spawns Bart with exactly 300 HP")
	var boss: Node = game.boss
	var center: Vector2 = boss.get_node("CollisionShape2D").global_position
	game.set_process(false)
	boss.set_process(false)
	var stage: Node = game.get_node("CinematicArena")
	stage.update_clock(92)
	stage._process(0.02)
	check(boss.get_node("CollisionShape2D").global_position == center,"boss float and glow leave the hitbox unchanged")
	boss.take_damage(30)
	check(boss.health == 270 and stage.boss_flash == 1,"real boss damage drives a decorative flash")
	boss.take_damage(270)
	await create_timer(0.9).timeout
	check(game.victory_started and game.ui.victory_screen.visible,"Bart defeat still triggers one victory sequence")
	check(game.ui.victory_screen.get_child(0).get_script().resource_path.ends_with("cinematic_result.gd"),"Bart victory uses the shared animated backdrop")
	var previous_scene := current_scene
	game.ui.victory_retry.pressed.emit()
	while current_scene == previous_scene or session.busy: await process_frame
	await process_frame
	game = current_scene.battle
	check(game.player.health == 3 and not game.victory_started,"Retry creates a fresh battle")
	await session.main_menu()
	check(current_scene.scene_file_path == "res://scenes/main_menu.tscn","Main Menu navigation remains functional")
	await session.new_game()
	session.evil_bart_defeated = true
	session.grant_flooded_key()
	await session.travel("flooded_forest","FromDeep")
	await session.begin_boss2_battle(Vector2(1840,450))
	game = current_scene.battle
	game.player.invincible = true
	await process_frame
	verify_presentation(game,"Doppelcat")
	check(not game.ui.dialogue_label.visible,"no technical placeholder appears in the battle HUD")
	game.introductory_dialogue = "An authored introduction."
	game.ui.update(0.5)
	check(game.ui.dialogue_label.visible and game.ui.dialogue_label.text == game.introductory_dialogue,"actual authored introductory dialogue still displays automatically")
	check(game.end_time == 140.8 and game.timeline.cross.maximum_rpm == 18,"survival duration and 18 RPM are preserved")
	check(game.timeline.cross.core_width == 3 and game.player.damage_hitbox_radius == 7.5,"cross and player damage shapes are unchanged")
	game.player.activate_saturate()
	game.player.shoot()
	check(not game.player.saturate_used and game.get_children().filter(func(c): return c.scene_file_path == "res://scenes/rainbow_beam.tscn").is_empty(),"survival fight keeps SATURATE and shooting disabled")
	game.elapsed_time = 20
	game.finish_survival()
	check(not game.victory_started,"visual phases cannot complete survival early")
	game.elapsed_time = game.end_time
	game.finish_survival()
	check(game.victory_started and game.ui.end_screen.visible,"existing 140.80-second ending opens the victory screen")
	check(game.ui.end_screen.get_script().resource_path.ends_with("cinematic_result.gd"),"Doppelcat victory shares the Bart backdrop component")
	check(game.music_player.playing and is_instance_valid(game.audio_fade),"existing music fade runs behind the victory presentation")
	await create_timer(0.9).timeout
	check(not game.music_player.playing,"remaining soundtrack still fades and stops gracefully")
	game.ui.return_button.get_parent().get_child(2).pressed.emit()
	while session.busy: await process_frame
	await process_frame
	game = current_scene.battle
	check(game.player.health == 3 and not game.victory_started,"Doppelcat Retry starts a fresh survival fight")
	game.player.invincible = false
	game.player.invulnerability_timer = 0
	game.player.take_damage(3)
	await process_frame
	check(game.game_over and game.ui.result_label.text == "GAME OVER()","real defeat uses the shared result typography")
	check(game.ui.end_screen.visible and not game.ui.return_button.visible,"defeat preserves valid navigation actions")
	await session.main_menu()
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	print("CINEMATIC VALIDATION: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
