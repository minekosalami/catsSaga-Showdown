extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+text)
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func _initialize() -> void:
	create_timer(45).timeout.connect(func(): quit(1))
	call_deferred("run")
func run() -> void:
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-cross-play.json"
	await session.new_game()
	session.evil_bart_defeated = true
	session.grant_flooded_key()
	await session.travel("flooded_forest","FromDeep")
	await session.begin_boss2_battle(Vector2(1840,450))
	var battle: Node = current_scene.battle
	var player: Node = battle.player
	var cross: Node = battle.timeline.cross
	battle.set_physics_process(false)
	# Real eight-direction inputs, original acceleration and focus speed. This
	# isolated cross test samples the music curve; the full-song test uses audio.
	# Approach from the real starting position during the warning/charge window.
	var safe_start: Vector2 = cross.pivot_center+Vector2.RIGHT.rotated(PI/4)*26
	for frame in range(96):
		battle.timeline.advance(70.4+frame/60.0)
		var desired: Vector2 = ((safe_start-player.hit_center())*6).limit_length(450)
		var best := Vector2.ZERO
		var cost := INF
		for candidate in [Vector2.ZERO,Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2(-1,-1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,1).normalized(),Vector2(1,1).normalized()]:
			var velocity: Vector2 = player.velocity.move_toward(candidate*450,(2200.0 if candidate == Vector2.ZERO else 1800.0)/60)
			var score: float = (player.hit_center()+velocity/60).distance_squared_to(safe_start)+velocity.distance_squared_to(desired)*0.003
			if score < cost:
				cost = score
				best = candidate
		key(KEY_LEFT,best.x < 0)
		key(KEY_RIGHT,best.x > 0)
		key(KEY_UP,best.y < 0)
		key(KEY_DOWN,best.y > 0)
		await physics_frame
	check(player.hit_center().distance_to(safe_start) < 10 and player.health == 3,"real movement reaches a safe quadrant from the starting position during telegraphing")
	key(KEY_SHIFT,true)
	var minimum := 3
	for frame in range(1057):
		var clock := 72.0+frame/60.0
		battle.timeline.advance(clock)
		battle.ui.update(clock)
		var angle: float = cross.angle_at(clock-72+1.0/60)+PI/4
		var target: Vector2 = cross.pivot_center+Vector2.RIGHT.rotated(angle)*26
		var desired_velocity: Vector2 = Vector2.DOWN.rotated(angle)*cross.velocity_at(clock-72)*26
		var best := Vector2.ZERO
		var best_cost := INF
		for candidate in [Vector2.ZERO,Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2(-1,-1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,1).normalized(),Vector2(1,1).normalized()]:
			var velocity: Vector2 = player.velocity.move_toward(candidate*150,(2200.0 if candidate == Vector2.ZERO else 1800.0)/60)
			var predicted: Vector2 = player.hit_center()+velocity/60
			var cost: float = predicted.distance_squared_to(target)+velocity.distance_squared_to(desired_velocity)*0.0004
			if cost < best_cost:
				best_cost = cost
				best = candidate
		key(KEY_LEFT,best.x < 0)
		key(KEY_RIGHT,best.x > 0)
		key(KEY_UP,best.y < 0)
		key(KEY_DOWN,best.y > 0)
		await physics_frame
		if player.health < minimum:
			print("ROUTE HIT clock=",clock," radius=",player.hit_center().distance_to(cross.pivot_center)," relative-angle=",wrapf((player.hit_center()-cross.pivot_center).angle()-cross.rotation,0,PI/2)," velocity=",player.velocity)
		minimum = mini(minimum,player.health)
		if battle.game_over: break
	for code in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_SHIFT]: key(code,false)
	check(not player.invincible and not player.unlimited_saturate,"survival route uses no cheats or health changes")
	check(minimum == 3 and not battle.game_over,"actual focused eight-direction movement survives the full 18 RPM cross without damage")
	check(battle.timeline.phase == 5 and not cross.active,"successful route reaches the 89.60-second shatter and finale")
	print("CROSS ROUTE MINIMUM HP: ",minimum)
	await session.main_menu()
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	print("CROSS PLAY VALIDATION: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
