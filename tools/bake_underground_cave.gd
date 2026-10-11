extends SceneTree
## Deterministic editor bake. Runtime loads ordinary editable TileMapLayers.
const Plan = preload("res://scripts/world/cave_layout.gd")
const ART := "res://assets/enironment/gfx/cave.png"
var floor_cells := {}
var water_cells := {}
var map: Node2D
var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var water_layer: TileMapLayer
var props_layer: TileMapLayer
var ripple_layer: TileMapLayer
var detail_layer: TileMapLayer
var noise := FastNoiseLite.new()
var paths: Array[PackedVector2Array] = []
var stone_cells := {}
func _initialize() -> void: call_deferred("run")
func own(node: Node, parent: Node = null) -> void:
	if parent == null: parent = map
	parent.add_child(node)
	node.owner = map
func atlas() -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = load(ART)
	source.texture_region_size = Vector2i(16,16)
	return source
func tiles(physical: bool) -> TileSet:
	var set := TileSet.new()
	set.tile_size = Vector2i(16,16)
	if physical:
		set.add_physics_layer()
		set.set_physics_layer_collision_layer(0,1)
		set.set_physics_layer_collision_mask(0,2)
	return set
func tile(source: TileSetAtlasSource, point: Vector2i, extent := Vector2i.ONE, polygon := PackedVector2Array()) -> void:
	source.create_tile(point,extent)
	if not polygon.is_empty():
		var data := source.get_tile_data(point,0)
		data.set_collision_polygons_count(0,1)
		data.set_collision_polygon_points(0,0,polygon)
		data.y_sort_origin = 10
func make_layer(name_: String, set: TileSet, depth: int, solid: bool) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = name_
	layer.tile_set = set
	layer.scale = Vector2.ONE*2
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.z_index = depth
	layer.collision_enabled = solid
	layer.navigation_enabled = false
	layer.y_sort_enabled = depth == 0
	own(layer)
	return layer
func make_resources() -> void:
	var square := PackedVector2Array([Vector2(-8,-8),Vector2(8,-8),Vector2(8,8),Vector2(-8,8)])
	var ground := tiles(false)
	var ga := atlas()
	ground.add_source(ga,0)
	for point in [Vector2i(0,0),Vector2i(0,1),Vector2i(0,2)]:
		tile(ga,point)
		for alternative in range(1,4):
			ga.create_alternative_tile(point,alternative)
			var data := ga.get_tile_data(point,alternative)
			data.flip_h = alternative&1 != 0
			data.flip_v = alternative&2 != 0
	var walls := tiles(true)
	var wa := atlas()
	walls.add_source(wa,0)
	for x in range(1,4):
		for y in range(3): tile(wa,Vector2i(x,y),Vector2i.ONE,square)
	var pools := tiles(true)
	var pa := atlas()
	pools.add_source(pa,0)
	for x in 3:
		for y in range(7,10): tile(pa,Vector2i(x,y),Vector2i.ONE,square)
	var ripples := tiles(false)
	var ripple_atlas := atlas()
	ripples.add_source(ripple_atlas,0)
	tile(ripple_atlas,Vector2i(5,7),Vector2i(2,2))
	var rocks := tiles(true)
	var ra := atlas()
	rocks.add_source(ra,0)
	tile(ra,Vector2i(7,5),Vector2i(2,2),PackedVector2Array([Vector2(-13,0),Vector2(11,-2),Vector2(15,9),Vector2(10,14),Vector2(-11,14),Vector2(-15,8)]))
	for point in [Vector2i(5,4),Vector2i(6,4)]: tile(ra,point,Vector2i.ONE,PackedVector2Array([Vector2(-6,-1),Vector2(6,-1),Vector2(7,5),Vector2(-7,6)]))
	var details := tiles(false)
	var da := atlas()
	details.add_source(da,0)
	for point in [Vector2i(5,3),Vector2i(6,3),Vector2i(3,0)]:
		if point != Vector2i(3,0): tile(da,point)
	for pair in [[ground,"cave_floor"],[walls,"cave_walls"],[pools,"cave_water"],[rocks,"cave_rocks"],[details,"cave_details"],[ripples,"cave_ripples"]]:
		var path: String = "res://resources/cave/"+pair[1]+".tres"
		assert(ResourceSaver.save(pair[0],path) == OK)
		pair[0].take_over_path(path)
	floor_layer = make_layer("CaveFloor",ground,-5,false)
	wall_layer = make_layer("CaveWalls",walls,0,true)
	water_layer = make_layer("CaveWater",pools,-3,true)
	props_layer = make_layer("CaveRocks",rocks,0,true)
	detail_layer = make_layer("CaveRubble",details,-2,false)
	ripple_layer = make_layer("WaterRipples",ripples,-2,false)
func carve_ellipse(center: Vector2, radii: Vector2, salt: float = 0) -> void:
	for y in range(int(center.y-radii.y-3),int(center.y+radii.y+3)):
		for x in range(int(center.x-radii.x-3),int(center.x+radii.x+3)):
			var cell := Vector2i(x,y)
			var edge := ((Vector2(cell)+Vector2(.5,.5)-center)/radii).length()
			var wobble := noise.get_noise_2d(x+salt,y-salt)*.13
			if edge <= 1+wobble and x > 4 and y > 4 and x < Plan.SIZE.x-4 and y < Plan.SIZE.y-4: floor_cells[cell] = true
func protected(cell: Vector2i) -> bool:
	var point := Vector2(cell)*Plan.CELL+Vector2.ONE*Plan.CELL*.5
	for room in Plan.ROOMS:
		if point.distance_to(Vector2(room.center)*Plan.CELL) < 8*Plan.CELL: return true
	for points in paths:
		for i in range(1,points.size()):
			if Geometry2D.get_closest_point_to_segment(point,points[i-1],points[i]).distance_to(point) < 4*Plan.CELL: return true
	return false
func carve() -> void:
	noise.seed = 98142
	noise.frequency = .095
	for i in Plan.ROOMS.size():
		var room: Dictionary = Plan.ROOMS[i]
		carve_ellipse(Vector2(room.center),Vector2(room.radius),i*23)
	for index in Plan.ROUTES.size():
		var points := Plan.route_points(Plan.ROUTES[index])
		paths.append(points)
		for i in range(1,points.size()):
			var first := points[i-1]/Plan.CELL
			var last := points[i]/Plan.CELL
			var steps := ceili(first.distance_to(last)*2)
			for j in steps+1:
				var blend := float(j)/steps
				var point := first.lerp(last,blend)
				var width := 4.7+1.0*sin(blend*TAU+index)
				carve_ellipse(point,Vector2(width,width),index*31)
	for cell in floor_cells:
		var variation := noise.get_noise_2d(cell.x*.55,cell.y*.55)
		var coordinate := Vector2i(0,0 if variation < .28 else (1 if variation < .48 else 2))
		floor_layer.set_cell(cell,0,coordinate,absi(cell.x*17+cell.y*31)%4)
	var boundaries := {}
	for cell in floor_cells:
		for dy in range(-1,2):
			for dx in range(-1,2):
				var next: Vector2i = cell+Vector2i(dx,dy)
				if not floor_cells.has(next): boundaries[next] = true
	for cell in boundaries:
		var n := floor_cells.has(cell+Vector2i.UP)
		var s := floor_cells.has(cell+Vector2i.DOWN)
		var w := floor_cells.has(cell+Vector2i.LEFT)
		var e := floor_cells.has(cell+Vector2i.RIGHT)
		var x := 1 if w else (3 if e else 2)
		var y := 0 if n else (2 if s else 1)
		if not n and not s and not w and not e:
			# Diagonal-only contact uses a rock corner rather than a bare void cell.
			for diagonal in [Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]:
				if floor_cells.has(cell+diagonal):
					x = 1 if diagonal.x < 0 else 3
					y = 0 if diagonal.y < 0 else 2
		wall_layer.set_cell(cell,0,Vector2i(x,y))
func decorate() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 92371
	for index in [4,8]:
		var room: Dictionary = Plan.ROOMS[index]
		var center: Vector2 = Vector2(room.center)+Vector2(15,4)
		for y in range(int(center.y)-8,int(center.y)+9):
			for x in range(int(center.x)-10,int(center.x)+11):
				var cell := Vector2i(x,y)
				if floor_cells.has(cell) and not protected(cell) and ((Vector2(cell)-center)/Vector2(9,6)).length() < 1: water_cells[cell] = true
	for cell in water_cells:
		var x := 1 if water_cells.has(cell+Vector2i.LEFT) and water_cells.has(cell+Vector2i.RIGHT) else (0 if not water_cells.has(cell+Vector2i.LEFT) else 2)
		var y := 8 if water_cells.has(cell+Vector2i.UP) and water_cells.has(cell+Vector2i.DOWN) else (7 if not water_cells.has(cell+Vector2i.UP) else 9)
		water_layer.set_cell(cell,0,Vector2i(x,y))
	for cell in water_cells:
		if cell.x%3 != 0 or cell.y%3 != 0: continue
		var fits := true
		for dy in range(-1,2):
			for dx in range(-1,2):
				if not water_cells.has(cell+Vector2i(dx,dy)): fits = false
		if fits: ripple_layer.set_cell(cell,0,Vector2i(5,7))
	for cell in floor_cells:
		var final: Dictionary = Plan.ROOMS[13]
		if ((Vector2(cell)-Vector2(final.center))/Vector2(final.radius)).length() < 1.2: continue
		if water_cells.has(cell) or protected(cell): continue
		var edge := false
		for offset in [Vector2i(2,0),Vector2i(-2,0),Vector2i(0,2),Vector2i(0,-2)]:
			if not floor_cells.has(cell+offset): edge = true
		if (edge and random.randf() < .14) or (not edge and random.randf() < .025):
			var large := random.randf() < .25
			var valid := true
			for dy in range(-1,3):
				for dx in range(-1,3):
					var next: Vector2i = cell+Vector2i(dx,dy)
					if not floor_cells.has(next) or water_cells.has(next) or protected(next) or stone_cells.has(next): valid = false
			if not valid: continue
			props_layer.set_cell(cell,0,Vector2i(7,5) if large else (Vector2i(5,4) if random.randf() < .5 else Vector2i(6,4)))
			for dy in range(-1,2):
				for dx in range(-1,2): stone_cells[cell+Vector2i(dx,dy)] = true
		elif random.randf() < .045:
			detail_layer.set_cell(cell,0,Vector2i(5,3) if random.randf() < .5 else Vector2i(6,3))
	# Authored landmark stones form crescents around selected chambers, with an open center.
	for index in [2,5,11]:
		var room: Dictionary = Plan.ROOMS[index]
		for i in 9:
			var point: Vector2i = room.center+Vector2i(Vector2.RIGHT.rotated(i*PI/9)*Vector2(room.radius)*.7)
			if protected(point) or water_cells.has(point): continue
			props_layer.set_cell(point,0,Vector2i(7,5))
func landmarks() -> void:
	var grouping := Node2D.new()
	grouping.name = "StoneLandmarks"
	grouping.y_sort_enabled = true
	own(grouping)
	for index in [2,5,11]:
		for side in [-1,1]:
			var point := Plan.center(index)+Vector2(side*360,-260)
			if protected(Vector2i(point/Plan.CELL)): continue
			var body := StaticBody2D.new()
			body.name = "StoneColumn"+str(index)+("Left" if side < 0 else "Right")
			body.position = point
			body.collision_layer = 1
			body.collision_mask = 2
			own(body,grouping)
			var texture := AtlasTexture.new()
			texture.atlas = load(ART)
			texture.region = Rect2(128 if side < 0 else 144,0,16,48)
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.scale = Vector2.ONE*2
			sprite.position = Vector2(0,-38)
			own(sprite,body)
			var shape := CollisionShape2D.new()
			var rectangle := RectangleShape2D.new()
			rectangle.size = Vector2(24,16)
			shape.shape = rectangle
			shape.position.y = 2
			own(shape,body)

func cache() -> void:
	var img := Image.create(1280,1024,false,Image.FORMAT_RGBA8)
	img.fill(Color("#1E1728"))
	for cell in floor_cells:
		var color := Color("#78616b") if not water_cells.has(cell) else Color("#335b72")
		img.fill_rect(Rect2i(cell*2,Vector2i(2,2)),color)
	for cell in wall_layer.get_used_cells(): img.fill_rect(Rect2i(cell*2,Vector2i(2,2)),Color("#383142"))
	for cell in props_layer.get_used_cells(): img.fill_rect(Rect2i(cell*2,Vector2i(2,2)),Color("#534652"))
	var texture := ImageTexture.create_from_image(img)
	texture.set_meta("source_hashes",{"res://scenes/world/underground_cave.tscn":FileAccess.get_sha256("res://scenes/world/underground_cave.tscn"),ART:FileAccess.get_sha256(ART)})
	assert(ResourceSaver.save(texture,"res://resources/maps/underground_terrain.res",ResourceSaver.FLAG_COMPRESS) == OK)
func run() -> void:
	if "--cache-only" in OS.get_cmdline_user_args():
		map = load("res://scenes/world/underground_cave.tscn").instantiate()
		floor_layer = map.get_node("CaveFloor")
		wall_layer = map.get_node("CaveWalls")
		water_layer = map.get_node("CaveWater")
		props_layer = map.get_node("CaveRocks")
		for cell in floor_layer.get_used_cells(): floor_cells[cell] = true
		for cell in water_layer.get_used_cells(): water_cells[cell] = true
		cache()
		map.free()
		print("CAVE CACHE: refreshed from edited scene; geometry preserved")
		quit()
		return
	map = Node2D.new()
	map.name = "UndergroundCave"
	map.set_script(preload("res://scripts/world/cave.gd"))
	map.display_name = "Underground Cave"
	map.map_size = Vector2(Plan.SIZE)*Plan.CELL
	map.y_sort_enabled = true
	var background := Polygon2D.new()
	background.name = "UnexcavatedRock"
	background.z_index = -10
	background.color = Color("#1E1728")
	background.polygon = PackedVector2Array([Vector2.ZERO,Vector2(map.map_size.x,0),map.map_size,Vector2(0,map.map_size.y)])
	own(background)
	make_resources()
	carve()
	decorate()
	landmarks()
	var entries := Node2D.new()
	entries.name = "Entries"
	own(entries)
	var entry := Marker2D.new()
	entry.name = "FromFlooded"
	entry.position = Plan.center(0)+Vector2(0,128)
	entry.set_meta("facing_direction",Vector2.UP)
	own(entry,entries)
	var portals := Node2D.new()
	portals.name = "Portals"
	own(portals)
	var characters := Node2D.new()
	characters.name = "Characters"
	characters.y_sort_enabled = true
	own(characters)
	var exit: Node2D = load("res://scenes/world/cave_return.tscn").instantiate()
	exit.position = Plan.center(0)-Vector2(0,64)
	own(exit,characters)
	var atmosphere := Node2D.new()
	atmosphere.name = "UndergroundAtmosphere"
	atmosphere.set_script(load("res://scripts/world/cave_atmosphere.gd"))
	own(atmosphere)
	map.set_meta("chamber_count",Plan.ROOMS.size())
	map.set_meta("network_length_pixels",Plan.network_length())
	var packed := PackedScene.new()
	assert(packed.pack(map) == OK)
	assert(ResourceSaver.save(packed,"res://scenes/world/underground_cave.tscn") == OK)
	cache()
	print("CAVE BAKE: ",floor_cells.size()," floor cells, ",wall_layer.get_used_cells().size()," boundary tiles; 14 chambers; network=",Plan.network_length()," px, one traversal of each passage=",Plan.network_length()/260.0/60," min")
	map.free()
	quit()
