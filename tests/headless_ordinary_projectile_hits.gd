extends SceneTree
## Exercise the real shared player bullet and physics signals, never direct damage.
const Catalog = preload("res://scripts/encounters/catalog.gd")
var checks := 0
var failures := 0
var session: Node

func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE") != "1" or OS.get_environment("XDG_DATA_HOME").is_empty():
		quit(1)
		return
	create_timer(240, true, false, true).timeout.connect(func():
		push_error("Projectile collision tests timed out")
		quit(1))
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func shoot(battle: Node) -> Area2D:
	# Spawn via the existing player weapon, below the moving target, so the
	# bullet must travel into its shape and emit area_entered through physics.
	battle.player.position = battle.boss.position + Vector2(0, 110)
	battle.player.shoot()
	return battle.get_child(battle.get_child_count() - 1) as Area2D

func settle() -> void:
	await process_frame
	while session.busy:
		await process_frame

func wait_for_impact(bullet: Area2D) -> void:
	# Wait for actual physics, including signal delivery/deferred deletion, rather
	# than assuming a render-frame timer also completed the collision step.
	for frame in 24:
		await physics_frame
		if not is_instance_valid(bullet): break
	await process_frame
	await process_frame

func run() -> void:
	session = root.get_node("Session")
	await session.new_game(2)
	while not current_scene.encounters.loaded:
		await process_frame
	# Confirm the working boss and the shared weapon's existing layer contract.
	var smoki := preload("res://scenes/boss.tscn").instantiate()
	var shared_bullet := preload("res://scenes/bullet.tscn").instantiate()
	check((smoki.collision_layer & shared_bullet.collision_mask) != 0,
		"Smoki is detectable by the unchanged shared player projectile")
	smoki.free()
	shared_bullet.free()
	for kind in 8:
		session.rpg.restore({}) # Keep this physics regression at LV1 for every kind.
		var world: Node = current_scene
		world.encounters.set_process(false)
		session.forest_encounters.population[0] = {"kind": kind, "position": Vector2(1000, 912), "home": Vector2(1100, 912), "alive": true, "retreat": false, "ignore_until": 0.0}
		session.forest_encounters.active = {"id": 0, "kind": kind, "area": session.area_id, "position": world.player.position, "settled": false}
		session.encounter_active = true
		session.encounter_id = "ordinary"
		await session.transition_to("res://scenes/encounters/combat_host.tscn", true)
		var battle: Node = current_scene.battle
		var enemy: Area2D = battle.boss
		var coins: int = session.story_progress.necoins
		var observed := {"hits": 0, "health": Catalog.ENEMY_HP, "collisions": 0}
		enemy.health_changed.connect(func(value: float):
			observed.hits += 1
			observed.health = value)
		# Remove player survival as a variable; enemy motion/attacks remain real.
		battle.player.invincible = true
		enemy.set_physics_process(false)
		var probe := shoot(battle)
		check((probe.collision_mask & enemy.collision_layer) != 0,
			"%s: shared bullet detects enemy layer" % Catalog.NAMES[kind])
		probe.area_entered.connect(func(area: Area2D):
			if area == enemy: observed.collisions += 1)
		await wait_for_impact(probe)
		check(enemy.health == Catalog.ENEMY_HP - 1 and observed.collisions == 1,
			"%s: physical overlap emits hit and deals existing one-point damage" % Catalog.NAMES[kind])
		check(not is_instance_valid(probe), "shot disappears on impact")
		check(battle.ui.hp.value == enemy.health, "HP bar reflects projectile damage")
		if enemy.health == Catalog.ENEMY_HP:
			# Fail quickly before the fix, rather than running 72 known misses.
			await session.forest_encounters.resolve("flee")
			continue
		var hitbox: CollisionShape2D = enemy.get_child(0)
		check(hitbox.get_parent() == enemy and enemy.sprite.get_parent() == enemy,
			"sprite and hitbox share the moving enemy transform")
		# A shot outside the body's horizontal bounds must miss.
		var miss := shoot(battle)
		miss.position.x = enemy.position.x + 100
		await create_timer(0.16).timeout
		check(enemy.health == Catalog.ENEMY_HP - 1 and is_instance_valid(miss), "outside-body shot misses")
		miss.queue_free()
		enemy.set_physics_process(true)
		for shot_index in range(1, Catalog.ENEMY_HP):
			# Explicitly cover both horizontal directions, then leave normal motion.
			if shot_index == 1: enemy.age = 0.0
			if shot_index == 2: enemy.age = PI / 0.9
			var previous_x: float = enemy.position.x
			var bullet := shoot(battle)
			bullet.area_entered.connect(func(area: Area2D):
				if area == enemy: observed.collisions += 1)
			await wait_for_impact(bullet)
			check(not is_instance_valid(bullet), "moving enemy consumes shot %d" % (shot_index + 1))
			check(observed.health == Catalog.ENEMY_HP - shot_index - 1, "one damage per moving hit")
			if shot_index < Catalog.ENEMY_HP - 1:
				check(battle.ui.hp.value == observed.health, "moving hit updates HP bar")
				check(hitbox.global_position.is_equal_approx(enemy.sprite.global_position), "hitbox follows visible sprite")
				if shot_index == 1: check(enemy.position.x > previous_x, "rightward hit")
				if shot_index == 2: check(enemy.position.x < previous_x, "leftward hit")
		var result_ui: Node=current_scene.rpg_ui
		await create_timer(.95).timeout
		result_ui.close_results()
		await settle()
		check(observed.health == 0 and observed.hits == Catalog.ENEMY_HP and observed.collisions == Catalog.ENEMY_HP,
			"all 72 real projectile collisions reach zero HP")
		check(current_scene.name == "Overworld" and not session.encounter_active, "lethal shot returns to overworld")
		check(session.story_progress.necoins == coins + Catalog.REWARD, "lethal shot rewards exactly ten NeCoins")
		check(not session.forest_encounters.population[0].alive, "defeated enemy stays removed for visit")
		await create_timer(0.1).timeout
		check(session.story_progress.necoins == coins + Catalog.REWARD, "reward remains single")
		print("PROJECTILE FLOW: %s passed" % Catalog.NAMES[kind])
	print("ORDINARY PROJECTILE HITS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
