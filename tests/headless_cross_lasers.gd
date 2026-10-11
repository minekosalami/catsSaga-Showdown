extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok: failures += 1
func _initialize() -> void:
	create_timer(65).timeout.connect(func(): quit(1))
	call_deferred("run")
func run() -> void:
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-cross-lasers.json"
	await session.new_game()
	var music: Node = root.get_node("Music")
	check(music.player.bus == "Overworld","overworld retains its dedicated EQ bus")
	var index := AudioServer.get_bus_index("Overworld")
	var eq: AudioEffectEQ6 = AudioServer.get_bus_effect(index,0)
	check(AudioServer.get_bus_effect_count(index) == 1 and is_equal_approx(eq.get_band_gain_db(2),-0.8) and is_equal_approx(eq.get_band_gain_db(5),1.2),"existing overworld EQ stays unchanged")
	session.evil_bart_defeated = true
	session.grant_flooded_key()
	await session.travel("flooded_forest","FromDeep")
	await session.begin_boss2_battle(Vector2(1840,450))
	var battle: Node = current_scene.battle
	var timeline: Node = battle.timeline
	var cross: Node = timeline.cross
	battle.set_physics_process(false)
	battle.player.set_physics_process(false)
	battle.player.invincible = true
	check(battle.music_player.bus == "Master","boss music bypasses overworld EQ")
	check(cross.start_time == 70.4 and cross.end_time == 89.6,"cross retains exact musical phase boundaries")
	check(is_equal_approx(cross.activation_time(),72.0),"0.8-second warning and 0.8-second charge precede damage")
	check(cross.beams.size() == 2 and is_equal_approx(cross.beams[1].rotation-cross.beams[0].rotation,PI/2),"two perpendicular beams form exactly four arms")
	check(cross.shapes.all(func(s): return s.shape.size == Vector2(1600,3)),"full-length geometry collides only along the three-pixel core")
	check(battle.player.damage_hitbox_radius == 7.5,"existing slightly larger player hitbox is retained without a second increase")
	for cue in [70.4,70.55,71.19]:
		timeline.advance(cue)
		battle.ui.update(cue)
		check(cross.warning and not cross.active and battle.ui.arena_overlay.warning_label.visible,"warning is visible and harmless at "+str(cue))
	check(battle.ui.arena_overlay.warning_label.text == "LASERS!" and battle.ui.dialogue_label.text == "NOW DIE!","warning contains exactly LASERS! with dialogue confined to HUD")
	battle.ui.update(70.55)
	check(battle.ui.arena_overlay.warning_label.scale.x > 1,"warning slams in with a slight overshoot")
	timeline.advance(71.2)
	battle.ui.update(71.2)
	check(cross.charging and not cross.active and not battle.ui.arena_overlay.warning_label.visible,"warning disappears before dangerous activation")
	for cue in [72.0,73.0,75.2,80.0,86.4,88.0,89.599]:
		timeline.advance(cue)
		check(cross.active and cross.position == cross.pivot_center,"fixed pivot remains active at "+str(cue))
		check(cross.angular_speed >= 0 and not timeline.lasers[0].active and get_nodes_in_group("boss2_projectiles").filter(func(p): return p.dangerous).is_empty(),"single-direction cross never stacks blue beams or normal bullets")
	check(is_equal_approx(cross.velocity_at(8)*60/TAU,18),"maximum speed is exactly 18 RPM")
	check(cross.velocity_at(0) == 0 and cross.velocity_at(17.6) == 0 and cross.velocity_at(1.6) < cross.velocity_at(3.2),"sine easing accelerates from rest and decelerates to rest")
	var t := 8.0
	var derivative: float = (cross.angle_at(t+0.0001)-cross.angle_at(t-0.0001))/0.0002
	check(absf(derivative-cross.velocity_at(t)) < 0.001,"closed-form rotation integrates actual angular velocity")
	var angle: float = cross.angle_at(12)
	cross.sample(88)
	cross.sample(76)
	cross.sample(84)
	check(is_equal_approx(cross.rotation,angle),"seeking produces the same pose independently of frame history")
	var point: Vector2 = cross.pivot_center+Vector2(200,18)
	check(not cross.swept_contact(point,point,72,72,7.5),"large red glow is harmless outside the thin core")
	point = cross.pivot_center+Vector2(200,8)
	check(cross.swept_contact(point,point,72,72,7.5),"visible white core plus actual player circle detects contact")
	# At max speed an arm sweeps through this far point entirely between poses.
	var from := 80.0
	var to := from+1.0/30
	point = cross.pivot_center+Vector2.RIGHT.rotated((cross.angle_at(from-72)+cross.angle_at(to-72))/2)*380
	check(cross.swept_contact(point,point,from,to,7.5),"fast cross detects a swept hit between rendered endpoint poses")
	timeline.advance(80.0)
	timeline.fire(Vector2.DOWN,200,Color.CYAN)
	check(get_nodes_in_group("boss2_projectiles").filter(func(p): return p.dangerous).is_empty(),"normal fire is explicitly blocked throughout the cross phase")
	timeline.advance(89.60)
	await physics_frame
	check(not cross.active and cross.shattering and cross.shatter_count == 1 and cross.fragments.size() == 64,"all four arms shatter at exactly 89.60")
	check(cross.shapes.all(func(s): return s.disabled) and cross.beams.all(func(b): return b.collision_layer == 0),"shattering immediately removes all damaging cross collisions")
	check(cross.fragments.any(func(p): return p.polygon.size() == 3) and cross.fragments.any(func(p): return p.polygon.size() == 5),"bounded glass fragments use varied angular polygons")
	timeline.advance(89.80)
	check(cross.visible and cross.shatter_count == 1 and timeline.phase == 5,"harmless shatter briefly continues into the clean finale exactly once")
	timeline.advance(90.11)
	check(not cross.visible and cross.fragments.is_empty(),"expired glass fragments clean up completely")
	timeline.clear_hostiles()
	cross.cancel()
	await physics_frame
	check(not cross.active and not cross.visible,"terminal cleanup cancels every cross effect")
	current_scene.retry()
	while session.busy: await process_frame
	await process_frame
	battle = current_scene.battle
	check(not battle.timeline.cross.active and battle.timeline.cross.fragments.is_empty() and battle.elapsed_time < 1,"Retry has fresh cross state and music at zero")
	await session.main_menu()
	check(music.player.bus == "Master","menu still bypasses overworld EQ")
	music.play_theme("")
	await create_timer(0.2).timeout
	print("CROSS LASER VALIDATION: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
