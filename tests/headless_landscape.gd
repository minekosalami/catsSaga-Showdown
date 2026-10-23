extends "res://tests/headless_journey.gd"
## Physics-backed connectivity of the authored paths, flooding and save clearings.
func run() -> void:
	if "--check-map-cache" in OS.get_cmdline_user_args():
		check_map_cache()
		return
	session=root.get_node("Session")
	session.saves.save_path="user://validation-landscape.json"
	await session.new_game()
	for area in Plan.ORDER:
		await session.travel(area,"Start")
		await physics_frame
		await physics_frame
		var world: Node=current_scene
		var map: Node2D=world.map
		var grid:=grid_for(world)
		check(map.map_size==Plan.SIZES[area],area+": original map bounds retained")
		check(map.has_meta("landscape_refinement"),area+": refinement is authored into the existing map")
		var east: Vector2=Plan.points(area)[-1]-Vector2(40,0) if area=="flooded_forest" else Vector2(map.map_size.x-224,Plan.SEAM_Y)
		check(reachable(grid,world.player.position,east),area+": west/east route traversable with actual player collision")
		for entry in map.get_node("Entries").get_children():
			check(reachable(grid,world.player.position,entry.position,64),area+": entry reachable "+entry.name)
		for npc in map.get_node("Characters").get_children():
			check(reachable(grid,world.player.position,npc.position,95),area+": NPC reachable "+npc.name)
		for discovery in map.get_node("Discoveries").get_children():
			check(reachable(grid,world.player.position,discovery.position,55),area+": landmark reachable "+discovery.name)
		var save_script: Script=load("res://scripts/world/save_statue.gd")
		var locations: Dictionary=save_script.get_script_constant_map().LOCATIONS
		var paths: TileMapLayer=map.get_node("Paths")
		var water: TileMapLayer=map.get_node("Water")
		var bridges: TileMapLayer=map.get_node("Bridges")
		for point: Vector2 in locations.get(area,[]):
			var cell:=Vector2i(point/32)
			check(paths.get_cell_source_id(cell)<0 and water.get_cell_source_id(cell)<0,area+": save star stands on grass")
			check(reachable(grid,world.player.position,point,85),area+": unobstructed save-star approach")
			var approach:=PhysicsShapeQueryParameters2D.new()
			approach.shape=world.player.get_node("CollisionShape2D").shape
			approach.collision_mask=world.player.collision_mask
			approach.exclude=[world.player.get_rid()]
			approach.transform=Transform2D(0,point+Vector2(0,58))
			check(world.get_world_2d().direct_space_state.intersect_shape(approach,1).is_empty(),area+": the actual player fits at the save star's below-facing interaction point")
		var query:=PhysicsShapeQueryParameters2D.new()
		query.shape=world.player.get_node("CollisionShape2D").shape
		query.collision_mask=1
		query.exclude=[world.player.get_rid()]
		var missing_water:=0
		var bridge_blocks:=0
		var bridge_water:=0
		for cell: Vector2i in water.get_used_cells():
			var data:=water.get_cell_tile_data(cell)
			query.transform=Transform2D(0,Vector2(cell)*32+Vector2.ONE*16)
			if bridges.get_cell_source_id(cell)>=0:
				bridge_water+=1
				if data.get_collision_polygons_count(0)>0:bridge_blocks+=1
			else:
				# Test the actual nonzero player shape. A zero-area point exactly
				# on a merged polygon's internal diagonal can return no hit.
				if data.get_collision_polygons_count(0)==0 or world.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty():missing_water+=1
		check(missing_water==0,area+": every water tile outside bridge decks is physically solid")
		check(bridge_blocks==0,area+": no hidden water collision beneath bridges")
		if area=="flooded_forest":
			var total: float=map.map_size.x*map.map_size.y/1024
			var count:=water.get_used_cells().size()
			check(count/total>.30 and count>=map.get_meta("pre_refinement_water_cells")*3,area+": coherent flooding covers over30% and triples original coverage")
			check(bridge_water>40,"existing bridges cross genuine water")
			for rect: Rect2i in map.get_meta("bridge_rects"):
				var y: int=rect.position.y+rect.size.y/2
				var left:=Vector2i(rect.position.x-1,y)
				var right:=Vector2i(rect.end.x,y)
				check(not grid.is_point_solid(left) and not grid.is_point_solid(right) and not grid.get_id_path(left,right).is_empty(),"bridge banks and deck remain physically connected "+str(rect))
				query.transform=Transform2D(0,Vector2(left)*32+Vector2.ONE*16)
				query.motion=Vector2(right-left)*32
				var sweep: PackedFloat32Array=world.get_world_2d().direct_space_state.cast_motion(query)
				check(sweep[0]>.999,"actual player collider crosses the entire bridge directly "+str(rect))
		print("LANDSCAPE PHYSICS ",area," water=",water.get_used_cells().size()," trees=",map.get_meta("tree_count"))
	await session.main_menu()
	print("LANDSCAPE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

func check_map_cache() -> void:
	var texture: Texture2D=load("res://resources/journey/world_terrain.res")
	check(texture.get_size()==Vector2(Layout.SIZE),"WORLD_MAP texture preserves the established combined atlas bounds")
	var hashes: Dictionary=texture.get_meta("source_hashes",{})
	var locations: Dictionary=texture.get_meta("boss_locations",{})
	for area in Plan.ORDER:
		var path: String=Plan.scene(area)
		check(hashes.get(path,"")==FileAccess.get_sha256(path),area+": WORLD_MAP cache matches the final authored terrain scene")
		var map: Node2D=load(path).instantiate()
		for pair in [["EvilBart","bart"],["Boss2NPC","boss2"],["BlankKitten","blankkitten"]]:
			var npc:=map.get_node_or_null("Characters/"+pair[0]) as Node2D
			if npc==null:continue
			var marker: Dictionary=locations.get(pair[1],{})
			check(marker.get("area","")==area and marker.get("local_position",Vector2.INF).is_equal_approx(npc.position),pair[1]+": map marker matches the unchanged overworld boss location")
		map.free()
	print("LANDSCAPE MAP CACHE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
