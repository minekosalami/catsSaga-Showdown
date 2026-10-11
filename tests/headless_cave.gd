extends SceneTree
const Plan = preload("res://scripts/world/cave_layout.gd")
const Layout = preload("res://scripts/maps/world_layout.gd")
var checks := 0
var failures := 0
var session: Node
func _initialize() -> void:
	create_timer(120).timeout.connect(func(): quit(1))
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+message)
func key(code: Key, pressed: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func press(code: Key) -> void:
	key(code,true)
	await process_frame
	key(code,false)
	await process_frame
func collision(world: Node, point: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = world.player.get_node("CollisionShape2D").shape
	query.transform = Transform2D(0,point)
	query.collision_mask = 1
	return not world.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()
func reachable(world: Node, start: Vector2, end: Vector2, size: Vector2i, step: int) -> bool:
	var a := Vector2i(start/step)
	var b := Vector2i(end/step)
	var queue: Array[Vector2i] = [a]
	var visited := {a:true}
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		if cell == b: return true
		for delta in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next: Vector2i = cell+delta
			if next.x < 0 or next.y < 0 or next.x >= size.x or next.y >= size.y or visited.has(next): continue
			visited[next] = true
			var point := Vector2(next*step)+Vector2.ONE*step*.5
			if world.map.has_method("is_walkable_position") and not world.map.is_walkable_position(point): continue
			if not collision(world,point): queue.append(next)
	return false
func preserves_bits(before: String, after: String) -> bool:
	var a := Marshalls.base64_to_raw(before)
	var b := Marshalls.base64_to_raw(after)
	if a.size() != b.size(): return false
	for i in a.size():
		if (a[i] & b[i]) != a[i]: return false
	return true
func run() -> void:
	session = root.get_node("Session")
	session.saves.save_path = "user://validation-cave.json"
	await session.new_game()
	var original_fog: Dictionary = session.exploration.snapshot()
	session.evil_bart_defeated = true
	session.story_flags = {"flooded_forest_key_obtained":true,"boss2_defeated":true,"boss2_victory_dialogue_seen":true,"unrelated_flag":true}
	await session.travel("flooded_forest","FromDeep")
	var world: Node = current_scene
	await physics_frame
	await physics_frame
	var hole: Node2D = world.map.get_node("Characters/CaveHole")
	var entry: Vector2 = world.map.get_node("Entries/FromCave").position
	check(not collision(world,hole.position) and not collision(world,entry),"hole and return arrival are clear of existing obstacles")
	check(reachable(world,world.player.position,hole.position,Vector2i(256,192),16),"hole reachable from Flooded Forest entry with actual player collision")
	world.player.position = hole.position+Vector2(0,70)
	await process_frame
	await process_frame
	check(world.nearest_npc == hole,"existing interaction system selects cave opening")
	await press(KEY_Z)
	check(session.busy,"Z latches the descent immediately")
	var before_id: int = world.get_instance_id()
	key(KEY_Z,true,true)
	key(KEY_Z,false)
	while session.busy: await process_frame
	world = current_scene
	await physics_frame
	await physics_frame
	check(session.area_id == "underground_cave" and world.get_instance_id() != before_id,"descent changes to one continuous underground region")
	check(world.map.map_size == Vector2(20480,16384) and world.map.get_meta("chamber_count") == 14,"large map has fourteen authored chambers")
	check(world.player.position == world.map.get_node("Entries/FromFlooded").position and not collision(world,world.player.position),"safe cave arrival")
	check(root.get_node("Music").current_theme == "" and world.map.get_node("UndergroundAtmosphere").bed.playing,"forest song gives way to local underground ambience")
	var atmosphere: Node = world.map.get_node("UndergroundAtmosphere")
	await create_timer(.35).timeout
	check(atmosphere.bed.volume_db > -40 and atmosphere.has_been_revealed,"entry reveal does not permanently silence cave ambience")
	var start_position: Vector2 = world.player.position
	key(KEY_D,true)
	await create_timer(.2).timeout
	key(KEY_D,false)
	await create_timer(.1).timeout
	check(world.player.position.x > start_position.x+25,"normal keyboard movement works underground")
	await press(KEY_ESCAPE)
	check(paused and session.pause_menu.opened,"existing pause menu works underground")
	var paused_clock: float = atmosphere.clock
	await create_timer(.1).timeout
	check(is_equal_approx(atmosphere.clock,paused_clock),"cave atmosphere pauses with gameplay")
	await press(KEY_ESCAPE)
	check(not paused,"pause closes normally underground")
	check(Plan.network_length()/260/60 >= 6 and Plan.network_length()/260/60 <= 10,"passage-network traversal estimate is within six to ten minutes")
	# One flood search using real physics proves all room centers reachable.
	var floor: TileMapLayer = world.map.get_node("CaveFloor")
	var queue: Array[Vector2i] = [Plan.ROOMS[0].center]
	var visited := {queue[0]:true}
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		for delta in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next: Vector2i = cell+delta
			if visited.has(next) or floor.get_cell_source_id(next) < 0: continue
			var point := Vector2(next*32)+Vector2(16,16)
			if not world.map.is_walkable_position(point) or collision(world,point): continue
			visited[next] = true
			queue.append(next)
	for room in Plan.ROOMS: check(visited.has(room.center),room.name+" reachable with the actual 28px player body")
	check(world.map.get_node("Characters").get_child_count() == 1 and world.map.get_node("Portals").get_child_count() == 0,"cave has only return interaction, no combat/puzzles/internal scene changes")
	check(world.player.sprite.texture.resource_path == "res://assets/player/player.png.png","original player artwork retained")
	var water: TileMapLayer = world.map.get_node("CaveWater")
	var walls: TileMapLayer = world.map.get_node("CaveWalls")
	check(water.get_used_cells().size() > 0 and walls.get_used_cells().size() > 0,"actual cave atlas includes collision-backed water and rocky boundaries")
	for layer in [floor,water,walls,world.map.get_node("CaveRocks"),world.map.get_node("CaveRubble")]:
		check(layer.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and layer.scale == Vector2(2,2) and layer.tile_set.get_source(0).texture.resource_path.ends_with("gfx/cave.png"),"atlas grid and nearest filtering for "+layer.name)
	var future := Plan.center(13)
	check(not collision(world,future) and visited.has(Plan.ROOMS[13].center),"future boss cavern is empty and freely accessible")
	world.player.position = Plan.center(9)
	world.update_map_exploration()
	var forest_fog: String = session.exploration.snapshot().flooded_forest
	check(session.exploration.snapshot().entrance == original_fog.entrance,"underground discovery preserves forest exploration")
	await press(KEY_M)
	check(world.map_ui.opened and world.map_ui.full_map.map_area == "underground_cave","M opens independent underground map")
	check(world.map_ui.fog_image.get_size() == Vector2i(1280,1024) and world.map_ui.minimap.shader.get_shader_parameter("atlas_size") == Vector2(1280,1024),"cave map uses its own terrain/fog dimensions")
	check(world.map_ui.fog_image.get_pixel(1100,900).r == 0 and world.map_ui.minimap.shader.get_shader_parameter("terrain").get_image().get_pixel(1100,900).a == 1,"unexplored cave geometry stays concealed under uniform fog")
	check(world.map_ui.full_map.player_world == world.player.position/16,"cave player marker has correct local map coordinates")
	await press(KEY_M)
	var point: Vector2 = world.player.position
	check(session.save_current(),"saving underground succeeds with existing save architecture")
	var data: Dictionary = session.saves.read_save()
	check(data.version == 1 and data.area == "underground_cave" and data.story_flags.unrelated_flag,"cave save retains format and unrelated flags")
	var saved_fog: Dictionary = session.exploration.snapshot()
	await session.main_menu()
	check(await session.load_game(),"cave save loads")
	world = current_scene
	await physics_frame
	await physics_frame
	check(session.area_id == "underground_cave" and world.player.position == point,"load restores cave scene and exact safe position")
	check(session.exploration.snapshot() == saved_fog,"all region fog survives save/load")
	var return_point: Node2D = world.map.get_node("Characters/ClimbToForest")
	world.player.position = return_point.position+Vector2(0,50)
	await process_frame
	await process_frame
	await press(KEY_Z)
	check(session.busy,"climb is Z-triggered and latched")
	while session.busy: await process_frame
	world = current_scene
	check(session.area_id == "flooded_forest" and world.player.position == entry,"return restores safe Flooded Forest arrival")
	check(world.map_ui.fog_image.get_size() == Layout.SIZE and world.map_ui.full_map.map_area == "flooded_forest","forest map restored after cave exit")
	check(preserves_bits(forest_fog,session.exploration.snapshot().flooded_forest),"forest fog preserved across cave round trip")
	await session.travel("underground_cave","FromFlooded")
	check(preserves_bits(saved_fog.underground_cave,session.exploration.snapshot().underground_cave),"cave fog preserved after re-entry")
	# Invalid-but-in-bounds saved positions in unexcavated void fall back safely.
	var bad: Dictionary = session.snapshot("underground_cave",Vector2(19000,15500))
	check(session.saves.write_save(bad),"version-one cave save accepts bounded coordinates for spawn validation")
	await session.main_menu()
	check(await session.load_game(),"saved cave with invalid terrain position loads safely")
	await physics_frame
	await physics_frame
	check(current_scene.player.position == current_scene.map.get_node("Entries/FromFlooded").position,"void position falls back to safe entrance chamber")
	var legacy: Dictionary = session.saves.validate({"version":1,"area":"entrance","position":[280,450],"story_flags":{"old_custom":true},"exploration":{"entrance":saved_fog.entrance}})
	check(not legacy.is_empty() and legacy.story_flags.old_custom,"old partial-region saves load with empty cave fog")
	await session.main_menu()
	root.get_node("Music").play_theme("")
	await create_timer(.2).timeout
	print("CAVE VALIDATION: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
