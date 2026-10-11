extends SceneTree

const Layout = preload("res://scripts/maps/world_layout.gd")
var checks := 0
var failures := 0
var session: Node

func _initialize() -> void:
	create_timer(100).timeout.connect(func(): quit(1))
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+message)

func press(code: int) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
		await physics_frame

func wait_transition() -> void:
	while session.busy: await process_frame
	for i in 3: await physics_frame

func acknowledge() -> void:
	var dialogue: Node = current_scene.dialogue
	if not dialogue.is_revealed(): await press(KEY_Z)
	await press(KEY_Z)

func approach_boss() -> void:
	current_scene.player.position = Vector2(1840,450)
	current_scene.player.velocity = Vector2.ZERO
	for i in 3: await physics_frame
	await press(KEY_Z)

func dialogue_and_markers() -> void:
	await session.new_game()
	check(current_scene.map_ui.visible_boss_markers().is_empty(),"undiscovered bosses have no map markers")
	session.evil_bart_defeated = true
	session.grant_flooded_key()
	session.key_notification_pending = false
	await session.travel("flooded_forest","FromDeep")
	var world: Node = current_scene
	var npc: Node = world.map.get_node("Characters/Boss2NPC")
	check(npc.position == Vector2(1840,360),"Boss 2 keeps original location and shared artwork")
	check(world.map_ui.visible_boss_markers().size() == int(session.exploration.visited("flooded_forest",Vector2i(npc.position/64))),"nearby arrival marker appears only if legitimate fog reveals the boss cell")
	for repeat in 3:
		await approach_boss()
		world = current_scene
		var dialogue: Node = world.dialogue
		check(dialogue.active and dialogue.lines[0].speaker == "Boss 2" and dialogue.lines[0].text == "The hell are you looking at? And why do you look just like me?","opening speaker and exact text on apology "+str(repeat))
		var original: Vector2 = world.player.position
		await press(KEY_RIGHT)
		await press(KEY_SPACE)
		await press(KEY_M)
		check(world.player.position == original and not world.map_ui.modal_open(),"dialogue blocks movement and map/inventory actions")
		await acknowledge()
		check(dialogue.choices.size() == 2 and dialogue.choices[0].text == "Sorry…" and dialogue.choices[1].text == "Bring it on, loser!","exact responses require explicit selection")
		for i in 4: await process_frame
		check(dialogue.active and not session.encounter_active,"choice does not automatically confirm")
		await press(KEY_DOWN)
		check(dialogue.selected_choice == 1,"DOWN selects the challenge")
		await press(KEY_UP)
		check(dialogue.selected_choice == 0,"UP selects the apology")
		await press(KEY_Z)
		check(dialogue.active and dialogue.lines[0].text == "get out of my sight","apology shows exact lowercase reply")
		await acknowledge()
		check(not dialogue.active and not world.player.movement_locked and not session.busy and not session.encounter_active,"apology restores exploration without battle or immediate reinteraction")
		check(not session.story_flags.get("boss2_defeated",false) and not session.story_flags.get("boss2_victory_dialogue_pending",false),"repeated apology changes no completion state")
	var markers: Array = world.map_ui.visible_boss_markers()
	check(markers.size() == 1 and markers[0].id == "boss2" and not markers[0].defeated,"legitimately explored Boss 2 gets an undefeated red marker")
	check(markers[0].point == Layout.world_point("flooded_forest",npc.position),"boss marker derives from actual NPC scene position")
	await press(KEY_M)
	check(world.map_ui.minimap.boss_markers == world.map_ui.full_map.boss_markers,"both maps share markers with the same world coordinates")
	await press(KEY_M)
	var flags_before: Dictionary = session.story_flags.duplicate()
	await approach_boss()
	await acknowledge()
	await press(KEY_DOWN)
	await press(KEY_Z)
	check(session.busy and session.encounter_active and session.encounter_id == "boss2" and not world.dialogue.active,"challenge immediately starts existing battle transition")
	await wait_transition()
	var host: Node = current_scene
	var battle: Node = host.battle
	check(battle.player.health == 3 and host.arena.size == Vector2i(540,900),"battle retains original health and internal resolution")
	check(current_scene.get_node_or_null("Cartography") == null,"no exploration minimap is added to combat")
	battle.set_physics_process(false)
	battle.player.set_physics_process(false)
	var cross: Node = battle.timeline.cross
	check(is_equal_approx(cross.maximum_rpm,18) and is_equal_approx(cross.velocity_at(8),TAU*0.3),"cross plateau is exactly 18 RPM / 0.3 revolutions per second")
	check(is_equal_approx(cross.velocity_at(8)*180/PI,108),"cross plateau is exactly 108 degrees per second")
	check(is_equal_approx(cross.angle_at(8+10.0/3.0)-cross.angle_at(8),TAU),"plateau makes one full turn in 3.333 seconds")
	check(cross.start_time == 70.4 and cross.end_time == 89.6 and cross.core_width == 3,"cross timing, geometry and damage core remain unchanged")
	check(battle.music_player.playing and battle.elapsed_time < 1,"existing battle soundtrack starts from zero")
	check(session.story_flags == flags_before,"entering challenge does not add rewards or progression flags")
	battle.elapsed_time = battle.end_time
	battle.finish_survival()
	check(session.story_flags.get("boss2_defeated",false) and session.story_flags.get("boss2_victory_dialogue_pending",false),"actual survival victory records defeat and pending acknowledgment")
	check(session.saves.read_save().story_flags.get("boss2_victory_dialogue_pending",false),"pending victory dialogue is persisted before leaving combat")
	check(session.story_flags.size() == flags_before.size()+2,"victory adds only boss completion and dialogue acknowledgment state")
	await host.return_to_forest()
	await wait_transition()
	world = current_scene
	check(world.dialogue.active and world.dialogue.lines[0].text == "What the hell?? I underestimated you…! Get out of here, me!","return after survival shows exact victory text")
	check(world.map.get_node("Characters/Boss2NPC").position == Vector2(1840,360),"victorious boss remains at original overworld location")
	markers = world.map_ui.visible_boss_markers()
	check(markers.size() == 1 and markers[0].defeated,"victory immediately changes explored Boss 2 marker to green")
	await session.main_menu()
	await session.load_game()
	await wait_transition()
	check(current_scene.dialogue.active and current_scene.dialogue.lines[0].text == "What the hell?? I underestimated you…! Get out of here, me!","unacknowledged victory dialogue survives save/load")
	await acknowledge()
	world = current_scene
	check(not world.dialogue.active and session.story_flags.get("boss2_victory_dialogue_seen",false) and not session.story_flags.has("boss2_victory_dialogue_pending"),"acknowledgment clears pending line and returns control")
	check(session.saves.read_save().story_flags.get("boss2_victory_dialogue_seen",false),"completed acknowledgment autosaves")
	for repeat in 2:
		await approach_boss()
		check(world.dialogue.active and world.dialogue.lines[0].text == "You're not telling anyone about this" and world.dialogue.choices.is_empty(),"defeated NPC repeat dialogue remains available")
		await acknowledge()
		check(not session.busy and not session.encounter_active and not world.dialogue.active,"repeat line never restarts combat or reopens from the same Z")
	await session.begin_boss2_battle(world.player.position)
	check(current_scene == world and not session.busy,"completed boss cannot restart through encounter entry point")
	await session.load_game()
	await wait_transition()
	world = current_scene
	check(not world.dialogue.active and world.map_ui.visible_boss_markers()[0].defeated,"acknowledged victory and green marker survive reload")
	session.exploration.reveal("bart_area",Vector2(1000,450))
	markers = world.map_ui.visible_boss_markers()
	check(markers.size() == 2 and markers.all(func(marker): return marker.defeated),"explored saved Bart and Boss 2 completion both render green")
	session.evil_bart_defeated = false
	markers = world.map_ui.visible_boss_markers()
	check(not markers.filter(func(marker): return marker.id == "bart")[0].defeated,"Bart marker uses real completion state rather than a separate flag")
	var before: Dictionary = session.exploration.snapshot()
	session.map_reveal_cheat = true
	check(world.map_ui.visible_boss_markers().size() == 2,"existing reveal cheat also respects fully revealed map presentation")
	session.map_reveal_cheat = false
	check(session.exploration.snapshot() == before,"marker display cannot reveal legitimate exploration")

func routes() -> void:
	var pairs := [
		["entrance","Exit0","deep_forest","Exit0"],
		["deep_forest","Exit1","bart_area","Exit0"],
		["deep_forest","ToFlooded","flooded_forest","ToDeep"],
		["entrance","ToBart","bart_area","ToEntrance"],
		["bart_area","ToFlooded","flooded_forest","ToBart"]]
	for pair in pairs:
		var maps: Array[Node] = []
		var boundaries: Array[Vector2] = []
		for side in [0,1]:
			var area: String = pair[side*2]
			var map: Node = load("res://scenes/world/"+Layout.REGIONS[area].scene+".tscn").instantiate()
			maps.append(map)
			var portal: Node = map.get_node("Portals/"+pair[side*2+1])
			# Source's paired arrival is the marker whose inward vector describes its edge.
			var inward: Vector2 = Vector2.ZERO
			for arrival in map.get_node("Entries").get_children():
				if arrival.position.distance_to(portal.position) == 144: inward = arrival.get_meta("facing_direction")
			var boundary: Vector2 = portal.position-inward*64
			boundaries.append(Layout.world_point(area,boundary))
			var paths: TileMapLayer = map.get_node("WindingTrails" if area == "flooded_forest" else "Paths")
			var cell := paths.local_to_map(boundary-inward*-8)
			cell = cell.clamp(Vector2i.ZERO,Vector2i(map.map_size/16)-Vector2i.ONE)
			check(inward != Vector2.ZERO and paths.get_cell_source_id(cell) != -1,area+" has an actual boundary path and inward-facing safe arrival")
		check(boundaries[0] == boundaries[1],pair[0]+" / "+pair[2]+" path seams use the same world-map coordinates")
		for map in maps: map.free()
	for area in Layout.REGIONS:
		var map: Node = load("res://scenes/world/"+Layout.REGIONS[area].scene+".tscn").instantiate()
		var stones: TileMapLayer = map.get_node("GFXBoulders")
		check(stones.get_used_cells().size() >= 5 and stones.tile_set.get_source(0).texture.resource_path.ends_with("gfx/objects.png"),area+" retains real stones instead of detached cliff segments")
		var variants := {}
		for cell in stones.get_used_cells(): variants[stones.get_cell_atlas_coords(cell)] = true
		check(variants.size() == 2,area+" uses individual stones and complete stone clusters")
		map.free()
	# Test every directed boundary with real held movement, no Z input.
	for pair in pairs:
		for side in [0,1]:
			var area: String = pair[side*2]
			session.evil_bart_defeated = true
			session.story_flags = {"bart_defeated":true,"flooded_forest_key_obtained":true,"bart_victory_dialogue_seen":true,"boss2_defeated":true}
			var entry: String = "Start" if area == "entrance" else ("FromEntrance" if area == "deep_forest" else "FromDeep")
			await session.travel(area,entry)
			var world: Node = current_scene
			var portal: Node = world.map.get_node("Portals/"+pair[side*2+1])
			var destination: String = portal.destination
			var arrival: String = portal.entry
			var outgoing := Vector2.LEFT if portal.position.x == 64 else (Vector2.RIGHT if portal.position.x == world.map.map_size.x-64 else (Vector2.UP if portal.position.y == 64 else Vector2.DOWN))
			world.player.position = portal.position-outgoing*160
			for i in 3: await physics_frame
			var button: int = KEY_RIGHT if outgoing == Vector2.RIGHT else (KEY_LEFT if outgoing == Vector2.LEFT else (KEY_DOWN if outgoing == Vector2.DOWN else KEY_UP))
			var event := InputEventKey.new()
			event.keycode = button
			event.pressed = true
			Input.parse_input_event(event)
			var deadline := Time.get_ticks_msec()+1600
			while not session.busy and Time.get_ticks_msec() < deadline: await physics_frame
			event = InputEventKey.new()
			event.keycode = button
			Input.parse_input_event(event)
			check(session.busy and world.player.movement_locked,area+" walking into boundary automatically starts one transition")
			var started := Time.get_ticks_msec()
			await create_timer(0.14).timeout
			check(session.curtain.visible and session.curtain.color == Color.BLACK and session.curtain.modulate.a > 0.3 and session.curtain.modulate.a < 0.8,area+" full-viewport black fade is mid-way after about 0.15 seconds")
			await wait_transition()
			check(session.area_id == destination and current_scene != world,area+" boundary reaches "+destination+" without Z")
			check(Time.get_ticks_msec()-started >= 500 and session.region_fade_duration == 0.3,"region transition retains separate 0.3-second fade-out/fade-in")
			world = current_scene
			var marker: Node = world.map.get_node("Entries/"+arrival)
			check(world.player.position == marker.position and world.player.facing_direction == marker.get_meta("facing_direction"),"arrival uses paired position and faces inward")
			await create_timer(0.2).timeout
			check(current_scene == world and not session.busy,"safe arrival avoids an immediate reverse transition")
	await session.travel("deep_forest","FromEntrance")
	session.evil_bart_defeated = false
	session.story_flags.clear()
	var world: Node = current_scene
	var gate: Node = world.map.get_node("Portals/ToFlooded")
	world.player.position = gate.position
	for i in 5: await physics_frame
	check(current_scene == world and not session.busy and not gate.can_travel(),"automatic Flooded Forest boundary cannot bypass Bart or missing key")

func run() -> void:
	root.size = Vector2i(1280,720)
	session = root.get_node("Session")
	session.saves.save_path = "user://validation-region-update.json"
	await dialogue_and_markers()
	await routes()
	current_scene.queue_free()
	await process_frame
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(session.saves.save_path+suffix)
	print("REGION UPDATE VALIDATION: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
