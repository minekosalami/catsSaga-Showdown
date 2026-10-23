extends SceneTree
## Migrates existing scene artwork only, preserving map bodies and authored geography.
const Plan = preload("res://scripts/journey/layout.gd")
const Art = preload("res://scripts/journey/forest_art.gd")
var sets := {}

func _initialize() -> void:run.call_deferred()

func atlas(sheet: String,size: int,solid := false,folder := Art.ROOT) -> TileSet:
	var texture := load(folder+sheet+".png") as Texture2D
	var tiles := TileSet.new()
	tiles.tile_size=Vector2i.ONE*size
	var source := TileSetAtlasSource.new()
	source.texture=texture
	source.texture_region_size=Vector2i.ONE*size
	if solid:
		tiles.add_physics_layer()
		tiles.set_physics_layer_collision_layer(0,1)
		tiles.set_physics_layer_collision_mask(0,2)
	tiles.add_source(source,0)
	for y in texture.get_height()/size:
		for x in texture.get_width()/size:
			var cell := Vector2i(x,y)
			source.create_tile(cell)
			if solid:
				var data := source.get_tile_data(cell,0)
				data.set_collision_polygons_count(0,1)
				var h := size*.5
				data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-h,-h),Vector2(h,-h),Vector2(h,h),Vector2(-h,h)]))
				source.create_alternative_tile(cell,1)
				source.get_tile_data(cell,1).set_collision_polygons_count(0,0)
	return tiles

func resources() -> void:
	sets={"grass":atlas("grass",32),"path":atlas("dirt",32),"water":atlas("watergrass",32,true),"bridge":atlas("bridges",32),"trail_surface":atlas("dirt",16),"water_surface":atlas("watergrass",16)}
	var plants := atlas("plants_summer",32,false,"res://assets/environment_human/lpc_revised/")
	for sheet in ["flowers","mushrooms"]:
		var extra := atlas(sheet,32,false,"res://assets/environment_human/lpc_revised/")
		var source := extra.get_source(0)
		extra.remove_source(0)
		plants.add_source(source,1 if sheet=="flowers" else 2)
	sets["plants"]=plants
	for kind in ["path","water"]:
		var tiles: TileSet=sets[kind]
		tiles.add_terrain_set()
		tiles.set_terrain_set_mode(0,TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
		tiles.add_terrain(0)
		tiles.set_terrain_name(0,0,"Forest path" if kind=="path" else "Water")
		for y in range(2,5):
			for x in 3:
				var data: TileData = tiles.get_source(0).get_tile_data(Vector2i(x,y),0)
				data.terrain_set=0
				data.terrain=0
				for pair in [[TileSet.CELL_NEIGHBOR_TOP_SIDE,y>2],[TileSet.CELL_NEIGHBOR_RIGHT_SIDE,x<2],[TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,y<4],[TileSet.CELL_NEIGHBOR_LEFT_SIDE,x>0],[TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,y>2 and x>0],[TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,y>2 and x<2],[TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,y<4 and x>0],[TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,y<4 and x<2]]:
					data.set_terrain_peering_bit(pair[0],0 if pair[1] else -1)
	for kind in sets:
		var path := "res://resources/journey/"+str(kind)+".tres"
		if ResourceSaver.save(sets[kind],path)!=OK:quit(1);return
		sets[kind].take_over_path(path)

func cells(layer: TileMapLayer) -> Dictionary:
	var result := {}
	for cell in layer.get_used_cells():result[cell]=true
	return result

func build(area: String) -> void:
	var map := load(Plan.scene(area)).instantiate() as Node2D
	var paths := cells(map.get_node("Paths"))
	var water := cells(map.get_node("Water"))
	var bridges := cells(map.get_node("Bridges"))
	var plants := cells(map.get_node("Understory"))
	for pair in [["GrassGround","grass"],["Paths","path"],["Water","water"],["Bridges","bridge"],["TrailSurface","trail_surface"],["WaterSurface","water_surface"]]:
		var layer: TileMapLayer=map.get_node(pair[0])
		layer.tile_set=sets[pair[1]]
		layer.scale=Vector2.ONE
		layer.modulate=Color.WHITE
		layer.clear()
	var ground: TileMapLayer=map.get_node("GrassGround")
	for y in int(map.map_size.y/32):
		for x in int(map.map_size.x/32):
			# Sparse original grass variants interrupt repetition without noisy tiling.
			var variant := posmod(x*73+y*197,29)
			ground.set_cell(Vector2i(x,y),0,Vector2i(variant%3,5) if variant<3 else Vector2i(1,3))
	var understory := map.get_node("Understory") as TileMapLayer
	understory.clear()
	understory.tile_set=sets.plants
	understory.scale=Vector2.ONE
	understory.material=load("res://resources/journey/lpc_understory.tres")
	for cell: Vector2i in plants:
		if paths.has(cell) or water.has(cell):continue
		var pick := posmod(cell.x*71+cell.y*229,20)
		if pick<7:understory.set_cell(cell,0,Vector2i(6+pick%2,pick%2))
		elif pick<12:understory.set_cell(cell,1,Vector2i([0,1,3,4,5,8][posmod(cell.x+cell.y,6)],2 if pick%2 else 3))
		elif pick<16:understory.set_cell(cell,0,Vector2i(pick%2,0))
		else:understory.set_cell(cell,2,Vector2i(pick%3,4))
	for cell: Vector2i in paths:map.get_node("Paths").set_cell(cell,0,Vector2i(1,3))
	for cell: Vector2i in water:map.get_node("Water").set_cell(cell,0,Vector2i(1,3),1 if bridges.has(cell) else 0)
	Art.paint(map.get_node("TrailSurface"),paths)
	Art.paint(map.get_node("WaterSurface"),water,true)
	var deck: TileMapLayer=map.get_node("Bridges")
	for cell: Vector2i in bridges:
		# Horizontal decks use the artist's modular top rail, planks and bottom rail.
		var tile := Vector2i(4,4)
		if not bridges.has(cell+Vector2i.UP):tile=Vector2i(1,3)
		elif not bridges.has(cell+Vector2i.DOWN):tile=Vector2i(1,6)
		deck.set_cell(cell,0,tile)
	var trees := 0
	for node in map.get_children():
		if node.is_in_group("journey_trees"):
			var sprite: Sprite2D=node.get_node("Sprite2D")
			var variant := posmod(hash(str(node.position)),10)
			var pine := variant>=7
			var canopy := Rect2(96 if variant%2 else 0,96 if pine else 0,96,128 if pine else 96)
			sprite.texture=Art.region("treetop",canopy)
			sprite.material=null
			var trunk := node.get_node_or_null("TrunkArt") as Sprite2D
			if trunk==null:
				trunk=Sprite2D.new()
				trunk.name="TrunkArt"
				node.add_child(trunk)
				trunk.owner=map
				trunk.show_behind_parent=true
			trunk.texture=Art.region("trunk",Rect2(96 if variant%2 else 0,0,96,96))
			trunk.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			trunk.material=load("res://resources/journey/submerged_trunk.tres") if water.has(Vector2i(node.position/32)) else null
			var shadow := node.get_node_or_null("GroundShadow") as Sprite2D
			if shadow!=null:shadow.hide() # Human trunk sheet already includes its shadow.
			node.refresh()
			trees+=1
		elif node.is_in_group("journey_props"):
			var sprite := node.get_node("Sprite2D") as Sprite2D
			if str(node.name).begins_with("Rock"):
				sprite.texture=Art.region("rock",Rect2(32 if posmod(hash(str(node.position)),3)==0 else 0,0,32,32))
				sprite.scale=Vector2.ONE
				sprite.position=Vector2(0,-12)
				var collider := node.get_node("CollisionShape2D") as CollisionShape2D
				var shape := CapsuleShape2D.new()
				shape.radius=11
				shape.height=24
				collider.shape=shape
				collider.position.y=-6
				node.get_node("GroundShadow").hide()
	# Shoreline plants use intact original reeds/lily-pad cells, never collide.
	for cell: Vector2i in water:
		if bridges.has(cell) or posmod(cell.x*53+cell.y*97,37)!=0:continue
		if not water.has(cell+Vector2i.UP) or not water.has(cell+Vector2i.LEFT):
			understory.set_cell(cell,0,Vector2i(8+posmod(cell.x,3),1))
		elif posmod(cell.x+cell.y,4)==0:understory.set_cell(cell,0,Vector2i(12+posmod(cell.x,2),2))
	map.remove_meta("route_samples")
	map.set_meta("environment_art","LPC Sharm outdoor — CC BY-SA 3.0")
	var packed := PackedScene.new()
	var error := packed.pack(map)
	if error==OK:error=ResourceSaver.save(packed,Plan.scene(area))
	print("FOREST ART ",area," preserved trees=",trees," save=",error)
	map.free()
	if error!=OK:quit(1)

func run() -> void:
	if not "--apply" in OS.get_cmdline_user_args():push_error("Use -- --apply to migrate existing scene artwork.");quit(1);return
	resources()
	for area in Plan.ORDER:build(area)
	quit()
