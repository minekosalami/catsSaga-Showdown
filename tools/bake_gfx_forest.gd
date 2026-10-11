extends SceneTree

## Editor-time bake: original PNGs stay intact; multi-cell features stay together.
const SCENES := ["forest_entrance", "deep_forest", "bart_area", "flooded_forest"]
var map: Node2D
var paths: TileMapLayer
var water_cells: Dictionary
var protected: Array[Vector2]
var clearings: Array[Vector2]
var original_canopies: Array[Rect2]
var random := RandomNumberGenerator.new()
var floor_noise := FastNoiseLite.new()
var woods_noise := FastNoiseLite.new()
var terrain: TileSet
var water: TileSet
var trees: TileSet
var props: TileSet
var plants: TileSet

func _initialize() -> void:
	call_deferred("run")

func source(texture_path: String) -> TileSetAtlasSource:
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load(texture_path)
	atlas.texture_region_size = Vector2i(16,16)
	return atlas

func physical_set(cell_size: int) -> TileSet:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(cell_size,cell_size)
	tiles.add_physics_layer()
	tiles.set_physics_layer_collision_layer(0,1)
	tiles.set_physics_layer_collision_mask(0,2)
	return tiles

func feature(atlas: TileSetAtlasSource, coordinate: Vector2i, extent: Vector2i, polygon: PackedVector2Array = []) -> void:
	atlas.create_tile(coordinate,extent)
	if not polygon.is_empty():
		var data := atlas.get_tile_data(coordinate,0)
		data.set_collision_polygons_count(0,1)
		data.set_collision_polygon_points(0,0,polygon)
		var trunk_base: float = polygon[0].y
		for point in polygon: trunk_base = maxf(trunk_base,point.y)
		data.y_sort_origin = int(trunk_base)

func resources() -> void:
	terrain = TileSet.new()
	var ground := source("res://assets/enironment/gfx/Overworld.png")
	terrain.add_source(ground,0)
	for tile in [Vector2i(5,9),Vector2i(7,9),Vector2i(5,10),Vector2i(8,10),Vector2i(17,30),Vector2i(18,30),Vector2i(1,30),Vector2i(2,32)]: feature(ground,tile,Vector2i.ONE)
	water = physical_set(16)
	var lake := source("res://assets/enironment/gfx/Overworld.png")
	water.add_source(lake,0)
	for tile in [Vector2i(1,1),Vector2i(2,7),Vector2i(3,7),Vector2i(4,7),Vector2i(2,8),Vector2i(3,8),Vector2i(4,8)]:
		feature(lake,tile,Vector2i.ONE,PackedVector2Array([Vector2(-8,-8),Vector2(8,-8),Vector2(8,8),Vector2(-8,8)]))
	trees = physical_set(32)
	var tree_atlas := source("res://assets/enironment/gfx/Overworld.png")
	trees.add_source(tree_atlas,0)
	var trunk := PackedVector2Array([Vector2(-3,8),Vector2(3,8),Vector2(4,12),Vector2(3,15),Vector2(-3,15),Vector2(-4,12)])
	feature(tree_atlas,Vector2i(5,16),Vector2i(2,2),trunk)
	var foliage := source("res://assets/enironment/gfx/objects.png")
	trees.add_source(foliage,1)
	for tile in [Vector2i(12,12),Vector2i(14,12),Vector2i(16,12)]: feature(foliage,tile,Vector2i(2,2),trunk)
	props = physical_set(32)
	var stone := source("res://assets/enironment/gfx/Overworld.png")
	props.add_source(stone,0)
	feature(stone,Vector2i(10,11),Vector2i(2,2),PackedVector2Array([Vector2(-11,0),Vector2(11,0),Vector2(12,12),Vector2(-12,12)]))
	plants = TileSet.new()
	var decorations := source("res://assets/enironment/gfx/Overworld.png")
	plants.add_source(decorations,0)
	for tile in [Vector2i(0,8),Vector2i(1,8),Vector2i(3,11),Vector2i(3,12)]: feature(decorations,tile,Vector2i.ONE)
	feature(decorations,Vector2i(0,14),Vector2i(1,2))
	for pair in [[terrain,"gfx_terrain"],[water,"gfx_water"],[trees,"gfx_trees"],[props,"gfx_boulders"],[plants,"gfx_plants"]]:
		var path: String = "res://resources/world/"+pair[1]+".tres"
		if ResourceSaver.save(pair[0],path) != OK: push_error("Failed to save "+path)
		pair[0].take_over_path(path)

func owned(node: Node) -> void:
	map.add_child(node)
	node.owner = map

func layer(label: String, tiles: TileSet, solid: bool, scale_factor: float, depth: int) -> TileMapLayer:
	var node := TileMapLayer.new()
	node.name = label
	node.tile_set = tiles
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.collision_enabled = solid
	node.navigation_enabled = false
	node.scale = Vector2.ONE*scale_factor
	node.z_index = depth
	node.y_sort_enabled = depth == 0
	owned(node)
	return node

func intersects_path(rect: Rect2) -> bool:
	var first := paths.local_to_map(rect.position)
	var last := paths.local_to_map(rect.end)
	for y in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			if paths.get_cell_source_id(Vector2i(x,y)) != -1: return true
	return false

func allowed(rect: Rect2, keep_clearings: bool = true) -> bool:
	if not Rect2(Vector2(48,48),map.map_size-Vector2(96,96)).encloses(rect): return false
	if intersects_path(rect.grow(10)): return false
	for point in protected:
		if rect.grow(96).has_point(point): return false
	if keep_clearings:
		for point in clearings:
			if rect.intersects(Rect2(point-Vector2(128,128),Vector2(256,256))): return false
	for original in original_canopies:
		if rect.intersects(original.grow(8)): return false
	for y in range(int(rect.position.y/16),int(rect.end.y/16)+1):
		for x in range(int(rect.position.x/16),int(rect.end.x/16)+1):
			if water_cells.has(Vector2i(x,y)): return false
	return true

func run() -> void:
	for filename in SCENES:
		var original: Node = load("res://scenes/world/"+filename+".tscn").instantiate()
		var baked := original.has_node("GFXTreesMedium")
		original.free()
		if baked:
			push_error("GFX forest already baked. Restore the previous scenes before rebaking.")
			quit(1)
			return
	resources()
	for index in SCENES.size():
		var filename: String = SCENES[index]
		map = load("res://scenes/world/"+filename+".tscn").instantiate()
		root.add_child(map)
		random.seed = 78100+index
		floor_noise.seed = 91400+index
		floor_noise.frequency = 0.07
		woods_noise.seed = 24500+index
		woods_noise.frequency = 0.007
		paths = map.get_node("WindingTrails" if index == 3 else "Paths")
		# Narrow only expanded-side path edges; keep all original progression routes.
		var all_paths: Dictionary = {}
		for cell in paths.get_used_cells(): all_paths[cell] = true
		var half: Vector2 = map.map_size/32.0
		for cell in all_paths:
			if cell.x < half.x and cell.y < half.y: continue
			var edge := false
			for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]: edge = edge or not all_paths.has(cell+step)
			if edge: paths.erase_cell(cell)
		var ground: TileMapLayer = map.get_node("GrassGround")
		ground.tile_set = terrain
		var forest_floor := layer("GFXForestFloor",terrain,false,1.0,-5)
		forest_floor.modulate.a = 0.38
		for cell in ground.get_used_cells():
			var noise := floor_noise.get_noise_2d(cell.x,cell.y)
			var choices := [Vector2i(5,9),Vector2i(7,9),Vector2i(5,10),Vector2i(8,10)]
			var tile: Vector2i = choices[random.randi_range(0,3)]
			if noise < -0.18: forest_floor.set_cell(cell,0,Vector2i(17,30) if noise < -0.28 else Vector2i(18,30))
			ground.set_cell(cell,0,tile)
		if index == 1: ground.modulate = Color(0.83,0.89,0.85)
		elif index == 2: ground.modulate = Color(0.93,0.90,0.87)
		paths.tile_set = terrain
		for cell in paths.get_used_cells(): paths.set_cell(cell,0,Vector2i(1,30) if floor_noise.get_noise_2d(cell.x,cell.y) > -0.12 else Vector2i(2,32))
		water_cells = {}
		for node in map.get_children():
			if node is TileMapLayer and node.tile_set.resource_path == "res://resources/world/placeholder_water.tres":
				for cell in node.get_used_cells(): water_cells[cell] = true
				node.tile_set = water
				for cell in node.get_used_cells():
					var tile := Vector2i(1,1)
					var upper := not water_cells.has(cell+Vector2i.UP)
					var lower := not water_cells.has(cell+Vector2i.DOWN)
					var left := not water_cells.has(cell+Vector2i.LEFT)
					var right := not water_cells.has(cell+Vector2i.RIGHT)
					if upper: tile = Vector2i(2 if left else (4 if right else 3),7)
					elif lower: tile = Vector2i(2 if left else (4 if right else 3),8)
					node.set_cell(cell,0,tile)
		protected.clear()
		clearings.clear()
		original_canopies.clear()
		for group in ["Entries","Portals","Characters"]:
			for marker in map.get_node(group).get_children(): protected.append(marker.position)
		for marker in map.get_node("Discoveries").get_children(): clearings.append(marker.position)
		for tree in get_nodes_in_group("world_trees"):
			if map.is_ancestor_of(tree):
				var sprite: Sprite2D = tree.get_node("Sprite2D")
				original_canopies.append(Rect2(tree.global_position+sprite.position,sprite.texture.get_size()*sprite.scale))
		var sizes := [2.6,3.2,3.8]
		var forests: Array[TileMapLayer] = []
		for i in 3: forests.append(layer("GFXTrees"+["Small","Medium","Large"][i],trees,true,sizes[i],0))
		var occupied: Array[Rect2] = []
		var count := 0
		var spacing := 104 if index == 1 else (116 if index == 0 else 110)
		for y in range(100,int(map.map_size.y)-100,spacing):
			for x in range(100,int(map.map_size.x)-100,spacing):
				var position := Vector2(x,y)+Vector2(random.randf_range(-22,22),random.randf_range(-22,22))
				var threshold := -0.65 if index == 1 else (-0.45 if index == 0 else -0.52)
				if woods_noise.get_noise_2d(position.x,position.y) < threshold: continue
				var weight := random.randf()
				var band := 0 if weight < 0.25 else (2 if weight > 0.90 else 1)
				var node: TileMapLayer = forests[band]
				var cell := node.local_to_map(position/node.scale)
				var center := node.map_to_local(cell)*node.scale
				var extent := Vector2(32,32)*node.scale
				var rect := Rect2(center-extent/2,extent)
				if not allowed(rect): continue
				var overlap := false
				for previous in occupied: overlap = overlap or rect.grow(-12).intersects(previous.grow(-12))
				if overlap: continue
				var use_tree := random.randf() < 0.68
				node.set_cell(cell,0 if use_tree else 1,Vector2i(5,16) if use_tree else Vector2i(12+2*random.randi_range(0,2),12))
				occupied.append(rect)
				count += 1
		var stones := layer("GFXBoulders",props,true,1.7,0)
		var details := layer("GFXUndergrowth",plants,false,1.5,-1)
		var details_count := 0
		for attempt in (850 if index == 1 else 600):
			var position := Vector2(random.randf_range(64,map.map_size.x-64),random.randf_range(64,map.map_size.y-64))
			var cell := details.local_to_map(position/details.scale)
			var center := details.map_to_local(cell)*details.scale
			if not allowed(Rect2(center-Vector2(18,24),Vector2(36,48))): continue
			var nearby_water := false
			for step in [Vector2i(-2,0),Vector2i(2,0),Vector2i(0,-2),Vector2i(0,2)]: nearby_water = nearby_water or water_cells.has(Vector2i(center/16)+step)
			var choices := [Vector2i(0,8),Vector2i(1,8),Vector2i(3,11),Vector2i(3,12),Vector2i(0,14)]
			details.set_cell(cell,0,Vector2i(0,14) if nearby_water else choices[random.randi_range(0,4)])
			details_count += 1
		for point in clearings:
			for attempt in 12:
				var position := point+Vector2(random.randf_range(-230,230),random.randf_range(-230,230))
				var cell := stones.local_to_map(position/stones.scale)
				var center := stones.map_to_local(cell)*stones.scale
				var rect := Rect2(center-Vector2(30,30),Vector2(60,60))
				if not allowed(rect): continue
				var overlapping := false
				for previous in occupied: overlapping = overlapping or rect.intersects(previous)
				if not overlapping: stones.set_cell(cell,0,Vector2i(10,11))
		var packed := PackedScene.new()
		var error := packed.pack(map)
		if error == OK: error = ResourceSaver.save(packed,"res://scenes/world/"+filename+".tscn")
		print(filename," GFX trees=",count," plants=",details_count," boulders=",stones.get_used_cells().size()," save=",error)
		map.free()
		if error != OK:
			quit(1)
			return
	quit()
