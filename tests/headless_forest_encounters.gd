extends SceneTree
var checks:=0
var failures:=0
var session: Node
var world: Node
const Catalog=preload("res://scripts/encounters/catalog.gd")
func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1" or OS.get_environment("XDG_DATA_HOME").is_empty():quit(1);return
	create_timer(180).timeout.connect(func():push_error("Encounter tests timed out");quit(1))
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func settle() -> void:
	await process_frame
	while session.busy:await process_frame
	world=current_scene
func forest(area: String) -> void:
	await session.travel(area,"Start")
	world=current_scene
	while not world.encounters.loaded:await process_frame
func start(kind: int) -> Node:
	world.encounters.set_process(false)
	session.forest_encounters.population[0]={"kind":kind,"position":Vector2(1000,912),"home":Vector2(1100,912),"alive":true,"retreat":false,"ignore_until":0.0}
	session.forest_encounters.active={"id":0,"kind":kind,"area":session.area_id,"position":world.player.position,"settled":false}
	session.encounter_active=true;session.encounter_id="ordinary"
	await session.transition_to("res://scenes/encounters/combat_host.tscn",true)
	var battle:Node=current_scene.battle
	battle.boss.set_physics_process(false)
	return battle
func run() -> void:
	session=root.get_node("Session")
	await session.new_game(2);world=current_scene
	while not world.encounters.loaded:await process_frame
	check(session.story_progress.necoins==0,"new game zero NeCoins")
	check(session.forest_encounters.checkpoint.position==[240.0,912.0],"new checkpoint original spawn")
	var signatures=[]
	for kind in 8:
		session.rpg.restore({})
		var battle:Node=await start(kind)
		check(current_scene.arena.size==Vector2i(540,900),"reuse arena resolution")
		check(battle.player.health==20 and battle.player.speed==450 and battle.player.damage_hitbox_radius==7.5,"reuse Showdown player balance")
		check(battle.boss.health==72 and battle.ui.enemy_name.text==Catalog.NAMES[kind],"official enemy and equal HP")
		check(battle.boss.sprite.texture.resource_path.ends_with("enemy_%d.png"%kind),"correct sprite reading order")
		check(battle.music_player.playing and battle.elapsed_time<1 and absf(battle.duration-70.818)<.1,"music starts at zero with actual duration")
		battle.boss.rng.seed=7654
		battle.boss.fire_pattern()
		var pattern=[]
		for bullet in get_nodes_in_group("enemy_bullets"):
			if not battle.is_ancestor_of(bullet):continue
			pattern.append([bullet.direction,bullet.speed,bullet.angular_velocity])
		check(pattern.size()>=10 and pattern.size()<=13,"bounded pattern density")
		check(pattern not in signatures,"unique themed pattern")
		signatures.append(pattern)
		battle.boss.age=60
		battle.boss.rng.seed=7654
		var before:int=battle.projectile_count()
		battle.boss.fire_pattern()
		check(battle.projectile_count()-before==pattern.size(),"no late-song density escalation")
		# Existing parent damage feedback, with ordinary-only longer protection.
		battle.player.take_damage(1)
		check(battle.player.health==17 and is_equal_approx(battle.player.invulnerability_timer,1.5),"one HP and 1.5s protection")
		battle.player.take_damage(1)
		check(battle.player.health==17,"overlapping hit blocked")
		if kind==0:
			battle.player.invincible=true
			battle.player.activate_saturate()
			await create_timer(1.8).timeout
			check(battle.boss.health==42 and battle.player.saturate_used,"inherited SATURATE deals thirty damage once")
			check(battle.projectile_count()==0,"SATURATE clears ordinary projectiles")
		var time:float=battle.music_player.get_playback_position()
		session.open_pause();await create_timer(.15).timeout
		check(absf(battle.music_player.get_playback_position()-time)<.08,"audio deadline pauses")
		session.close_pause()
		var coins:int=session.story_progress.necoins
		battle.boss.take_damage(72)
		battle.finish("victory") # Duplicate callback must not duplicate reward.
		await create_timer(.95).timeout
		current_scene.rpg_ui.close_results()
		await settle()
		check(session.story_progress.necoins==coins+10,"one ten-NeCoin victory reward")
		check(not session.forest_encounters.population[0].alive,"defeated enemy remains absent this visit")
		check(world.name=="Overworld" and root.get_node("Music").current_theme=="overworld","regional music restored")
	# Existing story progress survives ordinary defeat after the last manual save.
	session.story_progress.accept_cupid();session.story_progress.acquire_wand(false)
	session.story_progress.collect_feather("entrance_white")
	var earned:Dictionary=session.story_progress.snapshot()
	session.forest_encounters.activate_checkpoint("entrance",Vector2(640,1226))
	var battle:Node=await start(0)
	battle.music_player.seek(battle.duration-.05)
	await create_timer(.2).timeout
	await settle()
	check(world.name=="Overworld" and world.player.position.is_equal_approx(Vector2(640,1226)),"song timeout returns checkpoint")
	check(session.story_progress.snapshot()==earned,"timeout preserves unsaved earned progress")
	battle=await start(1)
	battle.player.invulnerability_timer=0
	battle.player.take_damage(100)
	await settle()
	check(not paused and world.name=="Overworld" and session.story_progress.snapshot()==earned,"zero HP returns without rollback/pause lock")
	# Fixed-seed FLEE verifies both outcomes and same 50% threshold.
	battle=await start(2)
	var seed_success:=0
	var seed_failure:=0
	for seed in range(1,100):
		var probe:=RandomNumberGenerator.new();probe.seed=seed
		if probe.randi_range(0,1)==0:seed_success=seed
		else:seed_failure=seed
	check(seed_success>0 and seed_failure>0 and Catalog.FLEE_OUTCOMES==2,"exact common 50% FLEE threshold")
	battle.rng.seed=seed_failure;battle.attempt_flee()
	check(not battle.settled and battle.ui.status.text=="FLEE — FAILED","failed FLEE stays active")
	battle.flee_cooldown=0;battle.rng.seed=seed_success;battle.attempt_flee()
	await settle()
	check(session.story_progress.snapshot()==earned,"successful FLEE no reward")
	check(session.forest_encounters.population[0].alive and session.forest_encounters.population[0].retreat,"fled enemy alive and retreating")
	check(session.forest_encounters.population[0].ignore_until>session.forest_encounters.clock+8,"ten-second ignore cooldown")
	check(session.forest_encounters.protection_until>session.forest_encounters.clock,"global encounter protection")
	var save:Dictionary=session.snapshot(session.area_id,world.player.position)
	check(Vector2(save.checkpoint.position[0],save.checkpoint.position[1])==Vector2(640,1226) and not session.saves.validate(save).is_empty(),"separate checkpoint persists in manual-save payload")
	save.erase("checkpoint")
	check(not session.saves.validate(save).is_empty(),"older saves without checkpoint accepted")
	save.checkpoint={"area":"bad","position":[0,0]}
	check(session.saves.validate(save).is_empty(),"malformed checkpoint rejected safely")
	# All four map geometries/story counts, and visit reset vs battle return.
	session.story_flags["blankkitten_defeated"]=true
	for area in ["entrance","deep_forest","bart_area","flooded_forest"]:
		await forest(area)
		check(world.map.map_size==load("res://scripts/journey/layout.gd").SIZES[area],"region geometry preserved")
		var stars=0
		for actor in get_nodes_in_group("interactables"):
			if world.map.is_ancestor_of(actor) and actor.has_meta("save_statue"):stars+=1
		check(stars==1,"one save star per forest")
		check(world.encounters.navigation.ready,"collision navigation built")
		world.encounters.set_process(false)
		session.forest_encounters.population[99]={"alive":false}
		await forest("deep_forest" if area=="entrance" else "entrance")
		await forest(area)
		check(not session.forest_encounters.population.has(99),"region exit permits repopulation")
	# Weather interpolation never jumps directly; battle switches remove overlay.
	var weather:Node=session.weather
	var initial:float=weather.rain
	weather.set_weather("heavy_rain")
	weather._process(.1)
	check(weather.rain>initial and weather.rain-initial<.05,"smooth rain transition")
	for i in 100:weather._process(.2)
	check(weather.rain>.75,"heavy rain eventually reached")
	weather.set_weather("clear")
	for i in 150:weather._process(.2)
	check(weather.rain<.01,"clear weather restores rain smoothly")
	check(root.get_node("Ambience").profile_for("deep_forest")!=root.get_node("Ambience").profile_for("bart_area"),"distinct forest ambience profiles")
	print("FOREST ENCOUNTERS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
