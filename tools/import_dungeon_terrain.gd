extends SceneTree
const Art = preload("res://scripts/world/cave_assets.gd")
const BITS := [TileSet.CELL_NEIGHBOR_TOP_SIDE,TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,TileSet.CELL_NEIGHBOR_RIGHT_SIDE,TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,TileSet.CELL_NEIGHBOR_LEFT_SIDE,TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER]
const SAMPLES := [Vector2i(16,1),Vector2i(30,1),Vector2i(30,16),Vector2i(30,30),Vector2i(16,30),Vector2i(1,30),Vector2i(1,16),Vector2i(1,1)]
func _initialize(): call_deferred("run")
func make_set(file: String, kind: String):
	var set := TileSet.new()
	set.tile_size = Vector2i(32,32)
	set.add_terrain_set()
	set.set_terrain_set_mode(0,TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES if kind == "floor" else TileSet.TERRAIN_MODE_MATCH_SIDES)
	set.add_terrain(0)
	set.set_terrain_name(0,0,kind.capitalize())
	set.set_terrain_color(0,0,Color("#675047"))
	var solid := kind in ["walls","water"]
	if solid:
		set.add_physics_layer()
		set.set_physics_layer_collision_layer(0,1)
		set.set_physics_layer_collision_mask(0,2)
	var source := TileSetAtlasSource.new()
	source.texture = load(Art.PACK+"tiles/"+file+"-tiles-32x32.png")
	source.texture_region_size = Vector2i(32,32)
	set.add_source(source,0)
	var image := source.texture.get_image()
	var seen := {}
	for y in image.get_height()/32:
		for x in image.get_width()/32:
			var cell := Vector2i(x,y)
			var origin := cell*32
			# Completely empty cells are not paintable assets.
			if image.get_region(Rect2i(origin,Vector2i(32,32))).is_invisible(): continue
			source.create_tile(cell)
			var data := source.get_tile_data(cell,0)
			if solid:
				data.set_collision_polygons_count(0,1)
				data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-16,-16),Vector2(16,-16),Vector2(16,16),Vector2(-16,16)]))
			if kind == "floor":
				if image.get_pixelv(origin+Vector2i(16,16)).a < .5: continue
				var mask := 0
				for i in 8:
					if image.get_pixelv(origin+SAMPLES[i]).a > .5: mask |= 1<<i
				if seen.has(mask): continue
				seen[mask] = true
				data.terrain_set = 0
				data.terrain = 0
				for i in 8: data.set_terrain_peering_bit(BITS[i],0 if mask & (1<<i) else -1)
			elif kind in ["hub","water"] and x < 3 and y < 3:
				data.terrain_set = 0
				data.terrain = 0
				for i in [0,2,4,6]:
					var filled: bool = not ((i == 0 and y == 0) or (i == 2 and x == 2) or (i == 4 and y == 2) or (i == 6 and x == 0))
					data.set_terrain_peering_bit(BITS[i],0 if filled else -1)
			elif kind == "walls" and cell == Vector2i(1,3):
				data.terrain_set = 0
				data.terrain = 0
				for i in [0,2,4,6]: data.set_terrain_peering_bit(BITS[i],0)
	assert(ResourceSaver.save(set,"res://resources/cave/settlement_"+kind+".tres") == OK)
	print(kind,": ",source.get_tiles_count()," native 32px atlas regions; ",seen.size()," alpha-derived corner/side variants; solid=",solid)
func run():
	make_set("dirt","floor")
	make_set("ground","hub")
	make_set("wall","walls")
	make_set("water","water")
	quit()
