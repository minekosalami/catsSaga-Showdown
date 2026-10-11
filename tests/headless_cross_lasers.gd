extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok:
		failures += 1
func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	call_deferred("run")
func run() -> void:
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-cross-lasers.json"
	await session.new_game()
	var music: Node = root.get_node("Music")
	check(music.player.bus == "Overworld","only overworld themes route to dedicated EQ bus")
	var index := AudioServer.get_bus_index("Overworld")
	check(index > 0 and AudioServer.get_bus_effect_count(index) == 1,"Overworld has one adjustable bus EQ")
	var eq: AudioEffectEQ6 = AudioServer.get_bus_effect(index,0)
	check(is_equal_approx(eq.get_band_gain_db(2),-0.8) and is_equal_approx(eq.get_band_gain_db(4),0.8) and is_equal_approx(eq.get_band_gain_db(5),1.2),"EQ gently reduces muddiness and adds treble presence")
	check(is_equal_approx(AudioServer.get_bus_volume_db(index),-1.2),"EQ has modest headroom without increasing source volume")
	session.evil_bart_defeated = true
	session.grant_flooded_key()
	await session.travel("flooded_forest","FromDeep")
	await session.begin_boss2_battle(Vector2(1840,450))
	var battle: Node = current_scene.battle
	var timeline: Node = battle.timeline
	var cross: Node = timeline.cross
	battle.set_physics_process(false)
	battle.player.invincible = true
	check(battle.music_player.bus == "Master","boss soundtrack bypasses overworld EQ")
	check(cross.start_time == 70.4 and cross.end_time == 89.6,"cross belongs entirely to established hardest phase")
	check(is_equal_approx(cross.activation_time(),81.6),"default cross hands over after complete blue convergence")
	check(cross.beams.size() == 2 and cross.shapes.size() == 2,"one shared pivot owns exactly two beam colliders")
	check(is_equal_approx(cross.beams[1].rotation-cross.beams[0].rotation,PI/2),"beams remain exactly perpendicular")
	check(battle.player.damage_hitbox_radius == 7.5 and battle.player.get_node("CollisionShape2D").shape.radius == 7.5,"Boss2 inherits the slightly larger 7.5-pixel hitbox")
	check(battle.player.get_node("Sprite2D").position.is_equal_approx(battle.player.get_node("CollisionShape2D").position),"damage shape remains centered on original sprite")
	timeline.advance(70.4)
	battle.ui.update(70.55)
	check(battle.ui.phase_label.text == "NOW DIE!" and battle.ui.phase_label.visible,"NOW DIE appears automatically through the existing announcement UI")
	check(battle.ui.current_phase_label.text == "Convergence()" and battle.music_player.playing and not paused,"dialogue leaves music, persistent HUD and movement active")
	timeline.advance(71.7)
	check(timeline.lasers[0].active and not cross.active,"blue convergence is initially the sole laser hazard")
	timeline.advance(79.2)
	check(cross.warning and not cross.active and timeline.lasers[0].active,"red targeting begins without stacking damage")
	battle.player.invincible = false
	battle.player.invulnerability_timer = 0
	battle.player.position = cross.position-battle.player.get_node("CollisionShape2D").position
	await create_timer(0.06).timeout
	check(battle.player.health == 3,"cross targeting lines are non-damaging on direct contact")
	timeline.advance(80.0)
	check(cross.charging and not cross.active,"charging remains visual-only")
	await create_timer(0.06).timeout
	check(battle.player.health == 3,"cross charging glow does not damage")
	timeline.advance(81.61)
	check(cross.active and not timeline.lasers[0].active and not timeline.lasers[1].active,"cross activation disables both blue colliders")
	check(is_equal_approx(timeline.lasers[1].position.x-timeline.lasers[0].position.x-timeline.laser_width,timeline.resolved_gap),"blue convergence still reaches the original two-player stopping gap")
	battle.player.position = cross.to_global(Vector2(100,25))-battle.player.get_node("CollisionShape2D").position
	await physics_frame
	check(cross.shapes.all(func(shape): return not shape.disabled and shape.shape.size == Vector2(1600,24)),"red visual dangerous widths match both live rectangle colliders")
	await create_timer(0.06).timeout
	check(battle.player.health == 3,"decorative outer glow is outside actual laser damage geometry")
	battle.player.position = cross.position-battle.player.get_node("CollisionShape2D").position
	await create_timer(0.06).timeout
	check(battle.player.health == 2,"actual rotated cross collision subtracts one health at intersection")
	await create_timer(0.12).timeout
	check(battle.player.health == 2,"two simultaneous beam contacts respect existing i-frames")
	battle.player.invincible = true
	check(cross.velocity_at(0.4) > 0 and cross.velocity_at(1.95) < 0 and cross.velocity_at(3.55) > 0,"rotation alternates clockwise, counterclockwise, clockwise")
	check(absf(cross.velocity_at(6.0)) > absf(cross.velocity_at(0.4)),"current target speed gradually accelerates")
	check(absf(cross.velocity_at(1.60001)-cross.velocity_at(1.59999)) < 0.001,"reversal has continuous angular velocity")
	check(absf(cross.velocity_at(1.74)) < 0.001,"eased reversal passes through zero speed")
	var pose := Vector2.ZERO
	var angle := 0.0
	timeline.advance(86.4)
	pose = cross.position
	angle = cross.rotation
	timeline.advance(82.1)
	timeline.advance(86.4)
	check(cross.position.is_equal_approx(pose) and is_equal_approx(cross.rotation,angle),"formation is deterministic when seeking the same song position")
	check(cross.position.distance_to(cross.pivot_center) > 8 and cross.pivot_bounds.has_point(cross.position),"moving pivot follows bounded path without player tracking")
	check(cross.pivot_at(0).distance_to(cross.pivot_at(0.001)) < 0.01,"pivot starts with eased motion and no teleport")
	check(get_nodes_in_group("boss2_projectiles").size() > 0,"normal bullets continue during rotating cross")
	# Check reachable safe cells for the laser formation at 0.1-song-second steps.
	# This geometric test excludes normal bullets and is not human fairness proof.
	var reachable: Array[Vector2] = []
	for x in range(30,520,20):
		for y in range(290,870,20):
			reachable.append(Vector2(x,y))
	for step in range(77):
		var t := 81.6+step*0.1
		cross.sample(t)
		var next_cells: Array[Vector2] = []
		for x in range(30,520,20):
			for y in range(290,870,20):
				var point := Vector2(x,y)
				var local: Vector2 = (point-cross.position).rotated(-cross.rotation)
				if absf(local.x) <= 19.5 or absf(local.y) <= 19.5:
					continue
				for previous in reachable:
					if point.distance_squared_to(previous) <= 45*45:
						next_cells.append(point)
						break
		reachable = next_cells
	check(not reachable.is_empty(),"laser-only grid retains a reachable route at actual 450-pixel player speed")
	timeline.advance(89.20)
	check(not cross.active and cross.shattering and cross.fragments.size() == cross.fragment_count,"both beams break into bounded visual fragment array at 89.20")
	await physics_frame
	check(cross.shapes.all(func(shape): return shape.disabled),"all red colliders disable immediately when shattering starts")
	check(cross.get_child_count() == 2 and cross.fragments.all(func(piece): return piece.polygon.size() >= 3),"varied angular shards add no physics or particle nodes")
	check(cross.fragments.any(func(piece): return piece.polygon.size() == 3) and cross.fragments.any(func(piece): return piece.polygon.size() == 4) and cross.fragments.any(func(piece): return piece.polygon.size() == 5),"glass shards mix triangles and varied irregular polygons")
	var shatters: int = cross.shatter_count
	timeline.advance(89.3)
	check(cross.shatter_count == shatters,"shattering triggers once during uninterrupted phase")
	battle.player.invincible = false
	battle.player.invulnerability_timer = 0
	battle.player.position = cross.position-battle.player.get_node("CollisionShape2D").position
	var hp: int = battle.player.health
	await create_timer(0.08).timeout
	check(battle.player.health == hp,"shards are non-damaging even at former intersection")
	timeline.advance(89.6)
	await physics_frame
	check(timeline.phase == 5 and not cross.visible and cross.fragments.is_empty() and cross.shapes.all(func(shape): return shape.disabled),"finale boundary removes fragments and all cross collisions")
	cross.start_time = 84.0
	timeline.advance(83.9)
	check(not cross.visible and not cross.active,"editable cross start delays warning and damage within the phase")
	timeline.advance(84.0)
	check(cross.warning and is_equal_approx(cross.activation_time(),86.4),"warning and activation settings remain relative to the configured start")
	cross.start_time = 70.4
	cross.activation_duration = 1.0
	timeline.advance(82.7)
	check(cross.shattering and not cross.active and is_equal_approx(cross.break_time(),82.6),"configurable active duration starts a safe early shatter")
	cross.activation_duration = 7.6
	timeline.advance(85.0)
	timeline.clear_hostiles()
	await physics_frame
	check(not cross.active and not cross.visible and cross.shapes.all(func(shape): return shape.disabled),"defeat/victory cleanup removes cross instantly")
	current_scene.retry()
	while session.busy:
		await process_frame
	await process_frame
	battle = current_scene.battle
	check(not battle.timeline.cross.active and battle.timeline.cross.fragments.is_empty() and battle.elapsed_time < 1,"Retry has fresh cross state and music clock")
	await session.main_menu()
	check(music.player.bus == "Master","menu music bypasses the dedicated overworld EQ")
	music.play_theme("")
	await create_timer(0.2).timeout
	print("CROSS LASER VALIDATION: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
