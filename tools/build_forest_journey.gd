extends SceneTree
## Intentional editor authoring. New scenes only; no original scene/asset deleted.
const Plan = preload("res://scripts/journey/layout.gd")
const FLOOR = preload("res://assets/wonderland_human/ninja/tileset_floor.png")
const LARGE = preload("res://assets/wonderland_human/ninja/Floor.png")
const DETAILS = preload("res://assets/wonderland_human/ninja/details.png")
const TREES := [preload("res://assets/overhaul_human/ninja/tree_round.png"),preload("res://assets/wonderland_human/ninja/tree_04.png")]
const Terrain = preload("res://scripts/journey/terrain_rules.gd")
var sets := {}
var foliage_material: ShaderMaterial
var map: Node2D
var terrain: Dictionary
var path_cells := {}
var water_cells := {}
var routes: Array[PackedVector2Array] = []
var protected: Array[Vector2] = []
var rng := RandomNumberGenerator.new()
var id := ""
func _initialize() -> void: run.call_deferred()
func own(node: Node,parent: Node = null) -> void:
	if parent == null: parent = map
	parent.add_child(node)
	node.owner = map
func atlas(texture: Texture2D,size: int,cells: Array[Vector2i],solid := false) -> TileSet:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i.ONE*size
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i.ONE*size
	if solid:
		tiles.add_physics_layer()
		tiles.set_physics_layer_collision_layer(0,1)
		tiles.set_physics_layer_collision_mask(0,2)
	tiles.add_source(source,0)
	for cell in cells:
		source.create_tile(cell)
		if solid:
			var data := source.get_tile_data(cell,0)
			data.set_collision_polygons_count(0,1)
			var h := size*.5
			data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-h,-h),Vector2(h,-h),Vector2(h,h),Vector2(-h,h)]))
	return tiles
func resources() -> void:
	foliage_material = ShaderMaterial.new()
	foliage_material.shader = preload("res://shaders/forest_sway.gdshader")
	ResourceSaver.save(foliage_material,"res://resources/journey/foliage.tres")
	foliage_material.take_over_path("res://resources/journey/foliage.tres")
	var grass: Array[Vector2i] = []
	for x in range(11,16): grass.append(Vector2i(x,12))
	var road: Array[Vector2i] = []
	var water: Array[Vector2i] = []
	for y in range(7,10):
		for x in range(11,14): road.append(Vector2i(x,y)); water.append(Vector2i(x,y-1))
	var wood: Array[Vector2i] = []
	for y in range(13,16):
		for x in range(3):wood.append(Vector2i(x,y))
	var quarters: Array[Vector2i] = []
	for y in range(12,21):
		for x in range(22,38):quarters.append(Vector2i(x,y))
	sets = {"grass":atlas(FLOOR,16,grass),"path":atlas(FLOOR,16,road),"water":atlas(LARGE,64,water,true),"bridge":atlas(LARGE,64,wood),"trail_surface":atlas(FLOOR,8,quarters),"water_surface":atlas(LARGE,32,quarters),"plants":atlas(DETAILS,64,[Vector2i(0,2),Vector2i(1,2),Vector2i(2,2),Vector2i(3,2),Vector2i(5,2),Vector2i(0,0),Vector2i(1,0),Vector2i(3,0)])}
	var water_source := sets.water.get_source(0) as TileSetAtlasSource
	for cell in water:
		water_source.create_alternative_tile(cell,1)
		water_source.get_tile_data(cell,1).set_collision_polygons_count(0,0)
	sets.path.add_terrain_set()
	sets.path.set_terrain_set_mode(0,TileSet.TERRAIN_MODE_MATCH_SIDES)
	sets.path.add_terrain(0)
	sets.path.set_terrain_name(0,0,"Forest path")
	for cell in road:
		var data: TileData = sets.path.get_source(0).get_tile_data(cell,0)
		data.terrain_set = 0
		data.terrain = 0
		for pair in [[TileSet.CELL_NEIGHBOR_TOP_SIDE,cell.y>7],[TileSet.CELL_NEIGHBOR_RIGHT_SIDE,cell.x<13],[TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,cell.y<9],[TileSet.CELL_NEIGHBOR_LEFT_SIDE,cell.x>11]]:
			data.set_terrain_peering_bit(pair[0],0 if pair[1] else -1)
	for kind in sets:
		var path: String = "res://resources/journey/"+kind+".tres"
		ResourceSaver.save(sets[kind],path)
		sets[kind].take_over_path(path)
func layer(label: String,kind: String,scale_factor: float,z: int) -> TileMapLayer:
	var node := TileMapLayer.new()
	node.name = label
	node.tile_set = sets[kind]
	node.scale = Vector2.ONE*scale_factor
	node.z_index = z
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.collision_enabled = kind == "water"
	node.navigation_enabled = false
	own(node)
	return node
func distance_to_route(point: Vector2) -> float:
	var result := INF
	for route in routes:
		for i in range(1,route.size()):result = minf(result,point.distance_to(Geometry2D.get_closest_point_to_segment(point,route[i-1],route[i])))
	return result
func stamp(point: Vector2,radius: float) -> void:
	for y in range(int((point.y-radius)/32),int((point.y+radius)/32)+1):
		for x in range(int((point.x-radius)/32),int((point.x+radius)/32)+1):
			var cell := Vector2i(x,y)
			if (Vector2(cell)*32+Vector2.ONE*16).distance_to(point)<=radius and x>=0 and y>=0 and x<ceili(map.map_size.x/32) and y<ceili(map.map_size.y/32): path_cells[cell] = true
func route(points: PackedVector2Array,width := 90.0) -> void:
	routes.append(points)
	var curve := Curve2D.new()
	for i in points.size():
		var tangent := Vector2.ZERO
		if i>0 and i<points.size()-1: tangent = (points[i+1]-points[i-1]).normalized()*62
		curve.add_point(points[i],-tangent,tangent)
	for point in curve.get_baked_points():stamp(point,width)
func marker(name: String,point: Vector2,facing := Vector2.RIGHT) -> void:
	var mark := Marker2D.new()
	mark.name = name
	mark.position = point
	mark.set_meta("facing_direction",facing)
	own(mark,map.get_node("Entries"))
func portal(name: String,point: Vector2,destination: String,entry: String,flag := "") -> void:
	var node := Area2D.new()
	node.name = name
	node.set_script(load("res://scripts/world/portal.gd"))
	node.position = point
	node.destination = destination
	node.entry = entry
	node.required_flag = flag
	node.collision_layer = 0
	node.collision_mask = 2
	own(node,map.get_node("Portals"))
	var collision := CollisionShape2D.new()
	collision.shape = RectangleShape2D.new()
	collision.shape.size = Vector2(96,224)
	own(collision,node)
func body(label: String,point: Vector2,texture: Texture2D,height: float,width: float,depth: float,tree := false) -> void:
	var node := StaticBody2D.new()
	node.name = label
	node.position = point
	node.collision_layer = 1
	node.collision_mask = 2
	node.add_to_group("journey_trees" if tree else "journey_props",true)
	own(node,map)
	var shade := Sprite2D.new()
	shade.name = "GroundShadow"
	shade.texture = preload("res://assets/wonderland_human/ninja/Shadow.png")
	shade.scale = Vector2(height*.40/12,height*.10/8)
	shade.z_index = -1
	shade.modulate.a = .35
	shade.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	own(shade,node)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE*height/texture.get_height()
	sprite.position.y = -height*.43
	if tree:
		sprite.material = foliage_material
		node.set_script(load("res://scripts/journey/tree.gd"))
		node.size_multiplier = height/128.0
	own(sprite,node)
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = CapsuleShape2D.new()
	collision.shape.radius = width
	collision.shape.height = maxf(width*2,depth)
	collision.position.y = -depth*.3
	own(collision,node)
func npc_copy(original: Node,path: String,point: Vector2) -> void:
	var source := original.get_node_or_null(path)
	if source == null: return
	var copy := source.duplicate()
	copy.position = point
	# The generic test NPC's [TEMP] conversation is not approved story content.
	# Keep the character and original JSON; disconnect only this placeholder talk.
	if copy.name=="ForestNPC":
		copy.set_script(null)
		if copy.is_in_group("interactables"):copy.remove_from_group("interactables")
	own(copy,map.get_node("Characters"))
	if copy.name in ["ForestNPC","InspectableTree"]:
		for child in copy.get_children():
			if child is CanvasItem: child.visible = false
		var picture := Sprite2D.new()
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.texture = preload("res://assets/bartplayer.png") if copy.name=="ForestNPC" else TREES[0]
		var height := 72.0 if copy.name=="ForestNPC" else 152.0
		picture.scale = Vector2.ONE*height/picture.texture.get_height()
		picture.position.y = -height*.35
		own(picture,copy)
		if copy.name=="InspectableTree":
			var trunk := StaticBody2D.new()
			trunk.name = "Trunk"
			trunk.collision_layer = 1
			trunk.collision_mask = 2
			own(trunk,copy)
			var shape := CollisionShape2D.new()
			shape.shape = CapsuleShape2D.new()
			shape.shape.radius = 10
			shape.shape.height = 26
			shape.position.y = -8
			own(shape,trunk)
	if copy.name in ["ForestNPC","EvilBart","Boss2NPC","BlankKitten"]:
		var pose := Node.new()
		pose.name = "VisualPose"
		pose.set_script(preload("res://scripts/journey/npc_pose.gd"))
		own(pose,copy)
	_set_owner(copy)
	protected.append(point)
	stamp(point,150)
func _set_owner(node: Node) -> void:
	for child in node.get_children():
		child.owner = map
		_set_owner(child)
func protected_point(point: Vector2,radius: float) -> bool:
	for center in protected:
		if point.distance_to(center)<radius:return true
	return false
func boundary(point: Vector2,size: Vector2) -> void:
	var block := StaticBody2D.new()
	block.position = point
	block.collision_layer = 1
	block.collision_mask = 2
	own(block,map.get_node("Boundaries"))
	var collision := CollisionShape2D.new()
	collision.shape = RectangleShape2D.new()
	collision.shape.size = size
	own(collision,block)
func build(area: String) -> void:
	id = area
	rng.seed = 40500+Plan.ORDER.find(id)*31
	path_cells.clear();water_cells.clear();routes.clear();protected.clear()
	map = Node2D.new()
	map.name = Plan.SCENES[id]
	map.set_script(preload("res://scripts/journey/area.gd"))
	map.region_id = id
	map.map_size = Plan.SIZES[id]
	map.display_name = preload("res://scripts/maps/world_layout.gd").REGIONS[id].name
	map.y_sort_enabled = true
	for name in ["Entries","Portals","Characters","Discoveries","Boundaries"]:
		var node := Node2D.new();node.name = name;node.y_sort_enabled = name == "Characters";own(node)
	var ground := layer("GrassGround","grass",2,-10)
	var path := layer("Paths","path",2,-8)
	path.hide() # Editable logical footprint; the connected quarter atlas renders it.
	var trail_surface := layer("TrailSurface","trail_surface",2,-8)
	var water := layer("Water","water",.5,-7)
	water.hide() # Collision footprint stays 32px; only the surface needs quarter tiles.
	var water_surface := layer("WaterSurface","water_surface",.5,-7)
	var water_material := ShaderMaterial.new()
	water_material.shader = preload("res://shaders/forest_water.gdshader")
	water_surface.material = water_material
	var bridge := layer("Bridges","bridge",.5,-6)
	var plants := layer("Understory","plants",.5,-3)
	var grass_material := ShaderMaterial.new()
	grass_material.shader = preload("res://shaders/forest_understory.gdshader")
	plants.material = grass_material
	var grid := Vector2i(ceili(map.map_size.x/32),ceili(map.map_size.y/32))
	var noise := FastNoiseLite.new();noise.seed = int(rng.seed);noise.frequency = .09
	for y in grid.y:
		for x in grid.x:
			var cell := Vector2i(x,y)
			var variant := 11 if rng.randf()<.75 else rng.randi_range(12,15)
			ground.set_cell(cell,0,Vector2i(variant,12))
	ground.modulate = Color("#dce8cf") if id == "deep_forest" else (Color("#d3e1df") if id == "flooded_forest" else Color.WHITE)
	trail_surface.modulate = ground.modulate
	water_surface.modulate = ground.modulate
	route(Plan.points(id))
	var width: float = map.map_size.x
	# Three connected scenic loops per region: hand-composed branches, not empty fields.
	for index in range(3):
		var x := width*(.25+index*.24)
		var below := index%2 == 0
		var extent: float = map.map_size.y*(.76 if below else .24)
		var first := Vector2(x-180,Plan.SEAM_Y)
		var branch := PackedVector2Array([first,Vector2(x-160,extent-80),Vector2(x+80,extent),Vector2(x+320,extent-180),Vector2(x+360,Plan.SEAM_Y)])
		if id=="flooded_forest":
			branch = [PackedVector2Array([Vector2(844,912),Vector2(900,1500),Vector2(850,2200),Vector2(1104,2334),Vector2(1344,2154),Vector2(1500,1800),Vector2(1400,1200),Vector2(1376,1130)]),PackedVector2Array([Vector2(2144,816),Vector2(2087,737),Vector2(2200,440),Vector2(2680,600),Vector2(2440,1100)]),PackedVector2Array([Vector2(2850,912),Vector2(2580,1560),Vector2(2570,2080),Vector2(2810,2400),Vector2(3070,2334),Vector2(3552,2380),Vector2(3680,1990),Vector2(3552,1550),Vector2(3200,1300),Vector2(2850,912)])][index]
		route(branch,70)
		var discovery := Marker2D.new();discovery.name = "ScenicClearing"+str(index);discovery.position = Vector2(x+80,extent)
		own(discovery,map.get_node("Discoveries"))
	# Retain the six existing exploration landmarks as connected destinations.
	var landmark_points := [Vector2(width*.25+80,map.map_size.y*.76),Vector2(width*.55,map.map_size.y*.72-240),Vector2(width*.73+80,map.map_size.y*.76),Vector2(width*.25+320,map.map_size.y*.76-180),Vector2(width*.49+80,map.map_size.y*.24),Vector2(width*.73+320,map.map_size.y*.76-180)]
	var landmark_names := ["EastMeadow","PondsideClearing","SouthernGrove","LowerMeadow","QuietHollow","FarGlade"]
	for i in landmark_names.size():
		var mark := Marker2D.new()
		mark.name = landmark_names[i]
		mark.position = landmark_points[i]
		own(mark,map.get_node("Discoveries"))
		if i==1:
			route(PackedVector2Array([Vector2(2440,1100),Vector2(2440,1500),mark.position]) if id=="flooded_forest" else PackedVector2Array([Vector2(width*.55,Plan.SEAM_Y),Vector2(width*.55-100,mark.position.y-60),mark.position]),65)
		if id=="flooded_forest" and i==5:
			route(PackedVector2Array([Vector2(3630,2154),mark.position]),55)
	marker("Start",Plan.SPAWNS[id])
	for alias in ["FromEntrance","FromDeep","FromBart","FromFlooded","FromEntranceShortcut","FromBartShortcut","FromFloodedShortcut","FromCave","FromWonderland"]:
		marker(alias,Vector2(width-224,Plan.SEAM_Y) if (id=="entrance" and alias=="FromDeep") or (id=="deep_forest" and alias in ["FromBart","FromFlooded"]) or (id=="bart_area" and alias=="FromFloodedShortcut") else Plan.SPAWNS[id],Vector2.LEFT if alias in ["FromBart","FromFloodedShortcut"] else Vector2.RIGHT)
	var index := Plan.ORDER.find(id)
	if index>0:portal("ToLeft",Vector2(64,Plan.SEAM_Y),Plan.ORDER[index-1],"FromDeep" if index==1 else ("FromBart" if index==2 else "FromFloodedShortcut"))
	if index<3:portal("ToRight",Vector2(width-64,Plan.SEAM_Y),Plan.ORDER[index+1],"FromEntrance" if index==0 else "FromDeep","flooded_forest_key_obtained" if index==2 else "")
	protected.append(Plan.SPAWNS[id])
	if index<3: protected.append(Vector2(width-224,Plan.SEAM_Y))
	var original: Node = load("res://scenes/world/"+Plan.SCENES[id]+".tscn").instantiate()
	if id=="entrance":
		npc_copy(original,"Characters/InspectableTree",Vector2(736,592));route(PackedVector2Array([Vector2(704,800),Vector2(736,656)]),70)
	elif id=="deep_forest":
		npc_copy(original,"Characters/ForestNPC",Vector2(1024,600))
		npc_copy(original,"Characters/BlankKitten",Vector2(1344,600))
		route(PackedVector2Array([Vector2(832,Plan.SEAM_Y),Vector2(1024,672),Vector2(1344,672),Vector2(1600,Plan.SEAM_Y)]),85)
	elif id=="bart_area":
		npc_copy(original,"Characters/EvilBart",Vector2(1792,896))
		var deep: Node = load("res://scenes/world/deep_forest.tscn").instantiate()
		npc_copy(deep,"Characters/FloodedGate",Vector2(width-240,Plan.SEAM_Y-96));deep.free()
	elif id=="flooded_forest":
		npc_copy(original,"Characters/Boss2NPC",Vector2(3200,800));route(PackedVector2Array([Vector2(2850,Plan.SEAM_Y),Vector2(3200,864),Vector2(3480,Plan.SEAM_Y)]),90)
	original.free()
	# Two authored rectangular crossings, never a boardwalk stamped along a bank.
	var crossings: Array[Rect2i] = []
	if id=="flooded_forest":crossings.assign([Rect2i(54,24,13,4),Rect2i(103,65,10,4)])
	for rect in crossings:
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x):
				var cell := Vector2i(x,y)
				# Side rails run along the banks of the deck; both walking ends stay open.
				var tile := Vector2i(1,13 if y==rect.position.y else (15 if y==rect.end.y-1 else 14))
				bridge.set_cell(cell,0,tile)
				path_cells[cell] = true
	bridge.modulate = Color("#c6b39a")
	map.set_meta("bridge_rects",crossings)
	# Recess pond banks around dry trails instead of producing slivers of planks.
	for y in grid.y:
		for x in grid.x:
			var cell := Vector2i(x,y);var p := Vector2(cell)*32+Vector2(16,16)
			var lake := ((p-Vector2(width*.55,map.map_size.y*.72))/Vector2(width*.14,180)).length()<1
			if id=="flooded_forest": lake = absf(p.x-width*.49-sin(p.y*.006)*115)<110 or ((p-Vector2(width*.76,map.map_size.y*.65))/Vector2(450,320)).length()<1
			var channel := id=="flooded_forest" and absf(p.x-width*.49-sin(p.y*.006)*115)<110
			var dry_shoulder := false
			if id!="flooded_forest" and not channel and bridge.get_cell_source_id(cell)<0:
				for offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					if path_cells.has(cell+offset):dry_shoulder = true
			var island := id=="flooded_forest" and p.distance_to(Vector2(width*.73+320,map.map_size.y*.76-180))<72
			if lake and not island and not dry_shoulder and not protected_point(p,90 if id=="flooded_forest" else 180):
				water_cells[cell] = true
	for cell: Vector2i in water_cells:
		var tx := 12;var ty := 7
		if not water_cells.has(cell+Vector2i.LEFT):tx=11
		elif not water_cells.has(cell+Vector2i.RIGHT):tx=13
		if not water_cells.has(cell+Vector2i.UP):ty=6
		elif not water_cells.has(cell+Vector2i.DOWN):ty=8
		water.set_cell(cell,0,Vector2i(tx,ty),1 if bridge.get_cell_source_id(cell)>=0 else 0)
	for cell: Vector2i in path_cells:
		var tx:=12;var ty:=8
		if cell.x>0 and not path_cells.has(cell+Vector2i.LEFT):tx=11
		elif cell.x<grid.x-1 and not path_cells.has(cell+Vector2i.RIGHT):tx=13
		if not path_cells.has(cell+Vector2i.UP):ty=7
		elif not path_cells.has(cell+Vector2i.DOWN):ty=9
		path.set_cell(cell,0,Vector2i(tx,ty))
	Terrain.paint(trail_surface,path_cells,false)
	Terrain.paint(water_surface,water_cells,true)
	# Jittered, noise-weighted clusters keep a dense, irregular canopy on both sides.
	var count := 0
	for y in range(80,int(map.map_size.y)-32,82):
		for x in range(64,int(width)-32,79):
			var point := Vector2(x+rng.randf_range(-30,30),y+rng.randf_range(-28,28))
			var cell := Vector2i(point/32)
			if distance_to_route(point)<118 or path_cells.has(cell) or water_cells.has(cell) or protected_point(point,178):continue
			if rng.randf()<.08+maxf(0,noise.get_noise_2d(point.x*.025,point.y*.025))*.2:continue
			var scale := rng.randf_range(.85,1.17) if rng.randf()<.80 else (rng.randf_range(.7,.85) if rng.randf()<.65 else rng.randf_range(1.25,1.5))
			body("Tree"+str(count),point,TREES[rng.randi_range(0,TREES.size()-1)],128*scale,9*scale,25*scale,true)
			count+=1
			if count%3==0:
				var p := point+Vector2(34,24)
				plants.set_cell(Vector2i(p/32),0,Vector2i(rng.randi_range(0,3),2))
	# Rocks, stumps and branches at route shoulders, never in a reserved road corridor.
	for i in int(width*map.map_size.y/140000):
		var p := Vector2(rng.randf_range(120,width-120),rng.randf_range(160,map.map_size.y-96))
		var cell := Vector2i(p/32)
		if distance_to_route(p)<120 or protected_point(p,190) or water_cells.has(cell):continue
		body("Rock"+str(i),p,preload("res://assets/overhaul_human/ninja/rock.png") if i%3 else preload("res://assets/overhaul_human/ninja/stump.png"),rng.randf_range(64,96),22,40)
	for i in int(width*map.map_size.y/5000):
		var p := Vector2(rng.randf_range(64,width-64),rng.randf_range(64,map.map_size.y-64))
		var cell := Vector2i(p/32)
		if water_cells.has(cell) or path_cells.has(cell) or protected_point(p,120):continue
		plants.set_cell(cell,0,Vector2i(1 if i%2 else 3,0) if i%19==0 else (Vector2i(rng.randi_range(0,3),2) if i%8 else Vector2i(5,2)))
	boundary(Vector2(width*.5,16),Vector2(width,32));boundary(Vector2(width*.5,map.map_size.y-16),Vector2(width,32))
	boundary(Vector2(16,map.map_size.y*.5),Vector2(32,map.map_size.y));boundary(Vector2(width-16,map.map_size.y*.5),Vector2(32,map.map_size.y))
	map.set_meta("journey_revision",1)
	map.set_meta("main_route",Plan.points(id))
	map.set_meta("tree_count",count)
	var packed := PackedScene.new()
	var error := packed.pack(map)
	if error==OK:error = ResourceSaver.save(packed,Plan.scene(id))
	print("JOURNEY: ",id," trees=",count," routes=",routes.size()," save=",error)
	map.free()
	if error!=OK:quit(1)
func run() -> void:
	if not OS.get_cmdline_user_args().has("--apply"):
		push_error("Use -- --apply to author the new journey scenes.");quit(1);return
	resources()
	for area in Plan.ORDER:build(area)
	quit()
