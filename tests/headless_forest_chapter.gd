extends SceneTree
const Plan=preload("res://scripts/journey/layout.gd")
const Routes=preload("res://scripts/journey/chapter_routes.gd")
var checks:=0
var failures:=0
var session: Node
func _initialize() -> void:
	if OS.get_environment("CATSSAGA_TEST_PROFILE")!="1" or OS.get_environment("XDG_DATA_HOME").is_empty():quit(1);return
	create_timer(150).timeout.connect(func():push_error("Forest chapter timeout");quit(1))
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func run() -> void:
	session=root.get_node("Session")
	await session.new_game(3)
	check(current_scene.player.position==Plan.SPAWNS.entrance,"original fresh spawn")
	session.story_flags["blankkitten_defeated"]=true
	session.rpg.rewarded_bosses.append("blankkitten")
	session.rpg.total_exp=125
	session.rpg.inventory.cat_treats=2
	session.story_progress.necoins=75
	session.story_progress.accept_cupid()
	session.story_progress.collect_feather("entrance_white")
	session.forest_encounters.protection_until=INF
	for area in Plan.ORDER:
		await session.travel(area,"Start")
		var world=current_scene
		while not world.encounters.loaded:await process_frame
		world.encounters.set_process(false)
		var query:=PhysicsShapeQueryParameters2D.new()
		query.shape=world.player.get_node("CollisionShape2D").shape;query.collision_mask=1
		var blocked: Array=[]
		for point in Routes.curve(area):
			if not Rect2(Vector2(120,100),world.map.map_size-Vector2(240,200)).has_point(point):continue
			query.transform=Transform2D(0,point)
			if not world.map.is_walkable_position(point) or not world.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty():blocked.append(point)
		check(blocked.is_empty(),area+" main centerline has player-sized clearance: "+str(blocked))
		check(world.map.get_meta("tree_count")>400,area+" retains dense forest")
		check(world.map.map_size==Plan.SIZES[area],area+" unchanged save coordinates and bounds")
		for landmark in world.map.get_node("Discoveries").get_children():
			check(not world.encounters.navigation.path(world.player.position,landmark.position).is_empty(),area+" retained landmark route: "+landmark.name)
		var atmosphere=world.map.get_node("ForestAtmosphere")
		session.weather.rain=.65
		atmosphere._process(.01)
		check(is_equal_approx(atmosphere.water_surface.material.get_shader_parameter("rain_strength"),.65),area+" rain drives rendered water")
		var visuals=root.get_node("VisualSettings")
		var old_motion: float=visuals.motion
		visuals.motion=0;atmosphere._process(.01)
		check(is_zero_approx(atmosphere.canopy.get_shader_parameter("motion")) and is_zero_approx(atmosphere.water_surface.material.get_shader_parameter("motion")),area+" motion preference respected")
		visuals.motion=old_motion
		if area=="flooded_forest":
			check(atmosphere.surface(Vector2(1936,816))==2,"bridge surface wins over water beneath it")
			for approach in Routes.BRIDGE_APPROACHES:
				var clear:=true
				for point in Routes.smooth(approach):
					query.transform=Transform2D(0,point)
					if not world.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty():clear=false
				check(clear,"southern bridge approach has actual collision clearance")
		# An obstructed old checkpoint must recover without discarding progress.
		var tree=world.map.get_children().filter(func(n):return n.is_in_group("journey_trees"))[0]
		var before:Dictionary=session.story_progress.snapshot()
		var rpg:Dictionary=session.rpg.snapshot()
		check(session.saves.write_progress(session.snapshot(area,tree.position)),area+" checkpoint saved to disk")
		check(await session.load_game(3),area+" old position loaded from disk")
		world=current_scene
		while world.checking_spawn:await process_frame
		query.transform=world.player.global_transform
		check(world.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(),area+" obstructed saved position recovered")
		check(session.story_progress.snapshot()==before and session.rpg.snapshot()==rpg,area+" recovery preserves earned state")
	# Legacy saves have no new terrain revision or progression requirements.
	var legacy={"version":1,"area":"entrance","position":[240,912],"evil_bart_defeated":false,"story_flags":{}}
	var clean: Dictionary=session.saves.validate(legacy)
	check(not clean.is_empty() and clean.rpg.total_exp==0 and clean.story_progress.necoins==0,"legacy missing fields default safely")
	FileAccess.open("user://legacy-chapter-fixture.json",FileAccess.WRITE).store_string(JSON.stringify(legacy))
	check(session.saves.read_file("user://legacy-chapter-fixture.json")==clean,"legacy file reads with same migration")
	await session.travel("entrance","Start")
	session.forest_encounters.active={"kind":0,"area":"entrance"}
	await session.transition_to("res://scenes/encounters/combat_host.tscn",true)
	var battle=current_scene.battle
	battle.boss.set_physics_process(false)
	var ui=current_scene.rpg_ui
	battle.player.item_mode=true;ui.item_mode=true;battle.player.shoot_timer=0
	battle.ui.refresh()
	var shots:=get_nodes_in_group("player_bullets").size()
	battle.ui.fight_button.pressed.emit()
	check(battle.ui.fight_button.disabled and get_nodes_in_group("player_bullets").size()==shots and battle.player.shoot_timer==0,"FIGHT cannot bypass Item Mode")
	battle.player.item_mode=false;ui.item_mode=false;battle.ui.refresh()
	battle.ui.fight_button.pressed.emit()
	check(not battle.ui.fight_button.disabled and battle.player.shoot_timer>0,"FIGHT still shoots in Battle Mode")
	battle.player.set_physics_process(false)
	battle.player.invulnerability_timer=0
	battle.player.shield_remaining=0
	battle.player.health=20
	var shot=load("res://scenes/enemybullet.tscn").instantiate()
	shot.set_script(load("res://scripts/encounters/projectile.gd"))
	shot.position=battle.player.get_node("CollisionShape2D").global_position;shot.speed=0
	battle.add_child(shot)
	check(not shot.armed and shot.collision_layer==0,"point-blank projectile begins harmless")
	await create_timer(.17).timeout
	check(battle.player.health==20,"actual overlap during warning cannot hurt")
	await create_timer(.2).timeout
	check(battle.player.health==17,"same actual overlap damages once after warning")
	check(not is_instance_valid(shot),"armed hit consumes projectile")
	check(ui.score.hits==1,"actual damage changes score once")
	# Normal volleys retain timing/speed/count; only dangerously close births arm late.
	for kind in 8:
		battle.boss.kind=kind;battle.boss.rng.seed=700+kind
		battle.boss.position=Vector2(270,200);battle.player.position=Vector2(270,780)
		for bullet in get_nodes_in_group("enemy_bullets"):bullet.free()
		battle.boss.fire_pattern()
		var bullets=get_nodes_in_group("enemy_bullets")
		check(bullets.size()>=10 and bullets.size()<=13,"pattern count retained for "+str(kind))
		check(bullets.all(func(b):return b.armed and b.speed>=148 and b.speed<=214),"distant volley timing/speed retained for "+str(kind))
		for bullet in bullets:bullet.free()
		battle.player.position=battle.boss.position+Vector2(0,44)-battle.player.get_node("CollisionShape2D").position
		battle.boss.fire_pattern()
		check(get_nodes_in_group("enemy_bullets").all(func(b):return not b.armed),"all eight families warn on close spawn: "+str(kind))
	await session.main_menu()
	# A rapid return to menu during automatic region arrival must cancel the
	# outgoing world's coroutine; normal one-time encounter is covered in story QA.
	session.story_flags.erase("blankkitten_defeated")
	await session.travel("bart_area","Start")
	await session.main_menu()
	await process_frame;await process_frame
	check(current_scene.scene_file_path=="res://scenes/main_menu.tscn" and not session.busy,"leaving automatic arrival safely cancels outgoing dialogue")
	print("FOREST CHAPTER: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
