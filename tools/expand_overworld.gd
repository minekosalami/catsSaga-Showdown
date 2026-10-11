extends SceneTree

## One-time authoring tool. Run on the pre-expansion scenes, not at game startup.
## The output is ordinary, editable TileMapLayers and shared tree instances.
const TREE = preload("res://scenes/world/tree.tscn")
const GRASS = preload("res://resources/world/forest_grass.tres")
const WATER = preload("res://resources/world/placeholder_water.tres")
const SPECS := {
	"forest_entrance": [Vector2i(200,114), Vector2(1480,450), 2101],
	"deep_forest": [Vector2i(320,180), Vector2(2440,1200), 2102],
	"bart_area": [Vector2i(200,114), Vector2(1360,450), 2103],
	"flooded_forest": [Vector2i(256,192), Vector2(1840,450), 2104],
}
var map: Node2D
var paths: TileMapLayer
var water: TileMapLayer
var old_size: Vector2i
var grid: Vector2i
var random := RandomNumberGenerator.new()
var clearings: Array[Vector2] = []
var added_paths: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func owned(node: Node, parent: Node) -> void:
	parent.add_child(node)
	node.owner = map

func layer(label: String, tiles: TileSet, depth: int, solid: bool) -> TileMapLayer:
	var node := TileMapLayer.new()
	node.name = label
	node.tile_set = tiles
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.z_index = depth
	node.collision_enabled = solid
	node.navigation_enabled = false
	owned(node, map)
	return node

func run() -> void:
	# Refuse a second bake rather than duplicating content or moving old entries.
	for filename in SPECS:
		var original: Node = load("res://scenes/world/" + filename + ".tscn").instantiate()
		var already_expanded := original.has_node("Discoveries")
		original.free()
		if already_expanded:
			push_error("Expansion already baked. Restore the pre-expansion scenes before running this tool.")
			quit(1)
			return
	for filename in SPECS:
		map = load("res://scenes/world/" + filename + ".tscn").instantiate()
		root.add_child(map)
		var ground: TileMapLayer = map.get_node("GrassGround")
		old_size = ground.get_used_rect().size
		grid = SPECS[filename][0]
		map.map_size = Vector2(grid * 16)
		random.seed = SPECS[filename][2]
		for y in grid.y:
			for x in grid.x:
				var cell := Vector2i(x,y)
				if ground.get_cell_source_id(cell) == -1:
					var tone := 1
					var noise := random.randf()
					if noise < 0.018: tone = 0
					elif noise > 0.985: tone = 2
					ground.set_cell(cell,0,Vector2i(3,tone))
		paths = map.get_node("WindingTrails" if filename == "flooded_forest" else "Paths")
		water = layer("ExpansionWater",WATER,-3,true)
		added_paths.clear()
		clearings.clear()
		var discoveries := Node2D.new()
		discoveries.name = "Discoveries"
		owned(discoveries,map)
		var names := ["EastMeadow", "PondsideClearing", "SouthernGrove", "LowerMeadow", "QuietHollow", "FarGlade"]
		var positions := [Vector2(0.64,0.22),Vector2(0.83,0.42),Vector2(0.70,0.70),Vector2(0.42,0.82),Vector2(0.18,0.76),Vector2(0.87,0.85)]
		for i in positions.size():
			var position: Vector2 = positions[i] * map.map_size
			clearings.append(position)
			var marker := Marker2D.new()
			marker.name = names[i]
			marker.position = position
			marker.set_meta("reserved_radius",120.0)
			owned(marker,discoveries)
		# Meandering branches end beside open grassy clearings, not paved squares.
		var anchor: Vector2 = SPECS[filename][1]
		trail(anchor, clearings[0])
		for i in range(4): trail(clearings[i],clearings[i+1])
		trail(clearings[2],clearings[5])
		if filename == "forest_entrance":
			shortcut("ToBart","bart_area","FromEntranceShortcut","bart_defeated",Vector2(0.42,0.94),"BART")
		elif filename == "bart_area":
			shortcut("ToEntrance","entrance","FromBartShortcut","bart_defeated",Vector2(0.64,0.12),"ENTRANCE")
			shortcut("ToFlooded","flooded_forest","FromBartShortcut","boss2_defeated",Vector2(0.93,0.70),"FLOODED")
		elif filename == "flooded_forest":
			shortcut("ToBart","bart_area","FromFloodedShortcut","boss2_defeated",Vector2(0.08,0.76),"BART")
		pond(Vector2(0.84,0.18)*map.map_size,Vector2(190,120))
		pond(Vector2(0.52,0.61)*map.map_size,Vector2(130,100))
		pond(Vector2(0.23,0.92)*map.map_size,Vector2(170,80))
		# A winding stream near the far edge; keep a broad dry crossing halfway.
		for y in range(int(grid.y*0.28),int(grid.y*0.78)):
			if absf(y-grid.y*0.54) < 5: continue
			var center := int(grid.x*0.96 + sin(y*0.08)*2.5)
			for x in range(center-2,center+3): wet(Vector2i(x,y))
		resize_boundaries()
		clear_old_tree_overlaps()
		plant_clusters()
		flowers()
		var packed := PackedScene.new()
		var error := packed.pack(map)
		if error == OK: error = ResourceSaver.save(packed,"res://scenes/world/"+filename+".tscn")
		print(filename," ",grid," saved=",error)
		map.free()
		if error != OK:
			quit(1)
			return
	quit()

func trail(a: Vector2, b: Vector2) -> void:
	var length := a.distance_to(b)
	var normal := (b-a).normalized().orthogonal()
	var bend := minf(length*0.10,96.0)
	for index in range(ceili(length/8.0)+1):
		var t := float(index)/maxi(ceili(length/8.0),1)
		var position := a.lerp(b,t)+normal*sin(t*PI)*bend
		var center := paths.local_to_map(position)
		for y in range(-3,4):
			for x in range(-3,4):
				if Vector2(x,y).length() > 3.4: continue
				var cell := center+Vector2i(x,y)
				if cell.x < 2 or cell.y < 2 or cell.x >= grid.x-2 or cell.y >= grid.y-2: continue
				if paths.get_cell_source_id(cell) == -1:
					paths.set_cell(cell,0,Vector2i(6,1))
					added_paths[cell] = true

func wet(cell: Vector2i) -> void:
	if cell.x < 3 or cell.y < 3 or cell.x >= grid.x-3 or cell.y >= grid.y-3: return
	if cell.x < old_size.x and cell.y < old_size.y: return
	for y in range(-2,3):
		for x in range(-2,3):
			if paths.get_cell_source_id(cell+Vector2i(x,y)) != -1: return
	for clearing in clearings:
		if water.map_to_local(cell).distance_to(clearing) < 160: return
	water.set_cell(cell,0,Vector2i.ZERO)

func pond(center: Vector2, radii: Vector2) -> void:
	var minimum := water.local_to_map(center-radii*1.2)
	var maximum := water.local_to_map(center+radii*1.2)
	for y in range(minimum.y,maximum.y+1):
		for x in range(minimum.x,maximum.x+1):
			var offset := (water.map_to_local(Vector2i(x,y))-center)/radii
			var shoreline := 1.0 + sin(atan2(offset.y,offset.x)*5.0)*0.10
			if offset.length() < shoreline: wet(Vector2i(x,y))

func resize_boundaries() -> void:
	var size: Vector2 = map.map_size
	var centers := [Vector2(size.x/2,15),Vector2(size.x/2,size.y-15),Vector2(15,size.y/2),Vector2(size.x-15,size.y/2)]
	var walls := map.get_node("Obstacles").get_children()
	for i in walls.size():
		walls[i].position = centers[i]
		var collider: CollisionShape2D = walls[i].get_child(0)
		collider.shape = collider.shape.duplicate()
		collider.shape.size = Vector2(size.x,30) if i < 2 else Vector2(30,size.y)

func canopy(tree: Node2D) -> Rect2:
	var sprite: Sprite2D = tree.get_node("Sprite2D")
	return Rect2(tree.position+sprite.position,sprite.texture.get_size()*sprite.scale)

func near_path(rect: Rect2, only_new: bool = false) -> bool:
	var minimum := paths.local_to_map(rect.position)
	var maximum := paths.local_to_map(rect.end)
	for y in range(minimum.y,maximum.y+1):
		for x in range(minimum.x,maximum.x+1):
			var cell := Vector2i(x,y)
			if added_paths.has(cell) if only_new else paths.get_cell_source_id(cell) != -1: return true
	return false

func clear_old_tree_overlaps() -> void:
	for tree in get_nodes_in_group("world_trees"):
		if map.is_ancestor_of(tree) and tree.get_parent() != map.get_node("Characters") and not map.get_node("Characters").is_ancestor_of(tree) and near_path(canopy(tree).grow(20),true):
			tree.free()

func plant_clusters() -> void:
	var trees: Node2D = map.get_node_or_null("Trees")
	if trees == null:
		trees = Node2D.new()
		trees.name = "Trees"
		trees.y_sort_enabled = true
		owned(trees,map)
	var centers := [Vector2(0.58,0.13),Vector2(0.76,0.30),Vector2(0.59,0.48),Vector2(0.84,0.59),Vector2(0.57,0.86),Vector2(0.33,0.66),Vector2(0.11,0.91),Vector2(0.82,0.94)]
	var count := 0
	for center in centers:
		for attempt in 90:
			if count >= (centers.find(center)+1)*7: break
			var tree: Node2D = TREE.instantiate()
			tree.name = "ExpansionTree%03d" % count
			tree.variation_seed = random.randi_range(100000,999999)
			tree.position = center*map.map_size + Vector2(random.randf_range(-180,180),random.randf_range(-110,110))
			owned(tree,trees)
			var rect := canopy(tree).grow(24)
			var invalid := near_path(rect) or not Rect2(Vector2(48,48),map.map_size-Vector2(96,96)).encloses(rect)
			for clearing in clearings: invalid = invalid or rect.intersects(Rect2(clearing-Vector2(140,140),Vector2(280,280)))
			for group in ["Entries","Portals","Characters"]:
				for node in map.get_node(group).get_children(): invalid = invalid or rect.grow(64).has_point(node.position)
			for existing in trees.get_children():
				if existing != tree: invalid = invalid or tree.position.distance_to(existing.position) < 65
			for body in map.get_children():
				if body is TileMapLayer and body.collision_enabled:
					for y in range(-2,3):
						for x in range(-2,3): invalid = invalid or body.get_cell_source_id(body.local_to_map(tree.position)+Vector2i(x,y)) != -1
			if invalid: tree.free()
			else: count += 1

func flowers() -> void:
	var details := layer("MeadowDetails",GRASS,-4,false)
	for clearing in clearings:
		var cell := details.local_to_map(clearing+Vector2(-88,-64))
		for i in 2:
			var offset := cell+Vector2i(i,0)
			if paths.get_cell_source_id(offset) == -1:
				details.set_cell(offset,0,Vector2i(4+i,2))

func shortcut(label: String, destination: String, destination_entry: String, flag: String, normalized: Vector2, caption: String) -> void:
	var position: Vector2 = normalized*map.map_size
	var clearing: Vector2 = clearings[0 if normalized.y < 0.3 else (4 if normalized.x < 0.3 else (2 if normalized.x > 0.8 else 3))]
	trail(clearing,position)
	var portal := Area2D.new()
	portal.name = label
	portal.position = position
	portal.set_script(load("res://scripts/world/shortcut.gd"))
	portal.destination = destination
	portal.entry = destination_entry
	portal.required_story_flag = flag
	portal.route_label = caption
	portal.collision_layer = 0
	portal.collision_mask = 2
	# Children must exist before _ready runs.
	var collider := CollisionShape2D.new()
	collider.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(96,96)
	collider.shape = shape
	portal.add_child(collider)
	var text := Label.new()
	text.name = "Label"
	text.position = Vector2(-90,-48)
	text.size = Vector2(180,96)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_override("font",preload("res://assets/ui/fonts/DejaVuSansMono.ttf"))
	text.add_theme_font_size_override("font_size",16)
	text.add_theme_color_override("font_outline_color",Color.BLACK)
	text.add_theme_constant_override("outline_size",4)
	portal.add_child(text)
	owned(portal,map.get_node("Portals"))
	collider.owner = map
	text.owner = map
	var marker := Marker2D.new()
	marker.name = "From"+ ("Bart" if label in ["ToBart"] else ("Entrance" if label == "ToEntrance" else "Flooded")) + "Shortcut"
	marker.position = position+(clearing-position).normalized()*160
	owned(marker,map.get_node("Entries"))
