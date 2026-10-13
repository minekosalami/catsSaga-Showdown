extends SceneTree
const Plan = preload("res://scripts/world/cave_layout.gd")
const Art = preload("res://scripts/world/cave_assets.gd")
var cells := {}
var water_cells := {}
var map: Node2D
var textures := {}
var reserved: Array[Vector2] = []
func _initialize():
	create_timer(90).timeout.connect(func(): quit(1))
	call_deferred("run")
func own(node: Node, parent: Node = null):
	if parent == null: parent = map
	parent.add_child(node)
	node.owner = map
func stamp(point: Vector2, radius: float, ids: Vector2i):
	for y in range(floori(point.y-radius),ceili(point.y+radius)+1):
		for x in range(floori(point.x-radius),ceili(point.x+radius)+1):
			var cell := Vector2i(x,y)
			if not cells.has(cell) and Vector2(cell).distance_to(point) < radius: cells[cell] = ids
func build_cells():
	for room in Plan.ROOMS:
		var outline := Plan.polygon(room.id)
		var rect: Rect2i = room.rect
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x):
				if Geometry2D.is_point_in_polygon(Vector2(x+.5,y+.5),outline): cells[Vector2i(x,y)] = Vector2i(room.id,0)
	for route in Plan.ROUTES+Plan.BRANCHES:
		for i in range(1,route.points.size()):
			var a: Vector2 = route.points[i-1]
			var b: Vector2 = route.points[i]
			var samples := ceili(a.distance_to(b)*2)
			for step in samples+1: stamp(a.lerp(b,float(step)/samples),2.15,Vector2i(route.a,route.b))
	for x in range(28,41):
		for y in range(79,85): cells[Vector2i(x,y)] = Vector2i(6 if x < 35 else 10,0)
	for cell in cells:
		for pool in Plan.POOLS:
			if Geometry2D.is_point_in_polygon(Vector2(cell)+Vector2(.5,.5),PackedVector2Array(pool)): water_cells[cell] = true
func layer(name_: String, resource: String, z: int, solid := false) -> TileMapLayer:
	var node := TileMapLayer.new()
	node.name = name_
	node.tile_set = load(resource)
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.collision_enabled = solid
	node.navigation_enabled = false
	node.z_index = z
	own(node)
	return node
func sprite(parent: Node, kind: String, point: Vector2, floor_decal := false) -> Sprite2D:
	if not textures.has(kind): textures[kind] = Art.texture(kind)
	var node := Sprite2D.new()
	node.texture = textures[kind]
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.position = point if floor_decal else point-Vector2(0,Art.REGIONS[kind].size.y*.5)
	if floor_decal: node.z_index = -2
	own(node,parent)
	return node
func actor(name_: String, kind: String, area: int, point: Vector2, text: Array[String] = [], display := ""):
	var node := Node2D.new()
	node.name = name_
	node.set_script(load("res://scripts/world/cave_actor.gd"))
	node.role = kind
	node.area = area
	node.notes = PackedStringArray(text)
	node.display_kind = display
	node.position = point
	own(node,map.get_node("Characters"))
	reserved.append(point)
func prop(name_: String, point: Vector2, kind: String, solid := true, decal := false):
	var node := StaticBody2D.new()
	node.name = name_
	node.position = point
	node.collision_layer = 1 if solid else 0
	node.collision_mask = 2
	own(node,map.get_node("Decorations"))
	sprite(node,kind,Vector2.ZERO,decal)
	if solid:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(Art.REGIONS[kind].size.x*.65,Art.REGIONS[kind].size.y*.23)
		shape.shape = rect
		shape.position.y = -rect.size.y*.5
		own(shape,node)
func light(point: Vector2, warm := true, brazier := false):
	prop("Lamp"+str(map.get_node("Decorations").get_child_count()),point,"brazier" if brazier else "torch",brazier)
	var node := PointLight2D.new()
	node.position = point-Vector2(0,30)
	node.color = Color("#ffce86") if warm else Color("#a5c9cc")
	node.set_script(load("res://scripts/world/cave_light.gd"))
	node.base_energy = 1.3 if brazier else .85
	node.phase = fmod(point.x*.03+point.y*.017,TAU)
	own(node,map.get_node("Decorations"))
func clear(point: Vector2, margin := 50.0) -> bool:
	var cell := Vector2i(point/32)
	if not cells.has(cell) or cells[cell].y != 0 or water_cells.has(cell): return false
	for offset in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
		if not cells.has(cell+offset) or water_cells.has(cell+offset): return false
	for p in reserved:
		if point.distance_to(p) < margin: return false
	for route in Plan.ROUTES+Plan.BRANCHES:
		for i in range(1,route.points.size()):
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point,route.points[i-1]*32,route.points[i]*32)) < 65: return false
	return true
func settlement():
	# Deliberate shop/work/rest groupings. Props retain complete original regions.
	for row in [
		["HubShelfA",Vector2(50,41),"shelf"],["HubShelfB",Vector2(64,40),"shelf"],
		["HubCounterA",Vector2(50,44),"table"],["HubCounterB",Vector2(52,44),"table"],
		["HubCounterC",Vector2(63,43),"table"],["HubCounterD",Vector2(65,43),"table"],
		["HubSeatA",Vector2(51,46),"chair"],["HubSeatB",Vector2(64,45),"chair"],
		["HubSupperA",Vector2(53,54),"table"],["HubSupperB",Vector2(55,54),"table"],
		["HubArmchairA",Vector2(52,56),"armchair"],["HubArmchairB",Vector2(56,56),"armchair"],
		["HubSuppliesA",Vector2(50,43),"supplies"],["HubSuppliesB",Vector2(63,42),"supplies"],
		["HubChestA",Vector2(44,47),"chest"],["HubChestB",Vector2(44,49),"chest"],
		["MarketShelfA",Vector2(93,41),"shelf"],["MarketShelfB",Vector2(103,43),"shelf"],
		["MarketCounterA",Vector2(93,45),"table"],["MarketCounterB",Vector2(95,45),"table"],
		["MarketCounterC",Vector2(100,49),"table"],["MarketCounterD",Vector2(102,49),"table"],
		["MarketGoodsA",Vector2(93,44),"supplies"],["MarketGoodsB",Vector2(100,48),"books"],
		["MarketCrateA",Vector2(86,52),"chest"],["MarketCrateB",Vector2(88,54),"chest"],
		["ResidenceBedA",Vector2(125,43),"bed"],["ResidenceBedB",Vector2(130,43),"bed"],
		["ResidenceShelf",Vector2(135,43),"shelf"],["ResidenceTable",Vector2(132,51),"table"],
		["ResidenceSeat",Vector2(130,52),"armchair"],["ResidenceChest",Vector2(140,54),"chest"],
		["SupplyChestA",Vector2(122,10),"chest"],["SupplyChestB",Vector2(124,11),"chest"],
		["SupplyChestC",Vector2(130,21),"chest"],["SupplyShelf",Vector2(128,10),"shelf"],
		["ArchiveShelfA",Vector2(98,76),"shelf"],["ArchiveShelfB",Vector2(100,79),"shelf"],
		["ArchiveTable",Vector2(97,85),"table"],["ArchiveChair",Vector2(95,87),"armchair"],
		["LastWatchSeat",Vector2(91,110),"chair"],["LastWatchCrate",Vector2(91,109),"chest"],
		["RiddleShelf",Vector2(16,10),"shelf"],["RiddleChair",Vector2(15,16),"chair"]
	]:
		prop(row[0],row[1]*32,row[2],row[2] not in ["supplies","books"])
	for point in [Vector2(46,53),Vector2(54,55),Vector2(127,47),Vector2(97,86)]: prop("FloorCloth"+str(point),point*32,"blanket",false,true)
	for point in [Vector2(47,42),Vector2(62,50),Vector2(69,55),Vector2(89,43),Vector2(102,53),Vector2(136,47),Vector2(124,18),Vector2(98,81)]: light(point*32,true,point == Vector2(62,50))
	# Keep the long encounter lane clear, with authored fire/stone landmarks along its edges.
	for point in [Vector2(143,105),Vector2(157,120),Vector2(175,110)]: light(point*32,true,true)
	for point in [Vector2(137,106),Vector2(170,118)]: prop("EncounterStone"+str(point),point*32,"spike")
func cave_detail():
	var spots := [Vector2(.23,.23),Vector2(.72,.23),Vector2(.85,.56),Vector2(.71,.78),Vector2(.24,.75),Vector2(.45,.83)]
	for room in Plan.ROOMS:
		var rect: Rect2i = room.rect
		for i in spots.size():
			var point: Vector2 = (Vector2(rect.position)+spots[i]*Vector2(rect.size))*32
			if not clear(point,100): continue
			prop("Stone%d_%d"%[room.id,i],point,"spike" if i%3 == 0 else "rock_cluster")
			for offset in [Vector2(-43,22),Vector2(38,30),Vector2(22,-23)]:
				if clear(point+offset,60): prop("SmallStone%d_%d_%s"%[room.id,i,str(offset)],point+offset,"rock",false)
			reserved.append(point)
		var warm: bool = room.id in [1,2,4,11,12,13]
		var glow := (Vector2(rect.position)+Vector2(.48,.20)*Vector2(rect.size))*32
		if clear(glow,90): light(glow,warm)
		# Small authored footprint/pebble motifs break up floors without blocking travel.
		for y in range(rect.position.y+4,rect.end.y-3,4):
			for x in range(rect.position.x+3,rect.end.x-3,5):
				var point := Vector2(x*32+16,y*32+16)
				if clear(point,55): prop("Pebbles%d_%d_%d"%[room.id,x,y],point,"pebbles",false,true)
	for route in Plan.ROUTES:
		if route.points.size() < 3: continue
		var point: Vector2 = route.points[1]*32+Vector2(36,-18)
		if cells.has(Vector2i(point/32)): light(point,false)
func cache():
	var image := Image.create(Plan.SIZE.x*2,Plan.SIZE.y*2,false,Image.FORMAT_RGBA8)
	image.fill(Color("#231b22"))
	for cell in cells:
		var color := Color("#6e5045") if cells[cell].x in [4,12,13] else Color("#4c4147")
		if water_cells.has(cell): color = Color("#315f57")
		for offset in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE]: image.set_pixelv(cell*2+offset,color)
	var texture := ImageTexture.create_from_image(image)
	texture.set_meta("source_hashes",{"underground_cave":FileAccess.get_sha256("res://scenes/world/underground_cave.tscn")})
	ResourceSaver.save(texture,"res://resources/maps/underground_terrain.res")
func run():
	if "--cache-only" in OS.get_cmdline_user_args():
		map = load("res://scenes/world/underground_cave.tscn").instantiate()
		var hub: TileMapLayer = map.get_node("HubFloor")
		for cell in map.get_node("CaveFloor").get_used_cells(): cells[cell] = Vector2i(4 if hub.get_cell_source_id(cell) >= 0 else 1,0)
		for cell in map.get_node("CaveWater").get_used_cells(): water_cells[cell] = true
		cache()
		map.free()
		quit()
		return
	build_cells()
	map = Node2D.new()
	map.name = "UndergroundCave"
	map.set_script(load("res://scripts/world/cave.gd"))
	map.display_name = "Underground Cave"
	map.map_size = Vector2(Plan.SIZE*32)
	map.y_sort_enabled = true
	map.set_meta("chamber_count",16)
	var backdrop := layer("RockMass","res://resources/cave/settlement_walls.tres",-10)
	backdrop.modulate = Color(.35,.27,.36)
	for y in Plan.SIZE.y:
		for x in Plan.SIZE.x: backdrop.set_cell(Vector2i(x,y),0,Vector2i(1,3))
	var floor := layer("CaveFloor","res://resources/cave/settlement_floor.tres",-5)
	var points: Array[Vector2i] = []
	points.assign(cells.keys())
	floor.set_cells_terrain_connect(points,0,0,false)
	var hub := layer("HubFloor","res://resources/cave/settlement_hub.tres",-4)
	var colored := layer("ColoredFloor","res://resources/cave/settlement_floor.tres",-4)
	colored.modulate = Color(.5,1.6,1.2)
	var hidden_cells: Array[Vector2i] = []
	for cell in cells:
		if cells[cell].x in [4,12,13] and cells[cell].y == 0: hub.set_cell(cell,0,Vector2i(1,1))
		if cells[cell].x == 10: hidden_cells.append(cell)
	colored.set_cells_terrain_connect(hidden_cells,0,0,false)
	var scuffs := layer("SettlementScuffs","res://resources/cave/settlement_hub.tres",-3)
	for cell in hub.get_used_cells():
		if (cell.x*13+cell.y*7)%17 == 0: scuffs.set_cell(cell,0,Vector2i(4+(cell.x%2),5+(cell.y%2)))
	var walls := layer("CaveWalls","res://resources/cave/settlement_walls.tres",0,true)
	var wall_cells := {}
	for cell in cells:
		for y in range(-2,3):
			for x in range(-2,3):
				var neighbor: Vector2i = cell+Vector2i(x,y)
				if not cells.has(neighbor) and Rect2i(Vector2i.ZERO,Plan.SIZE).has_point(neighbor): wall_cells[neighbor] = cells[cell]
	for cell in wall_cells: walls.set_cell(cell,0,Vector2i(1,3))
	var water := layer("CaveWater","res://resources/cave/settlement_water.tres",-2,true)
	points.assign(water_cells.keys())
	water.set_cells_terrain_connect(points,0,0,false)
	var ripples := ShaderMaterial.new()
	ripples.shader = load("res://shaders/cave_water.gdshader")
	water.material = ripples
	var ids := Image.create(Plan.SIZE.x,Plan.SIZE.y,false,Image.FORMAT_RG8)
	ids.fill(Color.BLACK)
	for cell in cells: ids.set_pixelv(cell,Color(cells[cell].x/255.0,cells[cell].y/255.0,0))
	for cell in wall_cells: ids.set_pixelv(cell,Color(wall_cells[cell].x/255.0,wall_cells[cell].y/255.0,0))
	ResourceSaver.save(ImageTexture.create_from_image(ids),"res://resources/cave/room_ids.res")
	for name_ in ["Entries","Portals","Characters","Decorations"]:
		var group := Node2D.new()
		group.name = name_
		group.y_sort_enabled = name_ in ["Characters","Decorations"]
		own(group)
	var entry := Marker2D.new()
	entry.name = "FromFlooded"
	entry.position = Plan.ENTRY
	entry.set_meta("facing_direction",Vector2.DOWN)
	own(entry,map.get_node("Entries"))
	var exit: Node2D = load("res://scenes/world/cave_return.tscn").instantiate()
	exit.position = Plan.ENTRY-Vector2(0,128)
	own(exit,map.get_node("Characters"))
	reserved.append(Plan.ENTRY)
	actor("RiddleCat","riddle",2,Plan.center(1))
	actor("WarningCat","warning",4,Plan.WARNING)
	actor("QuietCat","social",4,Plan.SOCIAL,["It's quiet here. Stay by the lights if you need a rest."])
	actor("SavePoint","save",4,Plan.SAVE_POINT)
	actor("RestPoint","rest",4,Plan.REST)
	actor("Merchant","merchant",12,Vector2(95,48)*32)
	actor("Resident","social",13,Vector2(137,50)*32,["These little rooms keep the damp off our blankets."])
	actor("RedBarrier","red_gate",5,Plan.RED_GATE)
	actor("SealedWindow","window",6,Vector2(34,82)*32)
	actor("HubShortcut","shortcut_hub",4,Plan.SHORTCUT_HUB)
	actor("JunctionShortcut","shortcut_junction",8,Plan.SHORTCUT_JUNCTION)
	actor("SupplyNote","inspect",11,Vector2(145,22)*32,["Someone tucked dry supplies into this dead end. Nothing here is for sale."],"chest")
	actor("ReadingNote","inspect",14,Vector2(98,85)*32,["A book lies open between two shelves. Its pages smell of damp stone."],"books")
	actor("OldMarker","inspect",14,Vector2(110,98)*32,["The tunnel narrows to a dead end. Old footsteps turn back here."],"sign")
	actor("WaterNote","inspect",15,Vector2(122,81)*32,["The water is too deep to cross. Every drop answers twice."],"sign")
	actor("QuietCorner","inspect",13,Vector2(148,63)*32,["An empty seat, hidden from the busy market. A little breathing room."],"armchair")
	settlement()
	cave_detail()
	var atmosphere := Node2D.new()
	atmosphere.name = "UndergroundAtmosphere"
	atmosphere.set_script(load("res://scripts/world/cave_atmosphere.gd"))
	own(atmosphere)
	var scene := PackedScene.new()
	assert(scene.pack(map) == OK)
	assert(ResourceSaver.save(scene,"res://scenes/world/underground_cave.tscn") == OK)
	cache()
	print("Settlement baked: ",cells.size()," floor cells, ",water_cells.size()," blocked water cells, ",map.get_node("Decorations").get_child_count()," prop/light nodes across 16 chambers")
	map.free()
	quit()
