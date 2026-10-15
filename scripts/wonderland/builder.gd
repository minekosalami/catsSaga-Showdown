extends RefCounted
## Deterministic authoring tool. Playable maps are baked scenes, not regenerated on entry.
const Plan = preload("res://scripts/wonderland/layout.gd")
const Ornament = preload("res://scripts/wonderland/ornament.gd")
var rng := RandomNumberGenerator.new()
var map: Node2D
var paths: Array[PackedVector2Array] = []
var clearings: Array[Rect2] = []
var reserved: Array[Rect2] = []
var palette: Array[ShaderMaterial] = []
var tiles: Dictionary = {}
var ground: TileMapLayer
var road: TileMapLayer

func setup_tiles() -> void:
	# Load licensed human-art resources. Never synthesize replacement pixels.
	for kind in ["grass","road","wood","marble"]:
		tiles[kind] = load("res://resources/wonderland/"+kind+".tres")

func owner_tree(node: Node, root_node: Node) -> void:
	for child in node.get_children():
		child.owner = root_node
		owner_tree(child,root_node)

func layer(name: String, kind: String, z: int) -> TileMapLayer:
	var node := TileMapLayer.new()
	node.name = name
	node.tile_set = tiles[kind]
	node.scale = Vector2.ONE*2
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.z_index = z
	map.add_child(node)
	return node

func solid(parent: Node2D, size: Vector2, point := Vector2.ZERO) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	body.position = point
	parent.add_child(body)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	return body

func ornament(kind: String, point: Vector2, color := Color("#ed84b1"), collision := Vector2.ZERO, variation := 0) -> Node2D:
	var node := Ornament.new()
	node.kind = kind
	node.accent = color
	node.variant = variation
	node.scale = Vector2.ONE*2
	node.position = point
	node.name = kind.to_pascal_case()+str(map.get_child_count())
	map.add_child(node)
	if collision != Vector2.ZERO: solid(node,collision/2,Vector2(0,-collision.y*.25))
	node.set_meta("map_color",color)
	return node

func sprite(kind: String, point: Vector2, tint := 0) -> Node2D:
	var root := Node2D.new()
	root.position = point
	root.name = kind.to_pascal_case()+str(map.get_child_count())
	map.add_child(root)
	var art := Ornament.new()
	art.kind = "house" if kind.begins_with("house") else kind
	art.scale = Vector2.ONE*2
	art.variant = tint
	root.add_child(art)
	if kind.begins_with("house"):
		var dimensions: Vector2 = {"house1":Vector2(88,103),"house2":Vector2(157,112),"house3":Vector2(180,128),"house4":Vector2(128,128)}[kind]
		var door_x: float = {"house1":44,"house2":113,"house3":149,"house4":106}[kind]
		art.footprint = dimensions
		art.visual_offset.x = (dimensions.x-door_x*2)/2
		solid(root,Vector2(dimensions.x*1.75,82),Vector2(art.visual_offset.x*2,-49))
		reserved.append(Rect2(point+Vector2(art.visual_offset.x*2-dimensions.x-40,-dimensions.y*2-30),Vector2(dimensions.x*2+80,dimensions.y*2+160)))
	elif kind == "tree": solid(root,Vector2(24,20),Vector2(0,-5))
	root.set_meta("map_color",Color("#be89ca") if tint%2 else Color("#61af9c"))
	return root

func label(text: String, point: Vector2, color := Color("#544e68")) -> void:
	var node := Label.new()
	node.text = text
	node.position = point-Vector2(150,0)
	node.size = Vector2(300,24)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_font_override("font",preload("res://assets/ui/fonts/DejaVuSansMono.ttf"))
	node.add_theme_font_size_override("font_size",14)
	node.add_theme_color_override("font_color",color)
	node.add_theme_color_override("font_outline_color",Color("#fff3d8"))
	node.add_theme_constant_override("outline_size",4)
	map.add_child(node)

func entry(name: String, point: Vector2, facing: Vector2) -> void:
	var marker := Marker2D.new()
	marker.name = name
	marker.position = point
	marker.set_meta("facing_direction",facing)
	map.get_node("Entries").add_child(marker)

func portal(name: String, point: Vector2, destination: String, marker: String, side: String, gate := "") -> void:
	var node: Area2D = load("res://scripts/wonderland/connection.gd").new()
	node.name = name
	node.position = point
	node.destination = destination
	node.entry = marker
	node.gate_flag = gate
	node.collision_layer = 0
	node.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(144,48) if side in ["north","south"] else Vector2(48,144)
	shape.shape = rect
	node.add_child(shape)
	map.get_node("Portals").add_child(node)

func path(points: PackedVector2Array) -> void:
	var curve := Curve2D.new()
	for i in points.size():
		var prev: Vector2 = points[maxi(0,i-1)]
		var next: Vector2 = points[mini(points.size()-1,i+1)]
		var handle := (next-prev)*.13
		curve.add_point(points[i],-handle if i>0 else Vector2.ZERO,handle if i<points.size()-1 else Vector2.ZERO)
	paths.append(curve.tessellate(4,5))

func path_distance(point: Vector2) -> float:
	var distance := INF
	for route in paths:
		for i in range(1,route.size()): distance = minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,route[i-1],route[i])))
	return distance

func build(id: String) -> Node2D:
	map = Node2D.new()
	map.name = id.to_pascal_case()
	map.set_script(preload("res://scripts/wonderland/area.gd"))
	map.region_id = id
	map.display_name = Plan.regions()[id].name
	map.map_size = Vector2(Plan.regions()[id].size)*16
	map.y_sort_enabled = true
	map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for name in ["Entries","Portals"]:
		var node := Node2D.new()
		node.name = name
		map.add_child(node)
	paths.clear()
	clearings.clear()
	reserved.clear()
	rng.seed = hash(id)
	if Plan.OUTDOORS.has(id): outdoor(id)
	else: interior(id)
	var ambience := preload("res://scripts/wonderland/ambience.gd").new()
	ambience.name = "WonderlandAmbience"
	ambience.z_index = 3
	ambience.indoor = not Plan.OUTDOORS.has(id)
	map.add_child(ambience)
	owner_tree(map,map)
	return map

func add_links(id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for link in Plan.LINKS:
		if id != link[0] and id != link[3]: continue
		var a := 0 if id == link[0] else 3
		var b := 3-a
		var side: String = link[a+1]
		var destination: String = link[b]
		var point := Plan.edge(id,side,link[a+2])
		portal("To_"+destination,point,destination,"From_"+id,side)
		entry("From_"+destination,Plan.edge(id,side,link[a+2],192),Plan.inward(side))
		result.append({"point":point,"side":side,"along":link[a+2],"destination":destination})
	return result

func outdoor(id: String) -> void:
	ground = layer("Ground","grass",-8)
	road = layer("GardenPaths","road",-6)
	var links := add_links(id)
	var center: Vector2 = map.map_size*.5
	if id == "wonderland_forest":
		center = Vector2(1280,1120)
		entry("FromFlooded",Vector2(1280,1728),Vector2.UP)
		portal("ToFlooded",Vector2(1280,1888),"flooded_forest","FromWonderland","south")
		path(PackedVector2Array([Vector2(1280,1920),Vector2(1280,1610),Vector2(1460,1430),center]))
		clearings.append(Rect2(920,770,720,560))
		ornament("great_tree",Vector2(1280,940),Color("#75c4ba"),Vector2(96,56))
		path(PackedVector2Array([center,Vector2(850,1050),Vector2(760,710),Vector2(1040,520),Vector2(1460,510),Vector2(1740,780),Vector2(1690,1150),center]))
	elif id == "wonderland_village":
		center = Vector2(1920,1060)
		clearings.append(Rect2(300,250,3250,1430))
		ornament("fountain",center,Color("#ad8fd0"),Vector2(150,80))
		path(PackedVector2Array([Vector2(1100,1000),Vector2(1400,830),Vector2(1950,810),Vector2(2450,1000),Vector2(2490,1250),Vector2(2000,1330),Vector2(1400,1270),Vector2(1100,1000)]))
		for building in Plan.BUILDINGS:
			build_house(building)
			var start: Vector2 = building.point+Vector2(0,110)
			var join := Vector2(clampf(start.x,1150,2450),900 if start.y < 1060 else 1270)
			path(PackedVector2Array([start,Vector2(start.x,join.y),join]))
	elif id == "tea_gardens":
		center = Vector2(1280,1060)
		clearings.append(Rect2(400,480,1730,1020))
		for p in [Vector2(740,800),Vector2(1380,1170),Vector2(1800,720)]:
			ornament("tea_table",p,Color("#e28fb9"),Vector2(248,64))
			for x in [-94,0,94]: ornament("chair",p+Vector2(x,75),Color("#a786cd"),Vector2(30,22))
			ornament("teapot",p+Vector2(48,-45),Color("#8acfd3"))
		path(PackedVector2Array([Vector2(650,1050),Vector2(700,1300),Vector2(1130,1450),Vector2(1820,1310),Vector2(2020,970),Vector2(1750,510),Vector2(1100,500),Vector2(650,1050)]))
		ornament("grand_teapot",Vector2(590,1430),Color("#edb9d3"),Vector2(100,48))
		ornament("grand_teacup",Vector2(1910,1440),Color("#88d1c8"),Vector2(100,48))
		for p in [Vector2(950,880),Vector2(1700,1430),Vector2(1110,620)]: garden_bed(p,Color("#df83b7"))
		for p in [Vector2(920,1170),Vector2(1720,1050),Vector2(1490,600),Vector2(510,1000)]: ornament("flowerpot",p,Color("#a68acb"),Vector2(28,20))
	elif id == "mushroom_thicket":
		center = Vector2(1320,1070)
		path(PackedVector2Array([Vector2(1280,32),Vector2(1430,420),Vector2(1160,740),center,Vector2(1590,1400),Vector2(1950,1400),Vector2(2090,1020),Vector2(1880,650),Vector2(1430,420)]))
		for p in [Vector2(880,580),Vector2(1800,760),Vector2(1650,1560),Vector2(630,1410)]:
			ornament("mushroom",p,Color("#d781b9"),Vector2(30,22))
			for i in range(4): ornament("mushroom",p+Vector2(-130+i*77,70+(i%2)*46),[Color("#af92dc"),Color("#6bbfcc"),Color("#e990a7")][i%3],Vector2(22,16) if i%2 == 0 else Vector2(16,12),i%2+1)
	elif id == "royal_woods":
		center = Vector2(2400,1030)
		clearings.append(Rect2(2680,200,950,1000))
		path(PackedVector2Array([Vector2(3200,32),Vector2(3200,480),Vector2(2940,750),center,Vector2(1900,1180),Vector2(1530,1420),Vector2(1280,1888)]))
		for p in [Vector2(3060,500),Vector2(3330,500),Vector2(1980,1200),Vector2(2440,670)]: ornament("banner",p,Color("#ce7fae"))
		for y in range(300,900,120):
			for x in [3000,3400]: ornament("roses",Vector2(x,y),Color("#dc7193"))
		ornament("arch",Vector2(3200,800),Color("#8bbcac"))
	elif id == "queens_castle":
		map.set_meta("camera_focus",Vector2(0,-256))
		center = Vector2(1280,1110)
		clearings.append(Rect2(500,100,1560,1570))
		ornament("castle",Vector2(1280,860),Color("#e197be"))
		solid(map,Vector2(740,430),Vector2(1280,630))
		ornament("fountain",Vector2(1280,1400),Color("#b9a1dc"),Vector2(140,80))
		for x in [900,1660]:
			for y in range(1050,1600,120): ornament("roses",Vector2(x,y),Color("#d96694"))
		for p in [Vector2(780,820),Vector2(1780,820),Vector2(790,1150),Vector2(1770,1150)]: garden_bed(p,Color("#df83b7"))
		for p in [Vector2(690,690),Vector2(1860,690),Vector2(690,1080),Vector2(1860,1080)]: sprite("tree",p,3)
		path(PackedVector2Array([Vector2(640,1888),Vector2(760,1610),Vector2(1040,1460),center,Vector2(1280,880)]))
		path(PackedVector2Array([Vector2(1920,1888),Vector2(1800,1610),Vector2(1520,1460),center]))
		entry("FromCastleHall",Vector2(1280,1030),Vector2.DOWN)
		portal("CastleEntrance",Vector2(1280,860),"castle_hall","FromGrounds","north",Plan.CASTLE_OPEN)
		gate("castle",Vector2(1280,880))
	for link in links:
		var point: Vector2 = link.point
		var join: Vector2 = center
		if id == "queens_castle": continue
		if id == "wonderland_village": join = Vector2(1250,980) if point.y<600 or point.x<100 else Vector2(2400,1270)
		if id == "royal_woods" and link.side != "east": continue
		if id == "mushroom_thicket" and link.side == "north": continue
		var mid := point.lerp(join,.5)+Vector2(45,-90)
		path(PackedVector2Array([point,mid,join]))
		label(Plan.regions()[link.destination].name,point+Plan.inward(link.side)*260)
	var cells := Vector2i(map.map_size/32)
	var path_cells: Array[Vector2i] = []
	for y in cells.y:
		for x in cells.x:
			ground.set_cell(Vector2i(x,y),0,Vector2i(5,0))
			if path_distance(Vector2(x*32+16,y*32+16)) < (104 if id == "wonderland_village" else 79): path_cells.append(Vector2i(x,y))
	road.set_cells_terrain_connect(path_cells,0,0,false)
	forest(id)
	boundaries(links)

func gate(kind: String, point: Vector2) -> void:
	var node: Node2D = load("res://scripts/wonderland/gate.gd").new()
	node.kind = kind
	node.position = point
	node.name = "CastleGate" if kind == "castle" else "PinkWonderlandDoor"
	map.add_child(node)

func forest(id: String) -> void:
	# Composed groves surround authored paths and clearings; trunks never block routes.
	for y in range(70,int(map.map_size.y)-40,93):
		for x in range(60,int(map.map_size.x)-40,101):
			var p: Vector2 = Vector2(x+rng.randf_range(-27,27),y+rng.randf_range(-26,26))
			var blocked := path_distance(p) < 107
			for rect in clearings+reserved:
				if rect.has_point(p): blocked = true
			if blocked: continue
			var color_group := (int(p.x/550)+int(p.y/410))%4
			sprite("tree",p,color_group)
			if rng.randf()<.55: sprite("bush",p+Vector2(33,28),color_group)
			if rng.randf()<.25: ornament("flowers",p+Vector2(-27,32),Color("#e89fb7"))
			if rng.randf()<.28: ornament("leaf_litter",p+Vector2(5,16),Color("#b3c27f"),Vector2.ZERO,int(p.x)).z_index = -4
			if id == "mushroom_thicket" and rng.randf()<.10: ornament("giant_flower",p+Vector2(-34,28),Color("#f0b58e"))
	for route in paths:
		for i in range(1,route.size(),3):
			var direction := (route[i]-route[i-1]).normalized()
			for side in [-1,1]:
				var p: Vector2 = route[i]+direction.orthogonal()*side*125
				if not Rect2(Vector2(60,60),map.map_size-Vector2(120,120)).has_point(p): continue
				var in_building := false
				for rect in reserved:
					if rect.has_point(p): in_building = true
				if not in_building: ornament("flowers",p,[Color("#f1a2c9"),Color("#e9c567"),Color("#a48edf")][(i/3)%3])
	if id == "royal_woods":
		for y in range(270,820,90):
			for x in [2900,3500]: sprite("bush",Vector2(x,y),0)

func boundaries(links: Array[Dictionary]) -> void:
	# Visible tree-backed borders, with openings at actual adjoining routes.
	for side in ["north","south","west","east"]:
		var length: float = map.map_size.x if side in ["north","south"] else map.map_size.y
		var openings: Array[float] = []
		for link in links:
			if link.side == side: openings.append(link.along)
		if map.region_id == "wonderland_forest" and side == "south": openings.append(1280.0)
		if not Plan.OUTDOORS.has(map.region_id) and side == "south" and not Plan.CASTLE_ROOMS.has(map.region_id): openings.append(640.0)
		if map.region_id == "castle_hall" and side == "south": openings.append(640.0)
		openings.sort()
		var before := 0.0
		for opening in openings+[length+96]:
			var end := minf(length,opening-96)
			if end>before:
				var point := Plan.edge(map.region_id,side,(before+end)*.5,16)
				var size := Vector2(end-before,32) if side in ["north","south"] else Vector2(32,end-before)
				var body := solid(map,size,point)
				if not Plan.OUTDOORS.has(map.region_id):
					var wall := Ornament.new()
					wall.kind = "wall"
					wall.footprint = size
					wall.visual_offset = -size/2
					body.add_child(wall)
			before = opening+96

func build_house(building: Dictionary) -> void:
	var p: Vector2 = building.point
	if building.kind.begins_with("house"):
		sprite(building.kind,p)
	elif building.kind == "mushroom_house":
		ornament("mushroom_house",p,building.color)
		solid(map,Vector2(100,52),p+Vector2(0,-31))
		reserved.append(Rect2(p+Vector2(-100,-150),Vector2(200,280)))
	else:
		ornament(building.kind,p,building.color,Vector2(150,64))
		reserved.append(Rect2(p+Vector2(-160,-260),Vector2(320,410)))
	entry("From_"+building.id,p+Vector2(0,104),Vector2.DOWN)
	portal("Enter_"+building.id,p+Vector2(0,14),building.id,"FromVillage","north")
	label(building.name,p+Vector2(0,45))
	for x in [-110,110]: ornament("flowers",p+Vector2(x,18),building.color)
	for x in [-170,170]: ornament("flowerpot",p+Vector2(x,-15),building.color,Vector2(28,20))
	for side in [-1,1]:
		for y in [110,180]: sprite("bush",p+Vector2(side*118,y),int(abs(p.x)/400)%4)
	if building.id == "flower_shop":
		for x in range(-210,-50,40): ornament("flowers",p+Vector2(x,15),building.color.lightened(.1))
	if building.id == "bakery": ornament("counter",p+Vector2(110,6),building.color,Vector2(90,22),1)

func garden_bed(point: Vector2,color: Color) -> void:
	for x in [-55,0,55]:
		for y in [-30,30]: ornament("roses",point+Vector2(x,y),color)
	for x in [-90,90]: sprite("bush",point+Vector2(x,10),0)

func interior(id: String) -> void:
	var castle := Plan.CASTLE_ROOMS.has(id)
	map.set_meta("camera_bounds",Rect2(0,120,1280,720))
	var backdrop := Ornament.new()
	backdrop.kind = "wall_background"
	backdrop.footprint = Vector2(1280,960)
	backdrop.z_index = -12
	map.add_child(backdrop)
	ground = layer("Ground","marble" if castle else "wood",-8)
	for y in range(30):
		for x in range(40):
			if x>=4 and x<36 and y>=7 and y<26: ground.set_cell(Vector2i(x,y),0,Vector2i.ZERO)
	var links := add_links(id)
	for link in links:
		var center := Vector2i(link.point/32)
		for y in range(30):
			for x in range(40):
				if (link.side in ["west","east"] and abs(y-center.y)<3) or (link.side in ["north","south"] and abs(x-center.x)<3): ground.set_cell(Vector2i(x,y),0,Vector2i.ZERO)
	if not castle:
		entry("FromVillage",Vector2(640,736),Vector2.UP)
		portal("ExitToVillage",Vector2(640,800),"wonderland_village","From_"+id,"south")
	elif id == "castle_hall":
		entry("FromGrounds",Vector2(640,736),Vector2.UP)
		portal("ExitToGrounds",Vector2(640,800),"queens_castle","FromCastleHall","south")
	boundaries(links)
	var accent := Color("#d98bb4")
	for b in Plan.BUILDINGS:
		if b.id == id: accent = b.color
	room_walls(links,accent,castle)
	var window_positions: Array = {
		"mushroom_cottage":[500],"teapot_house":[500],"flower_shop":[640],
		"clockmakers_house":[200,1080],"bakery":[200,910],"royal_gift_shop":[480,830],
		"storytellers_cottage":[355,735],"tiny_pink_house":[520],"royal_library":[355,735],
		"castle_hall":[440,840],"banquet_hall":[300,980],"throne_room":[500,780]
	}[id]
	for x in window_positions:
		var window := ornament("window",Vector2(x,208),accent,Vector2.ZERO,1 if id in ["storytellers_cottage","royal_library"] else 0)
		window.z_index = 1 # Wall decoration belongs above the Y-sorted wall face.
	if castle:
		for x in [190,1090]:
			for y in [340,660]: ornament("banner",Vector2(x,y),accent)
	ornament("rug",Vector2(640,620),accent).z_index = -5
	if not castle or id == "castle_hall": ornament("interior_door",Vector2(640,820),accent)
	match id:
		"mushroom_cottage":
			ornament("bed",Vector2(270,350),accent,Vector2(90,90))
			ornament("bookcase",Vector2(1000,270),accent,Vector2(100,40))
			ornament("tea_table",Vector2(670,410),accent,Vector2(240,60))
			for p in [Vector2(550,480),Vector2(790,480)]: ornament("chair",p,accent,Vector2(30,22))
			for p in [Vector2(220,780),Vector2(1060,780)]: ornament("mushroom",p,accent,Vector2(16,12),2)
		"teapot_house":
			ornament("tea_table",Vector2(640,400),accent,Vector2(240,60))
			ornament("teapot",Vector2(640,340),accent)
			for p in [Vector2(470,450),Vector2(810,450),Vector2(640,500)]: ornament("chair",p,accent,Vector2(30,22))
			ornament("counter",Vector2(250,260),accent,Vector2(180,40))
			ornament("bed",Vector2(1020,340),accent,Vector2(90,90))
		"flower_shop":
			ornament("counter",Vector2(900,350),accent,Vector2(180,40),2)
			for x in [240,420,600]:
				for y in [260,460]: ornament("flowerpot",Vector2(x,y),accent.lightened((int(x)%3)*.05),Vector2(30,20))
			ornament("bookcase",Vector2(1040,280),accent,Vector2(100,40))
			ornament("counter",Vector2(310,650),Color("#82c9a4"),Vector2(180,40),2)
		"clockmakers_house":
			for x in [270,450,640,830,1010]: ornament("clock",Vector2(x,260),accent,Vector2(50,34),int(x/170))
			ornament("workbench",Vector2(420,490),accent,Vector2(180,40))
			ornament("chair",Vector2(420,560),accent,Vector2(30,22))
			ornament("bed",Vector2(1030,620),accent,Vector2(90,90))
		"bakery":
			for x in [300,540,780]: ornament("oven",Vector2(x,280),accent,Vector2(100,70))
			for p in [Vector2(350,520),Vector2(880,520)]: ornament("counter",p,accent,Vector2(180,40),1)
			ornament("tea_table",Vector2(1000,750),accent,Vector2(200,60))
			ornament("bread_rack",Vector2(1040,300),accent,Vector2(100,40))
		"royal_gift_shop":
			for p in [Vector2(300,270),Vector2(650,270),Vector2(1000,270),Vector2(280,550),Vector2(1000,550)]: ornament("counter",p,accent,Vector2(180,40))
			for x in [190,1090]: ornament("banner",Vector2(x,420),accent)
		"storytellers_cottage":
			for x in [260,450,640,830,1020]: ornament("bookcase",Vector2(x,250),accent,Vector2(100,40),int(x/170))
			ornament("writing_desk",Vector2(500,480),accent,Vector2(240,60))
			for p in [Vector2(420,560),Vector2(580,560),Vector2(340,450)]: ornament("chair",p,accent,Vector2(30,22))
			ornament("bed",Vector2(1030,620),accent,Vector2(90,90))
		"tiny_pink_house":
			ornament("bed",Vector2(300,320),accent,Vector2(90,90))
			ornament("counter",Vector2(970,280),accent,Vector2(180,40),2)
			ornament("tea_table",Vector2(700,470),accent,Vector2(240,60))
			ornament("chair",Vector2(700,560),accent,Vector2(30,22))
			ornament("bookcase",Vector2(260,650),accent,Vector2(100,40))
		"castle_hall":
			for x in [300,980]:
				for y in [280,650]: ornament("banner",Vector2(x,y),accent)
			ornament("fountain",Vector2(640,400),Color("#ad99cc"),Vector2(120,60))
			ornament("interior_door",Vector2(640,240),Color("#d4b0d5"))
		"royal_library":
			for y in [260,650]:
				for x in [230,430,650,870,1080]: ornament("bookcase",Vector2(x,y),accent,Vector2(100,40),int(x/170))
			ornament("tea_table",Vector2(520,440),accent,Vector2(240,60))
			ornament("chair",Vector2(520,520),accent,Vector2(30,22))
		"banquet_hall":
			ornament("banquet_table",Vector2(640,350),Color("#d783a4"),Vector2(390,70))
			ornament("banquet_table",Vector2(640,700),Color("#d783a4"),Vector2(390,70))
			for y in [420,770]:
				for x in range(340,1000,160): ornament("chair",Vector2(x,y),accent,Vector2(30,22))
		"throne_room":
			ornament("rug",Vector2(640,450),Color("#be679c")).z_index = -5
			ornament("throne",Vector2(640,300),Color("#cb669e"),Vector2(100,50))
			for x in [300,980]:
				for y in [250,520,750]: ornament("banner",Vector2(x,y),accent)
			for p in [Vector2(240,300),Vector2(1040,300)]: ornament("roses",p,Color("#d95c8c"))
	# Purposeful small furnishings and plants make each room feel inhabited.
	for p in [Vector2(180,320),Vector2(1100,740)]: ornament("flowerpot",p,accent,Vector2(28,20))
	if id in ["teapot_house","mushroom_cottage","tiny_pink_house"]:
		ornament("kitchen_shelf",Vector2(800,270),accent,Vector2(112,30))

func room_walls(links: Array[Dictionary], accent: Color, castle: bool) -> void:
	for side in ["north","south","west","east"]:
		var horizontal: bool = side in ["north","south"]
		var start := 128.0 if horizontal else 160.0
		var end := 1152.0 if horizontal else 832.0
		var openings: Array[float] = []
		for link in links:
			if link.side == side: openings.append(link.along)
		if side == "south" and (not castle or map.region_id == "castle_hall"): openings.append(640.0)
		openings.sort()
		var before := start
		for opening in openings+[end+80]:
			var finish := minf(end,opening-80)
			if finish>before:
				var position := Vector2((before+finish)*.5,224 if side == "north" else 848) if horizontal else Vector2(144 if side == "west" else 1136,(before+finish)*.5)
				var size := Vector2(finish-before,32) if horizontal else Vector2(32,finish-before)
				var body := solid(map,size,position)
				var panel := Ornament.new()
				panel.kind = "wall"
				var visual := Rect2(-size/2,size)
				if side == "north": visual = Rect2(-size.x/2,-96,size.x,112)
				panel.footprint = visual.size
				panel.visual_offset = visual.position
				body.add_child(panel)
			before = opening+80
