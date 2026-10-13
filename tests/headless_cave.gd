extends SceneTree
const Plan = preload("res://scripts/world/cave_layout.gd")
const Layout = preload("res://scripts/maps/world_layout.gd")
var checks := 0
var failures := 0
var session: Node
func _initialize():
	create_timer(180).timeout.connect(func(): quit(1))
	call_deferred("run")
func check(ok: bool, text: String):
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+text)
func press(code: int):
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
func settle():
	while session.busy or session.cave_event_active: await process_frame
	await physics_frame
	await physics_frame
	await process_frame
	await process_frame
func place(point: Vector2):
	current_scene.player.position = point
	current_scene.player.velocity = Vector2.ZERO
	await physics_frame
	await process_frame
	await process_frame
func finish():
	while current_scene.dialogue.active:
		current_scene.dialogue.advance()
		await process_frame
func choices():
	while current_scene.dialogue.choices.is_empty():
		current_scene.dialogue.advance()
		await process_frame
func collision(world: Node, point: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = world.player.get_node("CollisionShape2D").shape
	query.transform = Transform2D(0,point)
	query.collision_mask = 1
	return not world.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()
func reachable(world: Node) -> Dictionary:
	var start := Vector2i(Plan.ENTRY/32)
	var visited := {start:true}
	var queue: Array[Vector2i] = [start]
	var i := 0
	while i < queue.size():
		var cell := queue[i]
		i += 1
		for offset in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next: Vector2i = cell+offset
			if visited.has(next) or world.map.get_node("CaveFloor").get_cell_source_id(next) < 0: continue
			if collision(world,Vector2(next*32)+Vector2(16,16)): continue
			visited[next] = true
			queue.append(next)
	return visited
func room_reachable(visited: Dictionary, id: int) -> bool:
	for cell in visited:
		var ids: Vector2i = current_scene.map.cell_room(cell)
		if ids.x == id and ids.y == 0: return true
	return false
func run():
	root.size = Vector2i(1280,720)
	session = root.get_node("Session")
	session.saves.save_path = "user://validation-cave-redesign.json"
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(session.saves.save_path+suffix)
	await session.new_game()
	await session.travel("underground_cave","FromFlooded")
	await settle()
	var world: Node = current_scene
	var cave: Node = world.map
	check(cave.get_meta("chamber_count") == 16 and Plan.ROOMS.size() == 16,"sixteen chambers retain original special area IDs")
	check(cave.map_size == Vector2(Plan.SIZE*32),"compact map bounds match blueprint")
	check(world.player.position == Plan.ENTRY and not collision(world,Plan.ENTRY),"safe entrance and default player sprite preserved")
	check(world.player.sprite.texture.resource_path == "res://assets/player/player.png.png" and world.player.speed == 260,"player artwork and movement unchanged")
	for name in ["CaveFloor","HubFloor","ColoredFloor","CaveWalls"]:
		var layer: TileMapLayer = cave.get_node(name)
		var source: TileSetAtlasSource = layer.tile_set.get_source(0)
		check(source.texture.resource_path.contains("basic caves and dungeons") and layer.scale == Vector2.ONE,name+" uses new source throughout at 32px display")
		check(source.texture_region_size == Vector2i(32,32) and source.texture.get_image().has_mipmaps() == false,name+" preserves native 32px regions without resampling")
		check(layer.tile_set.get_terrain_set_mode(0) == (TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES if name in ["CaveFloor","ColoredFloor"] else TileSet.TERRAIN_MODE_MATCH_SIDES),name+" has editable corner/side terrain transitions")
	var slots := {}
	for room in Plan.ROOMS: slots[room.slot] = true
	check(slots.size() == 16,"all sixteen organizational slots have distinct varied chambers")
	check(cave.get_node("Decorations").get_child_count() > 400,"dense props and lighting replace sparse blank floors")
	var water: TileMapLayer = cave.get_node("CaveWater")
	check(water.get_used_cells().size() > 300 and water.collision_enabled,"four pools have solid native water tiles")
	var blocked_water := true
	for cell in water.get_used_cells():
		var point := Vector2(cell*32)+Vector2(16,16)
		if not collision(world,point) or cave.is_walkable_position(point): blocked_water = false
	check(blocked_water,"every placed water cell blocks actual player collision and restored spawns")
	var closed := reachable(world)
	for id in [1,2,3,4,5,11,12,13]: check(room_reachable(closed,id),"Area %d reachable before red unlock"%id)
	for id in [6,7,8,9,10,14,15,16]: check(not room_reachable(closed,id),"Area %d blocked before red unlock"%id)
	var actors: Node = cave.get_node("Characters")
	var riddle: Node = actors.get_node("RiddleCat")
	await place(riddle.position+Vector2(0,96))
	await press(KEY_Z)
	check(world.dialogue.lines[0].text == riddle.RIDDLE.nodes.riddle.lines[0],"riddle starts with exact first box through Z")
	await choices()
	check(world.dialogue.lines[world.dialogue.line_index].text == "How many letters are in the word \"Cat?\"" and world.dialogue.choices[1].text == "14","second box and arithmetic distractor are correct")
	await press(KEY_DOWN)
	await press(KEY_Z)
	check(world.dialogue.lines[0].text == "Try again when you’re smart enough, peasant!","wrong answer gives exact response")
	await finish()
	check(not session.story_flags.get("cave_red_key_obtained",false) and not session.story_flags.get("cave_riddle_completed",false),"wrong answer awards nothing")
	var before_override: Dictionary = session.story_flags.duplicate()
	session.developer_cheats.activate("anywhereiwant")
	await physics_frame
	await physics_frame
	check(actors.get_node("RedBarrier").body.get_child(0).disabled and not actors.get_node("HubShortcut").blocker.visible,"existing region bypass also opens cave progression gates temporarily")
	check(session.story_flags == before_override and collision(world,actors.get_node("SealedWindow").position),"bypass grants no cave progress and cannot enter future green-key room")
	session.developer_cheats.activate("anywhereiwant")
	await physics_frame
	await physics_frame
	check(not actors.get_node("RedBarrier").body.get_child(0).disabled and actors.get_node("HubShortcut").blocker.visible,"disabling override restores red barrier and boulder")
	await press(KEY_Z)
	check(world.dialogue.lines[0].text == riddle.RIDDLE.nodes.riddle.lines[0],"next attempt repeats whole riddle")
	await choices()
	await press(KEY_Z)
	check(world.dialogue.lines[0].text == riddle.RIDDLE.nodes.correct.lines[0],"correct answer uses exact reward dialogue")
	await finish()
	await process_frame
	check(session.story_flags.get("cave_red_key_obtained",false) and session.story_flags.get("cave_riddle_completed",false),"correct answer gives one saved red key")
	check(not session.story_flags.get("cave_red_barrier_unlocked",false) and actors.get_node("HubShortcut").blocker.visible,"obtaining key does not unlock gate or shortcut")
	await press(KEY_SPACE)
	check(world.map_ui.inventory_contents.text.count("Red Key") == 1,"existing inventory shows exactly one red key")
	await press(KEY_SPACE)
	await press(KEY_Z)
	check(world.dialogue.graph.is_empty(),"completed riddle gives brief repeat response instead of restarting")
	await finish()
	await place(Plan.RED_GATE+Vector2(0,-96))
	await press(KEY_Z)
	await physics_frame
	await physics_frame
	await process_frame
	check(session.story_flags.get("cave_red_barrier_unlocked",false),"red barrier unlock requires explicit Z with key")
	check(actors.get_node("RedBarrier").body.get_child(0).disabled and not actors.get_node("HubShortcut").blocker.visible and not actors.get_node("JunctionShortcut").blocker.visible,"unlock removes barrier and both shortcut boulders")
	var open := reachable(world)
	for id in range(1,17):
		if id != 10: check(room_reachable(open,id),"Area %d reachable after unlock"%id)
	for actor in actors.get_children():
		var nearby := false
		for cell in open:
			if (Vector2(cell*32)+Vector2(16,16)).distance_to(actor.position) <= actor.interaction_radius:
				nearby = true
				break
		check(nearby,"reachable interaction approach: "+actor.name)
	await place(actors.get_node("Merchant").position+Vector2(0,96))
	var shop_scene_id: int = world.get_instance_id()
	await press(KEY_Z)
	check(cave.services.opened and world.map_modal_open() and world.get_instance_id() == shop_scene_id,"Z opens existing-world shop placeholder without internal scene loading")
	await press(KEY_MINUS)
	await press(KEY_SPACE)
	check(not session.developer_menu.opened and not world.map_ui.inventory_opened,"shop modal blocks conflicting debug/inventory overlays")
	await press(KEY_ESCAPE)
	check(not cave.services.opened and not paused and not world.map_modal_open(),"shop closes with Escape and restores navigation")
	await place(actors.get_node("RestPoint").position+Vector2(0,96))
	await press(KEY_Z)
	check(world.dialogue.active and world.dialogue.lines[0].text.begins_with("Rested."),"hub has a physical rest point using existing dialogue")
	await finish()
	check(not room_reachable(open,10),"Area 10 stays physically unreachable after red unlock")
	check(not cave.is_walkable_position(Plan.center(9)),"hidden room cannot be a restored player position")
	await place(actors.get_node("SavePoint").position+Vector2(0,100))
	var save_point: Vector2 = world.player.position
	await press(KEY_Z)
	check(world.dialogue.lines[0].text == "Game saved!","physical hub save point reports success")
	check(session.saves.read_save().position == [save_point.x,save_point.y],"save point stores exact valid player position")
	await finish()
	check(await session.load_game(),"cave save loads")
	await settle()
	world = current_scene
	cave = world.map
	actors = cave.get_node("Characters")
	check(world.player.position == save_point and session.story_flags.cave_red_key_obtained and session.story_flags.cave_red_barrier_unlocked,"load preserves position, key, puzzle and barrier state")
	await place(Plan.SHORTCUT_HUB+Vector2(0,-96))
	var scene_id: int = world.get_instance_id()
	await press(KEY_Z)
	await settle()
	check(world.get_instance_id() == scene_id and cave.current_room == 8 and not collision(world,world.player.position),"hub shortcut travels safely to Area 8 without scene reload")
	await place(Plan.SHORTCUT_JUNCTION+Vector2(0,96))
	await press(KEY_Z)
	await settle()
	check(cave.current_room == 4 and world.get_instance_id() == scene_id,"shortcut also returns from Area 8 to hub")
	await place(Plan.center(6)+Vector2(0,64))
	await create_timer(1.15).timeout
	check(cave.current_room == 7 and cave.gray > .99 and cave.screen_layer.layer == 128,"Area 7 transitions full-screen effect above HUD/dialogue/inventory")
	check(cave.drone.playing and cave.drone.volume_db > -30 and cave.get_node("UndergroundAtmosphere").bed.volume_db < -50,"Area 7 crossfades ambience to local muffled drone")
	await press(KEY_SPACE)
	check(world.map_ui.inventory_opened and cave.screen_layer.visible,"grayscale remains active with inventory")
	await press(KEY_SPACE)
	for cell in cave.get_node("CaveFloor").get_used_cells():
		if cave.cell_room(cell) == Vector2i(7,8):
			await place(Vector2(cell*32)+Vector2(16,16))
			break
	check(cave.gray == 0 and not cave.drone.playing,"grayscale and drone stop at the room boundary, before shared hallway")
	await place(Plan.center(7)+Vector2(0,64))
	check(cave.current_room == 8 and cave.gray == 0 and not cave.drone.playing,"Area 8 immediately restores colors and stops drone")
	await place(Plan.center(6)+Vector2(0,64))
	await create_timer(.3).timeout
	check(cave.gray > .2 and cave.drone.playing,"Area 7 effects reapply on reentry")
	await place(Plan.center(7)+Vector2(0,64))
	await press(KEY_MINUS)
	check(session.developer_menu.opened,"regular minus shortcut works with standard keyboard device")
	var focus := root.gui_get_focus_owner()
	await press(KEY_DOWN)
	check(root.gui_get_focus_owner() != focus,"developer menu arrow navigation advances enabled control")
	session.developer_menu.controls.mycoordinates.grab_focus()
	var previous: bool = session.show_coordinates
	await press(KEY_ENTER)
	check(session.show_coordinates != previous,"Enter activates focused toggle once through original handler")
	await press(KEY_MINUS)
	check(not paused and not session.developer_menu.opened,"minus closes menu and restores controls")
	await place(Plan.ROUTES.filter(func(route): return route.b == 9)[0].points[-1]*32)
	check(session.cave_event_active,"Area 9 starts introduction automatically")
	var camera: Camera2D = world.player.get_node("Camera2D")
	var view: Vector2 = world.get_viewport_rect().size/camera.zoom
	check(cave.boss.position.x-50 > camera.get_screen_center_position().x+view.x*.5,"temporary boss initially entirely beyond frame")
	await press(KEY_MINUS)
	await press(KEY_ESCAPE)
	session.request_main_menu()
	check(not session.developer_menu.opened and not paused,"debug/pause menus cannot interrupt cave introduction")
	check(current_scene == world and not is_instance_valid(session.confirmation),"HUD Main Menu cannot skip the introduction")
	while not world.dialogue.active: await process_frame
	var center: Vector2 = camera.get_screen_center_position()
	check(world.player.position.x-32 > center.x-view.x*.5 and world.player.position.x < center.x-view.x*.25,"final camera frames player near opposite edge")
	check(cave.boss.position.x > center.x+view.x*.25 and cave.boss.position.x < center.x+view.x*.5,"boss is near far edge, not centered")
	check(camera.zoom == Vector2.ONE and world.dialogue.lines[0].text == "Welcome to the underground.","camera preserves zoom and exact boss greeting")
	await finish()
	await settle()
	check(current_scene.name == "Boss4PlaceholderHost" and current_scene.arena.size == Vector2i(540,900),"advancing greeting opens fixed-size placeholder battle")
	var flags: Dictionary = session.story_flags.duplicate()
	current_scene.record_victory()
	check(session.story_flags == flags and not flags.has("boss4_defeated"),"placeholder cannot grant victory or progression")
	current_scene.retry()
	await settle()
	check(current_scene.map.current_room == 8 and not current_scene.map.intro_started and not session.cave_event_active,"retry returns to safe Area 8 for replay, not healed/rewarded completion")
	var old_fog: Dictionary = session.exploration.snapshot()
	var legacy_bytes := PackedByteArray()
	legacy_bytes.resize(10240)
	legacy_bytes.fill(0)
	legacy_bytes[10] = 1
	old_fog.underground_cave = Marshalls.raw_to_base64(legacy_bytes)
	var legacy: Dictionary = session.saves.validate({"version":1,"area":"underground_cave","position":[19000,15000],"story_flags":{"unrelated_flag":true},"exploration":old_fog})
	check(not legacy.is_empty() and legacy.position == [Plan.ENTRY.x,Plan.ENTRY.y] and legacy.story_flags.unrelated_flag,"old cave save relocates safely without losing unrelated flags")
	check(legacy.story_flags.underground_cave_discovered and legacy.exploration.entrance == old_fog.entrance,"migration retains cave discovery and other-region fog")
	var v2_bytes := PackedByteArray()
	v2_bytes.resize(1196)
	v2_bytes.fill(0)
	v2_bytes[20] = 1
	var v2_fog: Dictionary = old_fog.duplicate()
	v2_fog.underground_cave = Marshalls.raw_to_base64(v2_bytes)
	var v2_save: Dictionary = session.saves.validate({"version":1,"area":"underground_cave","position":[6200,5000],"exploration":v2_fog,"story_flags":{"cave_redesign_layout_v2":true,"cave_red_key_obtained":true,"cave_red_barrier_unlocked":true}})
	check(not v2_save.is_empty() and v2_save.position == [Plan.ENTRY.x,Plan.ENTRY.y] and v2_save.story_flags.cave_red_key_obtained and v2_save.story_flags.cave_red_barrier_unlocked,"previous ten-room save migrates with key and barrier progress intact")
	check(session.saves.write_save(legacy) and await session.load_game(),"migrated save can actually be loaded")
	await settle()
	check(current_scene.player.position == Plan.ENTRY and not collision(current_scene,Plan.ENTRY),"legacy load restores valid entrance position")
	for voice in root.get_node("Music").get_children():
		if voice is AudioStreamPlayer: voice.stop()
	current_scene.map.get_node("UndergroundAtmosphere").bed.stop()
	await create_timer(.15).timeout
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(session.saves.save_path+suffix)
	print("CAVE REDESIGN: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
