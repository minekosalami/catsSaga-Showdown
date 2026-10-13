extends SceneTree
const Plan = preload("res://scripts/world/cave_layout.gd")
var cells := {}
var map: Node2D
func _initialize():
	create_timer(60).timeout.connect(func(): quit(1))
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
	var noise := FastNoiseLite.new()
	noise.seed = 31817
	noise.frequency = .16
	for room in Plan.ROOMS:
		var rect: Rect2i = room.rect
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x):
				var p := (Vector2(x+.5,y+.5)-Vector2(rect.get_center()))/(Vector2(rect.size)*.5)
				if pow(absf(p.x),6)+pow(absf(p.y),6) < .96+noise.get_noise_2d(x,y)*.12: cells[Vector2i(x,y)] = Vector2i(room.id,0)
	for route in Plan.ROUTES+Plan.BRANCHES:
		for i in range(1,route.points.size()):
			var a: Vector2 = route.points[i-1]
			var b: Vector2 = route.points[i]
			var samples := ceili(a.distance_to(b)*2)
			for step in samples+1: stamp(a.lerp(b,float(step)/samples),2.55+sin(step*.17)*.25,Vector2i(route.a,route.b))
	# The sealed viewing aperture is the only geometric contact with Area 10.
	for x in range(38,47):
		for y in range(115,123): cells[Vector2i(x,y)] = Vector2i(6 if x < 42 else 10,0)
func layer(name_: String, resource: String, z: int, solid := false) -> TileMapLayer:
	var node := TileMapLayer.new()
	node.name = name_
	node.tile_set = load(resource)
	node.scale = Vector2.ONE*.5
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.collision_enabled = solid
	node.navigation_enabled = false
	node.z_index = z
	own(node)
	return node
func sprite(parent: Node, texture: String, region: Rect2, scale_: float, position_: Vector2 = Vector2.ZERO) -> Sprite2D:
	var tex := AtlasTexture.new()
	tex.atlas = load(texture)
	tex.region = region
	var node := Sprite2D.new()
	node.texture = tex
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.scale = Vector2.ONE*scale_
	node.position = position_
	own(node,parent)
	return node
func actor(name_: String, kind: String, area: int, position_: Vector2) -> Node2D:
	var node := Node2D.new()
	node.name = name_
	node.set_script(load("res://scripts/world/cave_actor.gd"))
	node.role = kind
	node.area = area
	node.position = position_
	own(node,map.get_node("Characters"))
	return node
func prop(name_: String, point: Vector2, atlas: String, region: Rect2, scale_: float, solid := true):
	var node := StaticBody2D.new()
	node.name = name_
	node.position = point
	node.collision_layer = 1 if solid else 0
	node.collision_mask = 2
	own(node,map.get_node("Decorations"))
	sprite(node,atlas,region,scale_,Vector2(0,-region.size.y*scale_*.35))
	if solid:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(region.size.x*scale_*.7,region.size.y*scale_*.3)
		shape.shape = rect
		own(shape,node)
func furniture():
	var inner := "res://assets/enironment/gfx/Inner.png"
	var objects := "res://assets/enironment/gfx/objects.png"
	for i in 3:
		var x := (73+i*10)*Plan.CELL
		prop("Counter"+str(i),Vector2(x,60*32),inner,Rect2(160,0,48,48),2.0)
		prop("Chair"+str(i),Vector2(x,63*32),inner,Rect2(256,64,16,32),2.0)
	prop("HubTable",Vector2(83,73)*32,inner,Rect2(224,112,48,32),2.0)
	for x in [80,86]: prop("TableChair"+str(x),Vector2(x,74)*32,inner,Rect2(256,64,16,32),2.0)
	for i in 3: prop("StorageChest"+str(i),Vector2(66+i*3,87)*32,objects,Rect2(144,0,32,16),2.0)
	for room in Plan.ROOMS:
		if room.id in [4,9]: continue
		var rect: Rect2i = room.rect
		for i in 3:
			var p := Vector2(rect.position+Vector2i(5+i*3,5))*32
			prop("Rubble%d_%d"%[room.id,i],p,objects,Rect2(128,64,32,32),1.0,false)
func cache():
	var size := Plan.SIZE*2
	var image := Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
	image.fill(Color("#15131c"))
	for cell in cells:
		for offset in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE]: image.set_pixelv(cell*2+offset,Color("#777261") if cells[cell].x != 4 else Color("#918b7b"))
	var texture := ImageTexture.create_from_image(image)
	texture.set_meta("source_hashes",{"underground_cave":FileAccess.get_sha256("res://scenes/world/underground_cave.tscn")})
	ResourceSaver.save(texture,"res://resources/maps/underground_terrain.res")
func run():
	if "--cache-only" in OS.get_cmdline_user_args():
		# Refresh cartography from the saved scene without replacing manual tile edits.
		map = load("res://scenes/world/underground_cave.tscn").instantiate()
		var hub: TileMapLayer = map.get_node("HubFloor")
		for cell in map.get_node("CaveFloor").get_used_cells():
			cells[cell] = Vector2i(4 if hub.get_cell_source_id(cell) >= 0 else 1,0)
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
	map.set_meta("chamber_count",10)
	var floor := layer("CaveFloor","res://resources/cave/dungeon_floor.tres",-5)
	var points: Array[Vector2i] = []
	points.assign(cells.keys())
	floor.set_cells_terrain_connect(points,0,0,false)
	var hub := layer("HubFloor","res://resources/cave/dungeon_hub_floor.tres",-4)
	var hub_cells: Array[Vector2i] = []
	var hidden := layer("ColoredFloor","res://resources/cave/dungeon_hub_floor.tres",-4)
	hidden.modulate = Color("#80D6B9")
	var hidden_cells: Array[Vector2i] = []
	for cell in cells:
		if cells[cell].x == 4 and cells[cell].y == 0: hub_cells.append(cell)
		if cells[cell].x == 10: hidden_cells.append(cell)
	hub.set_cells_terrain_connect(hub_cells,0,0,false)
	hidden.set_cells_terrain_connect(hidden_cells,0,0,false)
	var walls := layer("CaveWalls","res://resources/cave/dungeon_walls.tres",0,true)
	var wall_cells := {}
	for cell in cells:
		for delta in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]:
			if not cells.has(cell+delta): wall_cells[cell+delta] = cells[cell]
	var boundary: Array[Vector2i] = []
	boundary.assign(wall_cells.keys())
	walls.set_cells_terrain_connect(boundary,0,0,false)
	# Empty compatibility layer; new terrain does not introduce water into the cave.
	layer("CaveWater","res://resources/cave/dungeon_floor.tres",-3)
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
	actor("RiddleCat","riddle",2,Plan.center(1))
	actor("WarningCat","warning",4,Vector2(86,69)*32)
	actor("QuietCat","social",4,Vector2(96,63)*32)
	actor("SavePoint","save",4,Vector2(71,83)*32)
	actor("RedBarrier","red_gate",5,Plan.RED_GATE)
	actor("SealedWindow","window",6,Vector2(41,119)*32)
	actor("HubShortcut","shortcut_hub",4,Plan.SHORTCUT_HUB)
	actor("JunctionShortcut","shortcut_junction",8,Plan.SHORTCUT_JUNCTION)
	furniture()
	var atmosphere := Node2D.new()
	atmosphere.name = "UndergroundAtmosphere"
	atmosphere.set_script(load("res://scripts/world/cave_atmosphere.gd"))
	own(atmosphere)
	assert(ResourceSaver.save(pack(),"res://scenes/world/underground_cave.tscn") == OK)
	cache()
	print("Ten-area cave rebuilt from schematic: ",cells.size()," floor cells; ",wall_cells.size()," wall cells")
	map.free()
	quit()
func pack() -> PackedScene:
	var scene := PackedScene.new()
	assert(scene.pack(map) == OK)
	return scene
