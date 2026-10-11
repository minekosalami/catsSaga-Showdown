extends SceneTree

const SPECS := {
	"forest_entrance": [Vector2i(200,114),"Start",{"Start":Vector2(280,450),"FromDeep":Vector2(2992,992)}, {"InspectableTree":Vector2(450,280)}],
	"deep_forest": [Vector2i(320,180),"FromEntrance",{"FromEntrance":Vector2(208,992),"FromBart":Vector2(208,2816),"FromFlooded":Vector2(1792,2672)}, {"ForestNPC":Vector2(900,430),"FloodedGate":Vector2(1750,1090)}],
	"bart_area": [Vector2i(200,114),"FromDeep",{"FromDeep":Vector2(2992,992)}, {"EvilBart":Vector2(1000,450)}],
	"flooded_forest": [Vector2i(256,192),"FromDeep",{"FromDeep":Vector2(1792,208)}, {"Boss2NPC":Vector2(1840,360)}],
}
var checks := 0
var failures := 0
var session: Node

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+message)

func _initialize() -> void:
	create_timer(70).timeout.connect(func(): quit(1))
	call_deferred("run")

func block_rect(grid: AStarGrid2D, rect: Rect2) -> void:
	# Expand actual solids by the player's 14px half-width. Mark tile centers.
	var grown := rect.grow(14.1)
	var minimum := Vector2i(floor(grown.position.x/16),floor(grown.position.y/16))
	var maximum := Vector2i(floor(grown.end.x/16),floor(grown.end.y/16))
	for y in range(maxi(0,minimum.y),mini(grid.region.size.y-1,maximum.y)+1):
		for x in range(maxi(0,minimum.x),mini(grid.region.size.x-1,maximum.x)+1):
			if grown.has_point(Vector2(x*16+8,y*16+8)): grid.set_point_solid(Vector2i(x,y))

func navigation(map: Node2D, size: Vector2i) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO,size)
	grid.cell_size = Vector2(16,16)
	grid.offset = Vector2(8,8)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for collider in map.find_children("*","CollisionShape2D",true,false):
		if collider.get_parent() is StaticBody2D and not collider.disabled:
			block_rect(grid,collider.global_transform*collider.shape.get_rect())
	for node in map.get_children():
		if node is TileMapLayer and node.collision_enabled and node.tile_set.get_physics_layers_count() > 0:
			for cell in node.get_used_cells():
				var data: TileData = node.get_cell_tile_data(cell)
				for index in data.get_collision_polygons_count(0):
					var polygon := data.get_collision_polygon_points(0,index)
					var rect := Rect2(node.to_global(node.map_to_local(cell)+polygon[0]),Vector2.ZERO)
					for point in polygon: rect = rect.expand(node.to_global(node.map_to_local(cell)+point))
					block_rect(grid,rect)
	return grid

func cell(point: Vector2) -> Vector2i:
	return Vector2i(floor(point.x/16),floor(point.y/16))

func run() -> void:
	session = root.get_node("Session")
	session.saves.save_path = "user://validation-overworld-expansion.json"
	var total := 0
	for filename in SPECS:
		var spec: Array = SPECS[filename]
		var size: Vector2i = spec[0]
		var map: Node2D = load("res://scenes/world/"+filename+".tscn").instantiate()
		root.add_child(map)
		await physics_frame
		await physics_frame
		var ground: TileMapLayer = map.get_node("GrassGround")
		var count := size.x*size.y
		total += count
		check(map.map_size == Vector2(size*16) and ground.get_used_rect() == Rect2i(Vector2i.ZERO,size) and ground.get_used_cells().size() == count,filename+" fully painted doubled tile grid")
		var nav := navigation(map,size)
		var start: Vector2i = cell(map.get_node("Entries/"+spec[1]).position)
		var query := PhysicsShapeQueryParameters2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(28,28)
		query.shape = shape
		query.collision_mask = 1
		for label in spec[2]: check(map.get_node("Entries/"+label).position == spec[2][label],filename+" aligned safe arrival "+label)
		for label in spec[3]: check(map.get_node("Characters/"+label).position == spec[3][label],filename+" preserved character "+label)
		for group in ["Entries","Portals","Discoveries"]:
			for marker in map.get_node(group).get_children():
				query.transform = Transform2D(0,marker.position)
				check(map.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(),filename+" actual player fits "+group+"/"+marker.name)
				check(not nav.get_id_path(start,cell(marker.position)).is_empty(),filename+" walking route reaches "+group+"/"+marker.name)
		check(map.get_node("Discoveries").get_child_count() == 6,filename+" has six empty, reachable environmental discoveries")
		var water: TileMapLayer = map.get_node("ExpansionWater")
		check(water.get_used_cells().size() > 150 and water.tile_set.resource_path == "res://resources/world/gfx_water.tres",filename+" uses shared GFX water resource")
		query.transform = Transform2D(0,water.map_to_local(water.get_used_cells()[0]))
		check(not map.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(),filename+" new water blocks actual player collision shape")
		var shore := Vector2.ZERO
		for wet_cell in water.get_used_cells():
			var approach := water.map_to_local(wet_cell)-Vector2(48,0)
			query.transform = Transform2D(0,approach)
			if map.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty():
				shore = approach
				break
		var walker := CharacterBody2D.new()
		walker.position = shore
		walker.collision_layer = 2
		walker.collision_mask = 1
		var foot := CollisionShape2D.new()
		foot.shape = shape
		walker.add_child(foot)
		root.add_child(walker)
		await physics_frame
		var collision := walker.move_and_collide(Vector2(64,0))
		check(shore != Vector2.ZERO and collision != null and collision.get_collider() == water,filename+" actual moving CharacterBody cannot enter new water")
		walker.free()
		check(not map.get_node("MeadowDetails").collision_enabled,filename+" decorative flowers do not collide")
		var area: String = {"forest_entrance":"entrance","deep_forest":"deep_forest","bart_area":"bart_area","flooded_forest":"flooded_forest"}[filename]
		var far: Vector2 = map.get_node("Discoveries/FarGlade").position
		var save: Dictionary = session.saves.validate({"version":1,"area":area,"position":[far.x,far.y],"story_flags":{"unrelated_old_flag":true}})
		check(not save.is_empty() and save.story_flags.unrelated_old_flag,filename+" V1 saves accept far clearing and retain unrelated flags")
		check(session.saves.validate({"version":1,"area":area,"position":[map.map_size.x+16,far.y]}).is_empty(),filename+" saves still reject outside coordinates")
		map.free()
	check(total == 152352,"combined authored overworld is 152352 tiles, four times 38088")
	# Exercise real body-entered signals and transitions, including safe return spawns.
	await session.new_game()
	for route in [["entrance","Start","ToBart","bart_area","FromEntranceShortcut","bart_defeated"],["bart_area","FromDeep","ToEntrance","entrance","FromBartShortcut","bart_defeated"],["bart_area","FromDeep","ToFlooded","flooded_forest","FromBartShortcut","boss2_defeated"],["flooded_forest","FromDeep","ToBart","bart_area","FromFloodedShortcut","boss2_defeated"]]:
		session.evil_bart_defeated = true
		session.story_flags = {"bart_defeated":true,"flooded_forest_key_obtained":true,"bart_victory_dialogue_seen":true,"boss2_defeated":false}
		await session.travel(route[0],route[1])
		var world: Node = current_scene
		var portal: Area2D = world.map.get_node("Portals/"+route[2])
		session.story_flags[route[5]] = false
		world.player.position = portal.position
		for i in 4: await physics_frame
		check(current_scene == world and not portal.can_travel(),route[0]+" shortcut cannot bypass undefeated "+route[5])
		world.player.position = portal.position+Vector2(0,150)
		for i in 3: await physics_frame
		session.story_flags[route[5]] = true
		check(portal.can_travel(),route[0]+" shortcut unlocks after required victory")
		world.player.position = portal.position
		await create_timer(0.9).timeout
		check(session.area_id == route[3] and current_scene != world,"real "+route[0]+" shortcut transitions to "+route[3])
		world = current_scene
		check(world.player.position.distance_to(world.map.get_node("Entries/"+route[4]).position) < 1,"shortcut arrival uses safe paired marker "+route[4])
		await create_timer(0.3).timeout
		check(current_scene == world,"shortcut arrival does not bounce into return portal")
	# Save and reload an actual newly reachable position.
	await session.travel("deep_forest","FromEntrance")
	current_scene.player.position = current_scene.map.get_node("Discoveries/FarGlade").position
	var saved_position: Vector2 = current_scene.player.position
	check(session.save_current(),"save far expanded-world position")
	await session.load_game()
	for i in 4: await physics_frame
	check(current_scene.player.position.distance_to(saved_position) < 1,"expanded-world position survives real save/load")
	current_scene.queue_free()
	await process_frame
	for suffix in ["",".bak",".tmp"]: DirAccess.remove_absolute(session.saves.save_path+suffix)
	print("OVERWORLD EXPANSION VALIDATION: ",checks," checks, ",failures," failures")
	root.get_node("Music").play_theme("")
	await create_timer(0.2).timeout
	quit(0 if failures == 0 else 1)
