extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ")+text)
	if not ok:
		failures += 1
func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	call_deferred("run")
func run() -> void:
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-battle-visuals.json"
	await session.new_game()
	session.evil_bart_defeated = true
	session.grant_flooded_key()
	await session.travel("flooded_forest","FromDeep")
	await session.begin_boss2_battle(Vector2(1840,450))
	var game: Node = current_scene.battle
	var timeline: Node = game.timeline
	var hud: Node = game.ui
	var sprite: Sprite2D = timeline.boss
	game.player.invincible = true
	game.set_physics_process(false)
	sprite.set_process(false)
	check(sprite.texture.resource_path.ends_with("bosstwo.png"),"Boss2 keeps the authorized shared original image")
	check(sprite.beats_per_minute == 150 and sprite.beats_per_measure == 4,"pulse defaults to 150 BPM and 4/4")
	var scale0: Vector2 = sprite.rest_scale
	var origin0: Vector2 = sprite.position
	sprite.apply_clock(0)
	check(sprite.scale.is_equal_approx(scale0),"pulse starts at 100% on downbeat")
	sprite.apply_clock(0.06)
	check(sprite.scale.is_equal_approx(scale0*1.06),"pulse reaches exactly 106% with smooth attack")
	sprite.apply_clock(0.4)
	check(sprite.scale.is_equal_approx(scale0),"pulse smoothly settles before the next beat")
	sprite.apply_clock(1.66)
	check(sprite.scale.is_equal_approx(scale0*1.06),"measure pulse repeats every 1.6 song seconds")
	sprite.apply_clock(0.8)
	check(absf(sprite.float_pixels-8) < 0.001 and absf(sprite.offset.y*sprite.scale.y-8) < 0.001,"floating crest is eight internal pixels")
	sprite.apply_clock(2.4)
	check(absf(sprite.float_pixels+8) < 0.001,"floating trough is negative eight pixels")
	sprite.apply_clock(3.2)
	check(absf(sprite.float_pixels) < 0.001,"floating completes its 3.2-second cycle")
	sprite.apply_clock(1.66)
	check(sprite.scale.x > scale0.x and sprite.float_pixels != 0 and sprite.position == origin0,"pulse and floating coexist without moving the gameplay position")
	check(is_equal_approx(sprite.scale.x/sprite.scale.y,scale0.x/scale0.y),"pulse preserves original aspect ratio")
	sprite.downbeat_offset = 0.2
	sprite.apply_clock(0.1)
	check(sprite.scale.is_equal_approx(scale0),"no pulse before configurable downbeat offset")
	sprite.apply_clock(0.26)
	check(sprite.scale.is_equal_approx(scale0*1.06),"offset shifts pulse peak precisely")
	sprite.downbeat_offset = 0
	sprite.pulse_amount = 0
	sprite.float_amplitude = 0
	sprite.apply_clock(9.0)
	check(sprite.scale.is_equal_approx(scale0) and sprite.offset == sprite.rest_offset,"both sprite effects can be disabled")
	sprite.pulse_amount = 0.06
	sprite.float_amplitude = 8
	check(timeline.difficulty_multiplier == 1.25,"Boss2 defaults to moderate 1.25 difficulty")
	timeline.difficulty_multiplier = 1.0
	timeline.advance(12.8)
	var original_count: int = get_nodes_in_group("boss2_projectiles").size()
	var original_speed: float = get_nodes_in_group("boss2_projectiles")[0].speed
	timeline.advance(13.77)
	check(timeline.attack_index == 0,"baseline cadence remains recoverable at multiplier 1.0")
	timeline.clear_hostiles()
	await physics_frame
	timeline.difficulty_multiplier = 1.25
	timeline.phase = -1
	timeline.advance(12.8)
	check(get_nodes_in_group("boss2_projectiles").size() > original_count,"higher difficulty increases opening circular density")
	check(is_equal_approx(get_nodes_in_group("boss2_projectiles")[0].speed,original_speed*1.1),"higher difficulty increases projectile speed by exactly ten percent")
	timeline.advance(13.77)
	check(timeline.attack_index == 1,"higher difficulty advances firing cadence by 25 percent")
	timeline.clear_hostiles()
	await physics_frame
	timeline.advance(85.0)
	var left: Node = timeline.lasers[0]
	var right: Node = timeline.lasers[1]
	var left0: Vector2 = left.position
	var spawn0: Vector2 = sprite.position+Vector2(0,55)
	for clock in [85.0,85.06,85.8]:
		sprite.apply_clock(clock)
		check(sprite.position+Vector2(0,55) == spawn0 and left.position == left0,"sprite animation keeps laser formation and projectile origin stable at "+str(clock))
	check(timeline.cross.position == timeline.cross.pivot_center and not left.active and not right.active,"fixed cross is independent of inactive blue formation")
	check(left.collision.shape.size == Vector2(20,630) and left.collision.position.y == 585,"redesigned laser body preserves exact collision geometry")
	timeline.advance(38.40)
	check(left.warning and not left.active,"blue warnings remain non-damaging at exact assault boundary")
	timeline.advance(39.601)
	check(left.active and not left.warning,"warning ends at original 1.2-second activation boundary (first sample after it)")
	var time0: float = left.activation_clock
	timeline.advance(39.9)
	check(left.activation_clock == time0,"visual energy ramp does not restart during active movement")
	for cue in [12.80,38.40,64.00,70.40,89.60]:
		timeline.advance(cue)
		hud.update(cue)
		check(hud.phase_transition.cue_time == cue and hud.current_phase_label.text == timeline.PHASES[timeline.phase],"phase title and persistent caption track exact cue "+str(cue))
		check(absf(hud.song_progress.value-cue) < 0.002 and hud.song_progress.max_value == 140.8,"survival progress uses song playback at "+str(cue))
		check(game.music_player.playing and not paused and game.player.process_mode != Node.PROCESS_MODE_DISABLED,"transition leaves audio and movement active at "+str(cue))
	hud.update(38.4)
	check(hud.timer_label.text == "01:42.40","remaining timer is derived from soundtrack position")
	hud.update(140.8)
	check(hud.timer_label.text == "00:00.00" and hud.song_progress.value == hud.song_progress.max_value,"survival timer and progress clamp at the ending")
	check(hud.find_children("*Boss*","ProgressBar",true,false).is_empty(),"survival HUD has no boss HP bar")
	hud.phase_transition.update_clock(89.7)
	check(not hud.phase_label.visible,"compact phase caption avoids covering the arena")
	hud.phase_transition.update_clock(91.0)
	check(not hud.phase_label.visible,"transient phase title hides without removing persistent current phase")
	game.player.health = 2
	hud.update(91)
	check(hud.health_label.text.count("●") == 2 and is_instance_valid(hud.health_tween),"survival health feedback animates actual player health changes")
	timeline.clear_hostiles()
	await physics_frame
	for style in range(4):
		var bullet: Node = load("res://scenes/enemybullet.tscn").instantiate()
		bullet.visual_style = style
		bullet.direction = Vector2.ZERO
		game.add_child(bullet)
		bullet.position = Vector2(80+style*35,450)
		check(bullet.body_radius == bullet.RADII[style] and bullet.get_node("CollisionShape2D").shape.radius == bullet.body_radius and bullet.get_child_count() == 1,"bullet style "+str(style)+" preserves dangerous radius with no extra visual nodes")
		bullet.queue_free()
	await session.new_game()
	await session.travel("bart_area","FromDeep")
	await session.begin_battle(Vector2(1000,520))
	game = current_scene.battle
	game.music_player.seek(7)
	await create_timer(0.12).timeout
	check(game.boss.health == 300 and game.ui.boss_bar.max_value == 300,"Bart still starts at exactly 300 HP with accurate bar")
	check(game.ui.phase_transition.get_script() == hud.phase_transition.get_script() if is_instance_valid(hud) else game.ui.phase_transition.get_script().resource_path.ends_with("battle_phase_transition.gd"),"both fights reuse the same phase presentation component")
	game.boss.take_damage(30)
	await create_timer(0.22).timeout
	check(game.boss.health == 270 and absf(game.ui.boss_bar.value-270) < 0.1,"Bart health bar eases to real damage without changing HP mechanics")
	check(game.ui.saturate_label.text.contains("READY"),"Bart preserves SATURATE availability HUD")
	await session.main_menu()
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	print("BATTLE VISUAL VALIDATION: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
