extends SceneTree
const Plan = preload("res://scripts/wonderland/layout.gd")
const Layout = preload("res://scripts/maps/world_layout.gd")
var session: Node
var checks := 0
var failures := 0
var grids: Dictionary = {}
func _initialize() -> void:
	create_timer(240).timeout.connect(func(): push_error("Wonderland test timeout"); quit(1))
	call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: "+message)
func key(code: Key,pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func settle() -> void:
	await physics_frame
	await physics_frame
	await process_frame
func grid_for_world() -> AStarGrid2D:
	var id: String = session.area_id
	if grids.has(id): return grids[id]
	var world: Node2D = current_scene
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO,Vector2i(world.map.map_size/32))
	grid.cell_size = Vector2.ONE*32
	grid.offset = Vector2.ONE*16
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = world.player.get_node("CollisionShape2D").shape
	query.collision_mask = 1
	query.exclude = [world.player.get_rid()]
	var space := world.get_world_2d().direct_space_state
	for y in grid.region.size.y:
		for x in grid.region.size.x:
			var cell := Vector2i(x,y)
			var point := Vector2(cell)*32+Vector2.ONE*16
			query.transform = Transform2D(0,point)
			var blocked: bool = not space.intersect_shape(query,1).is_empty()
			if world.map.has_method("is_walkable_position"): blocked = blocked or not world.map.is_walkable_position(point)
			grid.set_point_solid(cell,blocked)
	grids[id] = grid
	return grid
func route(start: Vector2,end: Vector2,description: String) -> PackedVector2Array:
	var grid := grid_for_world()
	var a := Vector2i(start/32)
	var b := Vector2i(end/32)
	var found := grid.get_point_path(a,b)
	check(not found.is_empty(),description+" has a walkable route")
	return found
func walk_route(points: PackedVector2Array) -> void:
	if points.is_empty(): return
	current_scene.player.position = points[0]
	for i in range(1,points.size()):
		current_scene.player.velocity = Vector2.ZERO
		var hit: KinematicCollision2D = current_scene.player.move_and_collide(points[i]-current_scene.player.position)
		if hit != null:
			check(false,"physical route blocked at "+str(points[i]))
			return
		current_scene.update_map_exploration()
		if i%12 == 0: await physics_frame
	await settle()
func cross(name: String,direction: Vector2,expected: String) -> void:
	var world: Node2D = current_scene
	var portal: Area2D = world.map.get_node("Portals/"+name)
	world.player.position = portal.position-direction*(240 if name == "ToWonderland" else 80)
	world.player.velocity = Vector2.ZERO
	await settle()
	var code: Key = KEY_RIGHT if direction.x>0 else (KEY_LEFT if direction.x<0 else (KEY_DOWN if direction.y>0 else KEY_UP))
	key(code,true)
	for i in range(100):
		await physics_frame
		if session.area_id == expected: break
	key(code,false)
	while session.busy: await process_frame
	await settle()
	check(session.area_id == expected,"physical doorway "+name+" reaches "+expected)
func run() -> void:
	root.size = Vector2i(1280,720)
	session = root.get_node("Session")
	session.saves.save_path = "user://validation-wonderland.json"
	await session.new_game()
	session.evil_bart_defeated = true
	session.story_flags["boss2_defeated"] = true
	session.story_flags["cave_red_barrier_unlocked"] = true
	await session.travel("flooded_forest","FromWonderland")
	await settle()
	var door: Node = current_scene.map.get_node("WonderlandEntrance/PinkWonderlandDoor")
	check(door.global_position == Plan.FLOODED_DOOR,"door uses actual north-edge coordinates")
	check(not current_scene.map.get_node("Portals/ToWonderland").can_travel(),"pink entrance locked without key")
	door.handle_interaction(current_scene)
	check(not session.story_flags.get(Plan.DOOR_OPEN,false),"inspecting door grants no item/unlock")
	current_scene.player.position = Plan.FLOODED_DOOR+Vector2(0,144)
	check(current_scene.player.move_and_collide(Vector2(0,-220)) != null and current_scene.player.position.y >= Plan.FLOODED_DOOR.y+31,"closed pink door physically blocks its boundary passage")
	await session.travel("underground_cave","FromFlooded")
	await settle()
	var chest: Node = current_scene.map.get_node("IncarnaWonderlandChest")
	check(chest.position.x > current_scene.map.boss.position.x,"chest is physically beyond Incarna")
	check(not chest.can_interact(),"pre-victory chest inaccessible")
	chest.handle_interaction(current_scene)
	check(not session.story_flags.get(Plan.PINK_KEY,false),"pre-victory interaction cannot grant key")
	session.encounter_id = "incarna"
	session.encounter_active = true
	session.return_position = preload("res://scripts/world/cave_layout.gd").SHORTCUT_JUNCTION+Vector2(0,160)
	await session.transition_to("res://scenes/incarna/combat_host.tscn",true)
	current_scene.battle.music_player.stop()
	current_scene.battle.update_clock(preload("res://scripts/incarna/config.gd").END)
	check(session.story_flags.get("incarna_defeated",false),"real Incarna completion records victory")
	check(not session.story_flags.get(Plan.PINK_KEY,false),"victory does not automatically award key")
	current_scene.battle.ui.return_button.pressed.emit()
	while session.busy: await process_frame
	await settle()
	chest = current_scene.map.get_node("IncarnaWonderlandChest")
	await walk_route(route(current_scene.player.position,Plan.CHEST+Vector2(0,80),"junction to post-Incarna chest"))
	chest.handle_interaction(current_scene)
	check(session.story_flags.get(Plan.PINK_KEY,false) and session.story_flags.get(Plan.CHEST_OPEN,false),"physical chest interaction acquires permanent key")
	check(session.saves.read_save().story_flags.get(Plan.PINK_KEY,false),"key and chest saved")
	key(KEY_SPACE,true); key(KEY_SPACE,false)
	check(current_scene.map_ui.inventory_contents.text.contains("Pink Wonderland Key"),"existing inventory displays key")
	current_scene.map_ui.close_modals()
	var exit: Node
	for node in get_nodes_in_group("interactables"):
		if current_scene.map.is_ancestor_of(node) and node.get_script().resource_path == "res://scripts/world/cave_connection.gd": exit = node
	await walk_route(route(current_scene.player.position,exit.global_position+Vector2(0,70),"walk back through cave to surface"))
	exit.handle_interaction(current_scene)
	while session.busy: await process_frame
	await settle()
	check(session.area_id == "flooded_forest","normal cave exit returns to Flooded Forest")
	await walk_route(route(current_scene.player.position,Plan.FLOODED_DOOR+Vector2(0,144),"surface path to pink door"))
	door = current_scene.map.get_node("WonderlandEntrance/PinkWonderlandDoor")
	door.handle_interaction(current_scene)
	check(session.story_flags.get(Plan.DOOR_OPEN,false),"key interaction persistently unlocks doorway")
	await cross("ToWonderland",Vector2.UP,"wonderland_forest")
	check(current_scene.player.position.distance_to(Vector2(1280,1728))<30,"south arrival position is correct")
	var movement_start: Vector2 = current_scene.player.global_position
	key(KEY_W,true); key(KEY_SHIFT,true)
	await create_timer(.35).timeout
	check(is_equal_approx(current_scene.player.velocity.length(),390.0) and current_scene.player.global_position.distance_to(movement_start)>50,"WASD and Shift sprint work in Wonderland")
	key(KEY_W,false); key(KEY_SHIFT,false)
	await create_timer(.25).timeout
	session.save_current()
	var outdoor_fog: String = session.exploration.snapshot().wonderland_forest
	check(await session.load_game(),"save/reload Wonderland Forest")
	await settle()
	check(session.exploration.snapshot().wonderland_forest == outdoor_fog,"Wonderland outdoor fog persists exactly")
	for link in Plan.LINKS:
		if not Plan.OUTDOORS.has(link[0]): continue
		var a: String = link[0]
		var b: String = link[3]
		var from := "From_"+b
		await session.travel(a,from)
		await settle()
		var seam_a := Vector2(Plan.OUTDOORS[a].offset)*16+Plan.edge(a,link[1],link[2],0)
		var seam_b := Vector2(Plan.OUTDOORS[b].offset)*16+Plan.edge(b,link[4],link[5],0)
		check(seam_a == seam_b,"geographic seam aligns: "+a+" / "+b)
		var start: Vector2 = current_scene.map.get_node("Entries").get_child(0).position
		route(start,Plan.edge(a,link[1],link[2],128),a+" connection")
		await cross("To_"+b,-Plan.inward(link[1]),b)
		await cross("To_"+a,-Plan.inward(link[4]),a)
	await session.travel("wonderland_village","From_mushroom_thicket")
	await settle()
	for building in Plan.BUILDINGS:
		route(current_scene.player.position,building.point+Vector2(0,80),"village to "+building.name)
		await cross("Enter_"+building.id,Vector2.UP,building.id)
		check(Layout.visible_regions(building.id).size() == 1,"interior fog isolated from outdoor geography")
		var start: Vector2 = current_scene.player.position
		for target in [Vector2(640,700),Vector2(210,700),Vector2(1070,400)]: route(start,target,building.id+" floor")
		var saved_position: Vector2 = current_scene.player.position
		check(session.save_current(),"save inside "+building.id)
		var saved_fog: String = session.exploration.snapshot()[building.id]
		check(await session.load_game(),"reload inside "+building.id)
		await settle()
		check(current_scene.player.position.distance_to(saved_position)<.1 and session.exploration.snapshot()[building.id] == saved_fog,"interior position and fog persist: "+building.id)
		await cross("ExitToVillage",Vector2.DOWN,"wonderland_village")
		check(current_scene.player.position.distance_to(building.point+Vector2(0,104))<30,"return to specific exterior: "+building.id)
	await session.travel("queens_castle","From_royal_woods")
	await settle()
	check(not current_scene.map.get_node("Portals/CastleEntrance").can_travel(),"castle locked by default")
	current_scene.map.get_node("CastleGate").handle_interaction(current_scene)
	check(not session.story_flags.get(Plan.CASTLE_OPEN,false),"castle inspection creates no quest or unlock")
	current_scene.player.position = Vector2(1280,1030)
	check(current_scene.player.move_and_collide(Vector2(0,-240)) != null and current_scene.player.position.y >= 911,"normal castle gate physically blocks entry")
	session.unrestricted_region_access = true
	await settle()
	await cross("CastleEntrance",Vector2.UP,"castle_hall")
	for id in Plan.CASTLE_ROOMS:
		if id == "castle_hall": continue
		var link: Array = Plan.LINKS.filter(func(l: Array): return l[3] == id)[0]
		await cross("To_"+id,-Plan.inward(link[1]),id)
		route(current_scene.player.position,Vector2(640,480),id+" explorable floor")
		await cross("To_castle_hall",-Plan.inward(link[4]),"castle_hall")
	await cross("ExitToGrounds",Vector2.DOWN,"queens_castle")
	session.unrestricted_region_access = false
	await settle()
	check(not current_scene.map.get_node("Portals/CastleEntrance").can_travel(),"debug access never persists castle unlock")
	check(Plan.unlock_castle() and await session.load_game(),"future castle unlock interface saves/reloads")
	await settle()
	check(current_scene.map.get_node("Portals/CastleEntrance").can_travel(),"saved castle flag opens gate")
	check(session.story_flags.get(Plan.PINK_KEY,false) and session.story_flags.get(Plan.DOOR_OPEN,false),"key and pink door persist across all saves")
	key(KEY_M,true); key(KEY_M,false)
	check(current_scene.map_ui.opened,"existing M map works")
	var paused_position: Vector2 = current_scene.player.global_position
	key(KEY_W,true)
	await create_timer(.15).timeout
	key(KEY_W,false)
	check(current_scene.player.global_position == paused_position,"map modal blocks actual movement")
	current_scene.map_ui.close_modals()
	key(KEY_SPACE,true); key(KEY_SPACE,false)
	check(current_scene.map_ui.inventory_opened and current_scene.map_ui.inventory_contents.text.contains("Pink Wonderland Key"),"Space inventory works inside Wonderland")
	key(KEY_SPACE,true); key(KEY_SPACE,false)
	check(not current_scene.map_ui.inventory_opened,"Space closes Wonderland inventory")
	key(KEY_ESCAPE,true); key(KEY_ESCAPE,false)
	check(session.pause_menu.opened,"existing pause works")
	session.close_pause()
	await session.travel("wonderland_forest","FromFlooded")
	await settle()
	await cross("ToFlooded",Vector2.DOWN,"flooded_forest")
	check(current_scene.player.position.distance_to(Plan.FLOODED_DOOR+Vector2(0,144))<30,"surface return is at the correct pink entrance")
	await session.main_menu()
	print("WONDERLAND: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
