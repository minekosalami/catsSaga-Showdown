extends SceneTree
const ROOT := "res://assets/enironment/sbs_-_top_down_dungeon_pack/Tiles/"
const BITS := [TileSet.CELL_NEIGHBOR_TOP_SIDE,TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,TileSet.CELL_NEIGHBOR_RIGHT_SIDE,TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,TileSet.CELL_NEIGHBOR_LEFT_SIDE,TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER]
func _initialize(): call_deferred("run")
func make_set(folder: String, file: String, solid: bool, output: String):
	var set := TileSet.new()
	set.tile_size = Vector2i(64,64)
	set.add_terrain_set()
	set.set_terrain_set_mode(0,TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	set.add_terrain(0)
	set.set_terrain_name(0,0,"Stone walls" if solid else "Cave floor")
	set.set_terrain_color(0,0,Color("#79756a"))
	if solid:
		set.add_physics_layer()
		set.set_physics_layer_collision_layer(0,1)
		set.set_physics_layer_collision_mask(0,2)
	var source := TileSetAtlasSource.new()
	source.texture = load(ROOT+folder+"/"+file+".png")
	source.texture_region_size = Vector2i(64,64)
	set.add_source(source,0)
	var parser := XMLParser.new()
	assert(parser.open(ROOT+folder+"/Tiled Tsx/"+file+".tsx") == OK)
	var masks := {}
	while parser.read() == OK:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT and parser.get_node_name() == "wangtile":
			masks[int(parser.get_named_attribute_value("tileid"))] = parser.get_named_attribute_value("wangid").split(",")
	# Only the wall sheet uses cell 47 as its magenta transparency key.
	# The floors' cell 47 is their actual seamless, fully connected floor.
	if solid: masks.erase(47)
	for id in masks:
		var cell := Vector2i(id%8,id/8)
		source.create_tile(cell)
		var data := source.get_tile_data(cell,0)
		data.terrain_set = 0
		data.terrain = 0
		for i in 8: data.set_terrain_peering_bit(BITS[i],0 if masks[id][i] == "1" else -1)
		if solid:
			data.set_collision_polygons_count(0,1)
			data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-32,-32),Vector2(32,-32),Vector2(32,32),Vector2(-32,32)]))
	assert(ResourceSaver.save(set,output) == OK)
func run():
	make_set("Floors","Floor-Dirt_01-64x64",false,"res://resources/cave/dungeon_floor.tres")
	make_set("Floors","Floor-Stone_01-64x64",false,"res://resources/cave/dungeon_hub_floor.tres")
	make_set("Walls","Wall-Stone_02-64x64",true,"res://resources/cave/dungeon_walls.tres")
	print("Dungeon terrain: native 64px atlas, authored Wang corners/sides, 32px display, full wall collisions")
	quit()
