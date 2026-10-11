extends SceneTree

const Layout = preload("res://scripts/maps/world_layout.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var cache: Texture2D = load("res://resources/maps/world_terrain.res")
	var hashes: Dictionary = cache.get_meta("source_hashes",{})
	check(not hashes.is_empty(),"generated map records level/asset fingerprints")
	for path in hashes: check(hashes[path] == FileAccess.get_sha256(path),"map cache matches "+path)
	check(cache.get_size() == Vector2(Layout.SIZE),"terrain cache has bounded low resolution")
	for area in Layout.REGIONS:
		var region: Dictionary = Layout.REGIONS[area]
		var map: Node2D = load("res://scenes/world/"+region.scene+".tscn").instantiate()
		root.add_child(map)
		await physics_frame
		await physics_frame
		check(map.map_size == Vector2(region.size*16),area+" keeps expanded dimensions")
		var ground: TileMapLayer = map.get_node("GrassGround")
		var grass_choices := {}
		for cell in ground.get_used_cells(): grass_choices[ground.get_cell_atlas_coords(cell)] = true
		check(grass_choices.size() == 4 and ground.tile_set.get_source(0).texture.resource_path == "res://assets/enironment/gfx/Overworld.png",area+" uses four original GFX grass tiles")
		check(map.get_node("GFXForestFloor").get_used_cells().size() > 0 and not map.get_node("GFXForestFloor").collision_enabled,area+" has nonblocking forest-floor patches")
		var total := 0
		var sources := {}
		var small_trunks := true
		var solid_trunks := true
		var canopy_passable := true
		var query := PhysicsShapeQueryParameters2D.new()
		var foot := CircleShape2D.new()
		foot.radius = 2
		query.shape = foot
		query.collision_mask = 1
		for label in ["GFXTreesSmall","GFXTreesMedium","GFXTreesLarge"]:
			var trees: TileMapLayer = map.get_node(label)
			check(trees.y_sort_enabled and trees.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and trees.collision_enabled,area+" "+label+" uses crisp Y-sorted colliding tiles")
			total += trees.get_used_cells().size()
			for cell in trees.get_used_cells():
				sources[trees.get_cell_source_id(cell)] = true
				var tile := trees.get_cell_tile_data(cell)
				var polygon := tile.get_collision_polygon_points(0,0)
				var rect := Rect2(polygon[0],Vector2.ZERO)
				for point in polygon: rect = rect.expand(point)
				small_trunks = small_trunks and rect.get_area() < 100 and tile.y_sort_origin == int(rect.end.y)
				query.transform = Transform2D(0,trees.to_global(trees.map_to_local(cell)+rect.get_center()))
				solid_trunks = solid_trunks and not map.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()
				# Upper canopy should remain non-solid; pick an isolated tree example.
				if trees.get_used_cells().find(cell) == 0:
					query.transform = Transform2D(0,trees.to_global(trees.map_to_local(cell)+Vector2(0,-10)))
					canopy_passable = canopy_passable and map.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()
		check(total >= {"entrance":40,"deep_forest":350,"bart_area":50,"flooded_forest":250}[area],area+" noticeably denser GFX vegetation: "+str(total))
		check(sources.has(0) and sources.has(1),area+" mixes Overworld and objects foliage")
		check(small_trunks and solid_trunks,area+" tree collision is confined to actual trunks")
		check(canopy_passable,area+" upper canopy can be walked beneath")
		var stones: TileMapLayer = map.get_node("GFXBoulders")
		check(stones.get_used_cells().size() > 0 and stones.collision_enabled,area+" contains blocking boulders")
		var stone_cell: Vector2i = stones.get_used_cells()[0]
		query.transform = Transform2D(0,stones.to_global(stones.map_to_local(stone_cell)+Vector2(0,2)))
		check(not map.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(),area+" actual boulder collision blocks movement")
		var plants: TileMapLayer = map.get_node("GFXUndergrowth")
		check(plants.get_used_cells().size() >= 150 and not plants.collision_enabled and plants.tile_set.get_physics_layers_count() == 0,area+" flowers and shrubs are walkable")
		var path: TileMapLayer = map.get_node("WindingTrails" if area == "flooded_forest" else "Paths")
		check(path.tile_set == ground.tile_set and not path.collision_enabled,area+" paths reuse GFX tiles without adding walls")
		for water_label in ["ExpansionWater"]+(["PlaceholderWater"] if area == "flooded_forest" else []):
			var lake: TileMapLayer = map.get_node(water_label)
			check(lake.tile_set.get_source(0).texture.resource_path == "res://assets/enironment/gfx/Overworld.png" and lake.collision_enabled,area+" "+water_label+" uses GFX water with preserved collision")
		map.free()
	print("GFX FOREST VALIDATION: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
