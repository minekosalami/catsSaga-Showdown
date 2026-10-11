extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func wait_transition() -> void:
	while root.get_node("Session").busy:
		await process_frame
	await process_frame

func _initialize() -> void:
	create_timer(65).timeout.connect(func(): quit(1))
	call_deferred("run")
func run() -> void:
	var session: Node = root.get_node("Session")
	session.saves.save_path = "user://validation-boss2.json"
	var old := {"version":1,"area":"deep_forest","position":[1750,1010],"evil_bart_defeated":true,"story_flags":{"existing_flag":true,"bart_victory_dialogue_seen":true}}
	var migrated: Dictionary = session.saves.validate(old)
	check(migrated.story_flags.flooded_forest_key_obtained and migrated.story_flags.bart_defeated and migrated.story_flags.existing_flag,"old Bart victory grants key without erasing flags")
	check(not migrated.story_flags.flooded_forest_unlocked and not migrated.story_flags.boss2_defeated,"migration does not invent unlocked gate or boss2 victory")
	var root_legacy := old.duplicate(true)
	root_legacy.erase("evil_bart_defeated")
	root_legacy["bart_defeated"] = true
	check(session.saves.validate(root_legacy).story_flags.flooded_forest_key_obtained,"legacy bart_defeated root field also migrates to key")
	await session.new_game()
	session.grant_flooded_key()
	check(not session.story_flags.get("flooded_forest_key_obtained",false),"key cannot be granted before actual Bart victory")
	await session.travel("deep_forest","FromFlooded")
	var world: Node = current_scene
	var gate: Node = world.map.get_node("Characters/FloodedGate")
	gate.handle_interaction(world)
	check(world.dialogue.active and world.dialogue.lines[0].text == "The entrance is locked. A special key is required.","locked gate presents exact required text")
	check(session.area_id == "deep_forest" and not session.story_flags.get("flooded_forest_key_obtained",false),"locked interaction grants neither access nor reward")
	world.dialogue.active = false
	world.dialogue.panel.hide()
	session.evil_bart_defeated = true
	session.grant_flooded_key()
	session.grant_flooded_key()
	check(session.story_flags.flooded_forest_key_obtained and session.key_notification_pending,"key award is idempotent with one pending notification")
	world.player.position = world.map.get_node("Portals/ToFlooded").position
	for i in 4: await physics_frame
	await wait_transition()
	world = current_scene
	check(session.area_id == "flooded_forest" and session.story_flags.flooded_forest_unlocked,"automatic boundary uses existing key and records gate traversal")
	check(session.story_flags.flooded_forest_key_obtained,"gate never consumes key")
	check(world.map.map_size == Vector2(4096,3072) and world.player.get_node("Camera2D").limit_right == 4096,"new map and camera retain widescreen architecture")
	var water: TileMapLayer = world.map.get_node("PlaceholderWater")
	check(water.get_used_cells().size() > 3000 and water.tile_set.get_physics_layers_count() == 1,"separate editable water layer has physical terrain")
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = world.player.get_node("CollisionShape2D").shape
	query.collision_mask = 1
	query.transform = Transform2D(0,Vector2(120,200))
	await physics_frame
	await physics_frame
	check(not world.get_world_2d().direct_space_state.intersect_shape(query).is_empty(),"water tiles register collision at pool interior")
	query.transform = Transform2D(0,Vector2(260,768))
	check(world.get_world_2d().direct_space_state.intersect_shape(query).is_empty(),"entry point is clear of water, trees and walls")
	world.player.position = Vector2(200,600)
	world.player.velocity = Vector2.ZERO
	key(KEY_UP,true)
	await create_timer(0.5).timeout
	key(KEY_UP,false)
	check(world.player.position.y > 530,"real overworld movement stops at water shore")
	world.player.position = Vector2(260,768)
	world.player.velocity = Vector2.ZERO
	var route := [Vector2(320,768),Vector2(480,1050),Vector2(780,1050),Vector2(870,720),Vector2(700,520),Vector2(950,310),Vector2(1200,370),Vector2(1330,720),Vector2(1570,860),Vector2(1740,600),Vector2(1840,450)]
	var clear_route := true
	var previous := Vector2(260,768)
	for point in route:
		for step in range(11):
			query.transform = Transform2D(0,previous.lerp(point,step/10.0))
			if not world.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty():
				clear_route = false
		previous = point
	check(clear_route,"entire entry-to-boss trail is clear for actual player shape")
	var npc: Node = world.map.get_node("Characters/Boss2NPC")
	check(npc.get_node("Sprite2D").texture.resource_path == "res://assets/enironment/bosses/boss2/bosstwo.png","new NPC references authorized original bosstwo texture")
	check(world.map.y_sort_enabled and get_nodes_in_group("world_trees").size() >= 80,"trees use existing size variation and Y-sort")
	check(session.save_current(),"Flooded Forest position and flags save through existing storage")
	var saved: Dictionary = session.saves.read_save()
	check(saved.area == "flooded_forest" and saved.story_flags.flooded_forest_key_obtained,"new area and persistent key reload as valid version-one data")
	world.player.position = world.map.get_node("Portals/ToDeep").position
	await physics_frame
	await physics_frame
	await physics_frame
	await wait_transition()
	check(current_scene.player.position.distance_to(current_scene.map.get_node("Entries/FromFlooded").position) < 1,"actual return portal reaches safe Deep Forest marker")
	await session.load_game()
	check(session.area_id == "deep_forest" and session.story_flags.flooded_forest_key_obtained,"save-load preserves key across travel")
	await session.travel("flooded_forest","FromDeep")
	world = current_scene
	npc = world.map.get_node("Characters/Boss2NPC")
	npc.handle_interaction(world)
	check(world.dialogue.active and world.pending_encounter == "boss2" and world.dialogue.graph.nodes.intro.choices[1].end == "battle","new NPC uses existing introduction and distinct battle routing")
	world.player.position = Vector2(1840,450)
	world.dialogue.advance()
	world.dialogue.advance()
	world.dialogue._choose(1)
	await wait_transition()
	var host: Node = current_scene
	var battle: Node = host.battle
	var timeline: Node = battle.timeline
	battle.player.invincible = true
	check(host.arena.size == Vector2i(540,900) and battle.player.health == 3,"survival starts with original 540x900 arena and player health")
	check(battle.music_player.stream.resource_path.ends_with("SyNaPse - 003.mp3") and battle.music_player.playing and battle.elapsed_time < 1,"correct music starts at zero after entry wipe")
	check(battle.end_time == 140.80 and battle.music_player.stream.get_length() > 150,"approved 140.80 ending uses original longer track without altering it")
	check(timeline.boss.texture == npc.get_node_or_null("Sprite2D").texture if is_instance_valid(npc) else timeline.boss.texture.resource_path.ends_with("bosstwo.png"),"battle uses same original texture as NPC")
	check(not timeline.is_in_group("enemies") and not timeline.has_method("take_damage"),"survival boss has no damage/HP interface")
	battle.player.shoot()
	battle.player.activate_saturate()
	check(not battle.player.saturate_used and get_nodes_in_group("player_bullets").is_empty(),"shooting and SATURATE are disabled only by survival subclass")
	key(KEY_X,true)
	key(KEY_X,false)
	check(not battle.player.saturate_used,"X cannot activate SATURATE in survival encounter")
	battle.player.unlimited_saturate = true
	battle.player.activate_saturate()
	check(not battle.player.saturate_used,"BEAM does not bypass survival-only SATURATE disable")
	battle.player.unlimited_saturate = false
	session.open_pause()
	var paused_clock: float = battle.music_player.get_playback_position()
	await create_timer(0.15).timeout
	check(absf(battle.music_player.get_playback_position()-paused_clock) < 0.08,"survival pause also pauses authoritative music playback")
	session.close_pause()
	check(timeline.phase == 0 and get_nodes_in_group("boss2_projectiles").is_empty(),"introduction is safe and has no bullets")
	battle.finish_survival()
	check(not battle.victory_started and not session.story_flags.get("boss2_defeated",false),"survival completion rejects an early victory call")
	check(not battle.ui.dialogue_label.visible and battle.ui.dialogue_label.text.begins_with("[Automatic"),"technical authoring placeholder stays configurable but is not displayed to players")
	key(KEY_Z,true)
	key(KEY_Z,false)
	check(not battle.ui.dialogue_label.visible,"Z does not turn the authoring placeholder into visible dialogue")
	key(KEY_SHIFT,true)
	key(KEY_RIGHT,true)
	await create_timer(0.18).timeout
	check(battle.player.velocity.x > 0 and battle.player.velocity.x <= 150.1 and battle.player.get_node("HitboxDebug").visible,"player moves in automatic dialogue with actual Shift focus marker")
	key(KEY_SHIFT,false)
	key(KEY_RIGHT,false)
	await process_frame
	await process_frame
	check(not battle.player.get_node("HitboxDebug").visible,"focus marker hides on release")
	for moment in [[12.79,0],[12.80,1],[38.39,1],[38.40,2],[64.00,3],[70.40,4],[89.60,5]]:
		battle.music_player.seek(moment[0])
		# Direct boundary evaluation verifies exact math separately from audio latency.
		timeline.advance(moment[0])
		check(timeline.phase == moment[1],"exact timeline boundary at " + str(moment[0]))
	battle.music_player.seek(64.0)
	battle.elapsed_time = 64.0
	timeline.advance(64.0)
	await physics_frame
	check(get_nodes_in_group("boss2_ricochets").size() == 7 and not timeline.lasers[0].active,"ricochet replaces former intermission and removes blue lasers")
	battle.ui.update(64.0)
	check(battle.ui.dialogue_label.text == "You're stronger than you look. But how long can you survive?" and battle.music_player.playing,"exact ricochet line is presentation without music pause")
	battle.ui.update(70.0)
	check(not battle.ui.dialogue_label.visible,"automatic ricochet line disappears before 70.40")
	battle.set_physics_process(false)
	timeline.advance(38.40)
	check(timeline.lasers[0].warning and not timeline.lasers[0].active,"laser assault begins with warning-only window")
	timeline.advance(42.0)
	check(timeline.lasers[0].active and is_equal_approx(timeline.boss.position.x-timeline.lasers[0].position.x,timeline.side_offset),"coordinated boss/laser motion maintains offsets")
	timeline.advance(70.40)
	check(not timeline.lasers[0].active and timeline.boss.position.x == 270,"convergence starts with warning and centered stationary boss")
	timeline.advance(83.0)
	var stopped_x: float = timeline.lasers[0].position.x
	check(timeline.cross.active and timeline.cross.position == timeline.cross.pivot_center and timeline.boss.position.x == 270,"red cross has fixed pivot and stationary boss")
	timeline.advance(89.59)
	check(not timeline.lasers[0].active and timeline.cross.angular_speed < 0.001,"blue lasers stay off while red cross eases to rest")
	check(absf(timeline.boss.position.x-timeline.lasers[0].position.x) > timeline.boss.texture.get_width()*timeline.boss.scale.x/2+timeline.laser_width/2,"vertical blue beams remain clear of the protected boss sprite")
	timeline.cross.sample(-1)
	battle.player.invincible = false
	battle.player.invulnerability_timer = 0
	battle.player.position = Vector2(stopped_x+13,700-17)
	timeline.lasers[0].present(stopped_x,false,true,Rect2(stopped_x-10,270,20,630),85)
	await physics_frame
	await physics_frame
	check(battle.player.health == 3,"warning zone contact deals no damage")
	timeline.lasers[0].present(stopped_x,true,false,Rect2(),85)
	await create_timer(0.12).timeout
	check(battle.player.health == 2,"active laser contact damages through actual player collision")
	await create_timer(0.12).timeout
	check(battle.player.health == 2,"continuous laser contact respects Boss2 1.5-second i-frames")
	timeline.advance(89.60)
	await physics_frame
	check(not timeline.lasers[0].active and timeline.phase == 5 and not battle.victory_started,"finale deactivates lasers without ending encounter")
	timeline.clear_hostiles()
	await physics_frame
	for i in range(300):
		timeline.fire(Vector2.DOWN,120,Color.CYAN)
	check(get_nodes_in_group("boss2_projectiles").size() == 240,"survival projectile budget bounds dense patterns")
	check(get_nodes_in_group("boss2_projectiles")[0].visual_style == 0,"survival uses bright circular bullets including opening and finale")
	timeline.clear_hostiles()
	await physics_frame
	battle.player.position = Vector2(270,780)
	battle.music_player.seek(140.6)
	battle.elapsed_time = 140.6
	battle.set_physics_process(true)
	await create_timer(0.5).timeout
	check(battle.victory_started and not battle.game_over and session.story_flags.boss2_defeated,"audio clock triggers survival victory at approved song ending")
	check(session.story_flags.bart_defeated and session.evil_bart_defeated,"boss2 victory preserves existing Bart progression")
	check(session.saves.read_save().story_flags.boss2_defeated,"boss2 victory persists through existing save system")
	check(get_nodes_in_group("boss2_projectiles").is_empty() and not timeline.lasers[0].active,"victory clears all hostile objects")
	await create_timer(0.85).timeout
	check(not battle.music_player.playing,"remaining audio tail fades instead of abruptly stopping")
	await host.return_to_forest()
	await wait_transition()
	check(session.area_id == "flooded_forest" and current_scene.player.position.distance_to(Vector2(1840,450)) < 1,"victory returns to saved Flooded Forest point")
	check(current_scene.dialogue.active and current_scene.dialogue.lines[0].text == "What the hell?? I underestimated you…! Get out of here, me!","survival return presents exact requested victory line")
	check(current_scene.map.get_node("Characters/Boss2NPC").can_interact(),"completed NPC remains available for repeat dialogue")
	await session.new_game()
	session.evil_bart_defeated = true
	session.grant_flooded_key()
	await session.travel("flooded_forest","FromDeep")
	await session.begin_boss2_battle(Vector2(1840,450))
	battle = current_scene.battle
	battle.player.take_damage(3)
	check(battle.game_over and not battle.victory_started,"death before ending triggers defeat")
	check(not session.story_flags.get("boss2_defeated",false) and not session.saves.read_save().story_flags.boss2_defeated,"first survival defeat never awards completion or saves victory")
	check(not battle.ui.return_button.visible,"defeat offers retry/menu without awarding victory")
	current_scene.retry()
	await wait_transition()
	battle = current_scene.battle
	check(battle.player.health == 3 and not battle.game_over and battle.elapsed_time < 1,"survival Retry restarts health and music from zero")
	await session.main_menu()
	check(current_scene.name == "Mainmenu","survival Main Menu navigation works")
	root.get_node("Music").play_theme("")
	current_scene.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.1).timeout
	print("BOSS2 VALIDATION: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
