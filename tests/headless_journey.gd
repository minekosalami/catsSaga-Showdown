extends SceneTree
const Plan = preload("res://scripts/journey/layout.gd")
const Layout = preload("res://scripts/maps/world_layout.gd")
var checks := 0
var failures := 0
var session: Node
var density := {}
func _initialize() -> void:
	create_timer(120).timeout.connect(func():quit(1))
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: "+message)
func grid_for(world: Node) -> AStarGrid2D:
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
	var physics: PhysicsDirectSpaceState2D = world.get_world_2d().direct_space_state
	for y in grid.region.size.y:
		for x in grid.region.size.x:
			var cell := Vector2i(x,y)
			query.transform = Transform2D(0,Vector2(cell)*32+Vector2.ONE*16)
			grid.set_point_solid(cell,not physics.intersect_shape(query,1).is_empty())
	return grid
func reachable(grid: AStarGrid2D,from: Vector2,target: Vector2,radius := 50.0) -> bool:
	var origin := Vector2i(from/32)
	var best := Vector2i(target/32)
	for y in range(-3,4):
		for x in range(-3,4):
			var cell := best+Vector2i(x,y)
			if not grid.region.has_point(cell) or grid.is_point_solid(cell) or (Vector2(cell)*32+Vector2.ONE*16).distance_to(target)>radius:continue
			if not grid.get_id_path(origin,cell).is_empty():return true
	return false
func run() -> void:
	session = root.get_node("Session")
	session.saves.save_path = "user://validation-journey.json"
	await session.new_game()
	check(session.story_flags.get(Plan.REVISION,false),"new save identifies active layout")
	for area in Plan.ORDER:
		await session.travel(area,"Start")
		await physics_frame
		await physics_frame
		var world: Node = current_scene
		check(world.map.map_size==Plan.SIZES[area],area+" preserves original bounds")
		check(world.player.sprite.texture.resource_path=="res://assets/player/player.png.png",area+" preserves supplied player art")
		check(world.map.get_node("Water").tile_set.get_source(0).texture.resource_path=="res://assets/environment_human/lpc/watergrass.png",area+" uses licensed human terrain")
		check(world.map.get_meta("tree_count")>400,area+" has dense woodland")
		var grid := grid_for(world)
		var east: Vector2 = Plan.points(area)[-1]-Vector2(40,0) if area=="flooded_forest" else Vector2(world.map.map_size.x-224,Plan.SEAM_Y)
		check(reachable(grid,world.player.position,east),area+" has a continuous real-collider route west to east")
		var probe := PhysicsShapeQueryParameters2D.new()
		probe.shape = world.player.get_node("CollisionShape2D").shape
		probe.collision_mask = 1
		probe.exclude = [world.player.get_rid()]
		var total := 0
		var open := 0
		for y in range(2,grid.region.size.y-2,7):
			for x in range(2,grid.region.size.x-2,9):
				var cell := Vector2i(x,y)
				if grid.is_point_solid(cell):continue
				probe.transform = Transform2D(0,Vector2(cell)*32+Vector2.ONE*16)
				for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
					var motion: Vector2 = direction*world.player.speed*5
					if not Rect2(Vector2(48,48),world.map.map_size-Vector2(96,96)).has_point(probe.transform.origin+motion):continue
					probe.motion = motion
					var result: PackedFloat32Array = world.get_world_2d().direct_space_state.cast_motion(probe)
					total+=1
					if result[0]>=.999:open+=1
		var fraction := float(open)/maxi(1,total)
		density[area] = {"five_second_clear_directions":open,"sampled_directions":total,"clear_fraction":fraction}
		check(fraction<.10,area+" rarely permits five straight seconds without an obstacle")

		for npc in world.map.get_node("Characters").get_children():
			check(reachable(grid,world.player.position,npc.position,100),area+" interaction is reachable: "+npc.name)
		for mark in world.map.get_node("Discoveries").get_children():
			check(reachable(grid,world.player.position,mark.position,65),area+" branch remains reachable: "+mark.name)
		for portal in world.map.get_node("Portals").get_children():
			check(Plan.active(portal.destination),area+" only connects to active geography")
			var index := Plan.ORDER.find(area)
			check(Plan.ORDER.find(portal.destination)==index+(-1 if portal.position.x<300 else 1),area+" correct horizontal neighbor")
			var expected: float = Layout.REGIONS[area].offset.y*16+portal.position.y
			check(is_equal_approx(expected,Plan.SEAM_Y),area+" aligned world seam")
		var first: StaticBody2D = world.map.get_tree().get_nodes_in_group("journey_trees")[0]
		var shape: CapsuleShape2D = first.get_node("CollisionShape2D").shape
		check(first.get_node("Sprite2D").modulate.a==1 and first.get_node("Sprite2D").self_modulate.a==1,area+" opaque canopy")
		check(is_equal_approx(shape.radius,9*first.size_multiplier),area+" trunk collision scales with art")
		var bridges: TileMapLayer = world.map.get_node("Bridges")
		var water: TileMapLayer = world.map.get_node("Water")
		for cell in bridges.get_used_cells():
			var data := water.get_cell_tile_data(cell)
			check(data==null or data.get_collision_polygons_count(0)==0,area+" crossing or dry abutment has no underwater collider")
		check(world.map.get_node("Characters").find_children("*Cave*","",true,false).is_empty() and world.map.get_node("Characters").find_children("*Wonderland*","",true,false).is_empty(),area+" has no archived entrance objects")
		check(world.map_ui.visible_boss_markers().all(func(marker):return marker.id not in ["wonderland_door","underground_cave"]),area+" has no archived entrance markers")
		if area=="bart_area":
			var gate: Area2D = world.map.get_node("Portals/ToRight")
			check(not gate.can_travel(),"normal Flooded Forest gate remains locked")
			session.unrestricted_region_access = true
			check(gate.can_travel(),"existing gate bypass still works")
			session.unrestricted_region_access = false
			session.evil_bart_defeated = true
			session.grant_flooded_key()
			check(gate.can_travel(),"Bart victory still opens Flooded Forest")
	var before: String = session.area_id
	for inactive in ["underground_cave","wonderland_forest","tea_gardens","queens_castle"]:
		await session.travel(inactive,"Start")
		check(session.area_id==before and current_scene.name=="Overworld","archived travel is refused: "+inactive)
	check(not await session.transition_to("res://scenes/incarna/combat_host.tscn",true),"Incarna cannot enter active play")
	# Migration reads original data without touching the source file or old flags.
	for inactive in ["underground_cave","wonderland_forest","mushroom_cottage"]:
		var flags := {"cave_redesign_layout_v2":true,"cave_settlement_layout_v3":true,"cave_red_key_obtained":true,"incarna_defeated":true,"blankkitten_defeated":true}
		var old := {"version":1,"area":inactive,"position":[400,400],"evil_bart_defeated":true,"story_flags":flags,"exploration":session.exploration.snapshot()}
		var migrated: Dictionary = session.saves.validate(old)
		check(not migrated.is_empty() and migrated.area=="flooded_forest",inactive+" save safely relocates")
		check(migrated.story_flags.get("incarna_defeated",false),inactive+" preserves inactive victory")
		check(migrated.story_flags.cave_red_key_obtained and migrated.story_flags.blankkitten_defeated,inactive+" preserves keys and other bosses")
		check(migrated.exploration==old.exploration,inactive+" preserves exploration bytes")
		check(old.area==inactive and old.position==[400,400],inactive+" validation leaves input save untouched")
	var statue: Node2D=current_scene.map.find_child("CatSaveStatue",true,false)
	current_scene.player.position=statue.position+Vector2(0,58)
	session.open_save_point(statue)
	session.confirmation.confirmed.emit()
	check(not session.saves.read_slot(session.active_slot).is_empty(),"active progress saves after deliberate statue confirmation")
	check(await session.load_game(),"active progress reloads")
	check(session.area_id=="flooded_forest" and session.story_flags.flooded_forest_key_obtained,"reload preserves final-region access")
	check(not paused and not session.busy,"player remains free to explore")
	print("DENSITY SURVEY: ",JSON.stringify(density))
	print("JOURNEY VALIDATION: ",checks," checks, ",failures," failures")
	await session.main_menu()
	root.get_node("Music").play_theme("")
	quit(1 if failures else 0)
