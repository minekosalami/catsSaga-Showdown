extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok: failures += 1
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func _initialize() -> void:
	create_timer(70).timeout.connect(func(): quit(1))
	call_deferred("run")
func run() -> void:
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-boss2-overhaul.json"
	await session.new_game()
	session.evil_bart_defeated = true
	session.grant_flooded_key()
	await session.travel("flooded_forest","FromDeep")
	await session.begin_boss2_battle(Vector2(1840,450))
	var battle: Node = current_scene.battle
	var player: Node = battle.player
	var timeline: Node = battle.timeline
	battle.set_physics_process(false)
	check(current_scene.arena.size == Vector2i(540,900) and player.health == 3 and player.stamina == 1,"new fight retains portrait arena, three HP and full stamina")
	check(battle.music_player.playing and battle.end_time == 140.8,"original soundtrack starts and retains approved ending")
	player.shoot()
	player.activate_saturate()
	check(not player.saturate_used and get_nodes_in_group("player_bullets").is_empty(),"Boss2 remains survival-only")
	key(KEY_RIGHT,true)
	key(KEY_X,true)
	await create_timer(0.65).timeout
	check(absf(player.velocity.length()-810) < 0.1 and player.sprinting,"actual X movement reaches exactly 1.8 times normal speed")
	check(not battle.effects.ghosts.is_empty() and battle.effects.ghosts.size() <= 12,"sprint produces bounded collision-free white afterimages")
	key(KEY_X,false)
	await physics_frame
	await physics_frame
	check(player.velocity.length() <= 450.1 and not player.sprinting,"X release immediately caps sprint momentum to normal speed")
	key(KEY_X,true)
	key(KEY_SHIFT,true)
	await create_timer(0.1).timeout
	check(player.velocity.length() <= 150.1 and not player.sprinting and player.get_node("HitboxDebug").visible,"Shift takes priority over X and displays actual focus hitbox")
	key(KEY_X,false)
	key(KEY_SHIFT,false)
	key(KEY_RIGHT,false)
	# An actual protected crossing, using movement and the real blue collider.
	player.position = Vector2(160,700)-player.get_node("CollisionShape2D").position
	player.previous_hit_center = player.hit_center()
	player.velocity = Vector2(450,0)
	player.stamina = 1
	player.sprint_cooldown = 0
	player.sprint_protection = 0
	timeline.lasers[0].present(200,true,false,Rect2(),42)
	key(KEY_RIGHT,true)
	key(KEY_X,true)
	await create_timer(0.11).timeout
	check(player.hit_center().x > 210 and player.health == 3 and player.protected_crossings > 0,"real sprint crosses a damaging blue core with activation protection and white sparks")
	key(KEY_RIGHT,false)
	key(KEY_X,false)
	timeline.lasers[0].present(200,false,false,Rect2(),42.2)
	player.set_physics_process(false)
	player.set_process(false)
	player.stamina = 1
	player.exhausted_until_release = false
	for i in range(300): player.update_sprint(1.0/60,true,false)
	check(is_zero_approx(player.stamina),"full stamina lasts exactly five seconds")
	for i in range(180): player.update_sprint(1.0/60,false,false)
	check(is_equal_approx(player.stamina,1),"empty stamina fully recharges in three seconds")
	player.stamina = 0.1
	player.update_sprint(0.01,true,false)
	check(player.sprinting and player.stamina > 0,"partial stamina permits ordinary sprinting below protection threshold")
	player.sprint_cooldown = 0
	check(not player.try_protected_activation(false),"less than twenty percent stamina cannot grant activation protection")
	player.stamina = 0.2
	check(player.try_protected_activation(false) and is_equal_approx(player.sprint_protection,0.2),"fresh X with twenty percent stamina grants exactly 0.2 seconds")
	check(not player.try_protected_activation(false),"release/repress cannot bypass protection cooldown")
	player.update_sprint(0.201,false,false)
	check(player.sprint_protection == 0 and player.sprint_cooldown > 0,"protection ends while the separate 0.6-second cooldown continues")
	player.update_sprint(0.4,false,false)
	check(player.sprint_cooldown == 0 and player.try_protected_activation(false),"protected activation becomes available after 0.6 seconds")
	player.sprint_cooldown = 0
	check(not player.try_protected_activation(true),"focus cannot activate sprint protection")
	player.invulnerability_timer = 0
	player.sprint_protection = 0.2
	player.take_damage(1)
	check(player.health == 3,"activation protection blocks projectile damage")
	var crossings0: int = player.protected_crossings
	player.laser_spark_cooldown = 0
	player.notify_laser_contact(player.hit_center())
	check(player.protected_crossings == crossings0+1 and not battle.effects.particles.is_empty(),"protected laser contact gives white sparks")
	player.sprint_protection = 0
	player.take_damage(1)
	check(player.health == 2 and is_equal_approx(player.invulnerability_timer,1.5),"valid hit removes one HP and grants exactly 1.5 seconds")
	check(battle.hit_effect_time == 0.16 and battle.shake_strength == 4 and battle.music_player.playing,"damage feedback is brief and leaves audio playing")
	player.take_damage(1)
	check(player.health == 2,"overlapping damage cannot remove a second HP during protection")
	player.health = 3
	player.invulnerability_timer = 0
	player.invincible = true
	player.position = Vector2(20,20)-player.get_node("CollisionShape2D").position
	player.previous_hit_center = player.hit_center()
	timeline.advance(12.8)
	check(is_equal_approx(get_nodes_in_group("boss2_projectiles")[0].speed,115*1.1*1.3),"normal projectile speed increases thirty percent without changing difficulty density")
	timeline.clear_hostiles()
	await physics_frame
	var projectile: Node = load("res://scenes/boss2/projectile.tscn").instantiate()
	projectile.position = Vector2(100,100)
	projectile.direction = Vector2.RIGHT
	battle.add_child(projectile)
	projectile.set_physics_process(false)
	player.position = Vector2(150,120)-player.get_node("CollisionShape2D").position
	player.previous_hit_center = player.hit_center()
	var graze0: int = battle.effects.graze_count
	var stamina0: float = player.stamina
	projectile.test_segment(Vector2(100,100),Vector2(200,100))
	projectile.test_segment(Vector2(100,100),Vector2(200,100))
	check(battle.effects.graze_count == graze0+1 and player.health == 3 and player.stamina == stamina0,"near miss grazes once without healing or stamina rewards")
	projectile.queue_free()
	timeline.advance(38.4)
	check(timeline.lasers[0].warning and timeline.lasers[0].warning_span.size.x == timeline.laser_width,"blue warning matches actual narrow beam width")
	timeline.advance(39.601)
	check(timeline.lasers[0].active and timeline.lasers[0].collision.shape.size.x == 20,"blue laser activates after full 1.2-second telegraph")
	player.position = Vector2(20,20)-player.get_node("CollisionShape2D").position
	player.previous_hit_center = player.hit_center()
	timeline.advance(64)
	await physics_frame
	check(get_nodes_in_group("boss2_ricochets").size() == 7 and not timeline.lasers[0].active,"64-second boundary replaces blue assault with boss-fired ricochet fan")
	for cue in [65.6,67.2,68.8]: timeline.advance(cue)
	check(get_nodes_in_group("boss2_ricochets").size() == 28,"four musical volleys peak at twenty-eight ricochets")
	var ric: Node = get_nodes_in_group("boss2_ricochets")[0]
	ric.set_physics_process(false)
	ric.position = Vector2(520,400)
	ric.direction = Vector2.RIGHT
	ric.move_reflecting(0.2)
	check(ric.direction.x < 0 and ric.position.x < 533.5 and is_equal_approx(ric.speed,288),"right-wall impact reflects inward and reduces speed ten percent")
	for i in range(20): ric.reflect(Vector2.RIGHT)
	check(ric.bounce_count > 20 and is_equal_approx(ric.speed,160) and ric.dangerous,"unlimited reflections stay dangerous and stop slowing at half original speed")
	ric.position = Vector2(300,400)
	ric.direction = Vector2.RIGHT
	ric.move_reflecting(30)
	check(ric.position.x >= 6.5 and ric.position.x <= 533.5 and ric.bounce_count > 25,"large motion step processes multiple impacts without escaping or sticking")
	var old: Node = get_nodes_in_group("boss2_ricochets")[0]
	timeline.fire_ricochet_volley(4)
	check(not old.dangerous and get_nodes_in_group("boss2_ricochets").filter(func(p): return p.dangerous).size() == 30,"soft cap harmlessly dissolves oldest projectiles without limiting bounces")
	battle.ui.update(65)
	check(battle.ui.dialogue_label.text == "You're stronger than you look. But how long can you survive?" and battle.music_player.playing and not paused,"ricochet dialogue runs automatically alongside attack and audio")
	var remaining: Array = get_nodes_in_group("boss2_ricochets")
	timeline.advance(70.4)
	check(remaining.all(func(p): return not p.dangerous and p.collision_layer == 0),"70.40 immediately makes every remaining ricochet harmless")
	check(battle.effects.particles.size() <= 256 and battle.effects.particles.any(func(p): return p.shard),"ricochet ending uses bounded colorful visual shards")
	await physics_frame
	check(get_nodes_in_group("boss2_ricochets").is_empty() and timeline.cross.warning,"ricochet fully clears before cross activation")
	battle.ui.update(70.6)
	await process_frame
	await process_frame
	check(battle.ui.top_margin.size.y < 120 and timeline.boss.position.y-83 > battle.ui.top_margin.position.y+battle.ui.top_margin.size.y,"compact HUD and automatic dialogue do not overlap boss")
	check(battle.ui.stamina_bar.name == "SprintStamina" and battle.ui.find_children("*Boss*","ProgressBar",true,false).is_empty(),"survival HUD contains stamina and no invented boss health")
	check(battle.find_children("*","Label",true,false).all(func(l): return not l.text.contains("OFFENSE DISABLED")),"large survival footer is removed")
	# Continuous bullet collision detects a high-speed pass through the hit circle.
	timeline.clear_hostiles()
	player.invincible = false
	player.invulnerability_timer = 0
	player.sprint_protection = 0
	player.position = Vector2(200,500)-player.get_node("CollisionShape2D").position
	player.previous_hit_center = player.hit_center()
	projectile = load("res://scenes/boss2/projectile.tscn").instantiate()
	projectile.position = Vector2(100,500)
	battle.add_child(projectile)
	projectile.set_physics_process(false)
	projectile.test_segment(Vector2(100,500),Vector2(300,500))
	check(player.health == 2 and not projectile.dangerous,"swept projectile collision catches a hit entirely between movement endpoints")
	player.invulnerability_timer = 0
	player.take_damage(1)
	player.invulnerability_timer = 0
	player.take_damage(1)
	check(player.health == 0 and battle.game_over and not battle.victory_started,"three valid one-HP hits trigger defeat without victory")
	check(not timeline.cross.active and timeline.lasers.all(func(l): return not l.active),"death immediately stops all damaging hazards")
	await create_timer(0.9).timeout
	check(not battle.music_player.playing,"defeat fades music even while the death screen pauses gameplay")
	current_scene.retry()
	while session.busy: await process_frame
	await process_frame
	check(current_scene.name=="Overworld" and not session.encounter_active,"death Retry restores manual save or fresh entrance when not yet saved")
	await session.transition_to("res://scenes/boss2/combat_host.tscn",true)
	battle = current_scene.battle
	check(battle.player.health == 3 and battle.player.stamina == 1 and battle.player.sprint_cooldown == 0 and battle.elapsed_time < 1,"Retry resets HP, stamina, protection cooldown and audio clock")
	check(battle.timeline.phase == 0 and battle.effects.particles.is_empty() and battle.timeline.cross.fragments.is_empty(),"Retry starts at introduction without leftover attacks or effects")
	await session.main_menu()
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	print("BOSS2 OVERHAUL VALIDATION: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
