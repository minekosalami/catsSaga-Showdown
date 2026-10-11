extends SceneTree

## Focused, one-time authoring pass on the GFX scenes, not a runtime generator.
const Layout = preload("res://scripts/maps/world_layout.gd")
# Each edge keeps its destination/entry names and progression conditions.
const ROUTES := {
	"entrance": [
		["Exit0","FromDeep",Vector2(3136,992),Vector2(2992,992),Vector2.LEFT,Vector2(1480,450),Vector2(3200,992)],
		["ToBart","FromBartShortcut",Vector2(1344,1760),Vector2(1344,1616),Vector2.UP,Vector2(1344,1714.56),Vector2(1344,1824)]],
	"deep_forest": [
		["Exit0","FromEntrance",Vector2(64,992),Vector2(208,992),Vector2.RIGHT,Vector2(280,540),Vector2(0,992)],
		["Exit1","FromBart",Vector2(64,2816),Vector2(208,2816),Vector2.RIGHT,Vector2(2280,1200),Vector2(0,2816)],
		["ToFlooded","FromFlooded",Vector2(1792,2816),Vector2(1792,2672),Vector2.UP,Vector2(1750,1090),Vector2(1792,2880)]],
	"bart_area": [
		["Exit0","FromDeep",Vector2(3136,992),Vector2(2992,992),Vector2.LEFT,Vector2(280,450),Vector2(3200,992)],
		["ToEntrance","FromEntranceShortcut",Vector2(1344,64),Vector2(1344,208),Vector2.DOWN,Vector2(2048,378.88),Vector2(1344,0)],
		["ToFlooded","FromFloodedShortcut",Vector2(3136,1728),Vector2(2992,1728),Vector2.LEFT,Vector2(2816,1276.8),Vector2(3200,1728)]],
	"flooded_forest": [
		["ToDeep","FromDeep",Vector2(1792,64),Vector2(1792,208),Vector2.DOWN,Vector2(260,768),Vector2(1792,0)],
		["ToBart","FromBartShortcut",Vector2(64,672),Vector2(208,672),Vector2.RIGHT,Vector2(487.68,2334.72),Vector2(0,672)]]
}
var map: Node2D
var paths: TileMapLayer
var random := RandomNumberGenerator.new()
var navigation: AStarGrid2D
var water_cells := {}
var newly_painted := {}
var original_paths := {}

func _initialize() -> void:
	call_deferred("run")

func collision_rect(tile: TileData) -> Rect2:
	var polygon := tile.get_collision_polygon_points(0,0)
	var rect := Rect2(polygon[0],Vector2.ZERO)
	for point in polygon: rect = rect.expand(point)
	return rect

func rock_tiles() -> TileSet:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(32,32)
	tiles.add_physics_layer()
	tiles.set_physics_layer_collision_layer(0,1)
	tiles.set_physics_layer_collision_mask(0,2)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load("res://assets/enironment/gfx/objects.png")
	atlas.texture_region_size = Vector2i(16,16)
	tiles.add_source(atlas,0)
	for coordinate in [Vector2i(6,4),Vector2i(8,4)]:
		atlas.create_tile(coordinate,Vector2i(2,2))
		atlas.create_alternative_tile(coordinate,1)
		for alternative in [0,1]:
			var data := atlas.get_tile_data(coordinate,alternative)
			data.flip_h = alternative == 1
			data.y_sort_origin = 5 if coordinate.x == 6 else 12
			data.set_collision_polygons_count(0,1)
			data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-5,-1),Vector2(3,-1),Vector2(3,4),Vector2(-2,5),Vector2(-6,1)]) if coordinate.x == 6 else PackedVector2Array([Vector2(-9,-1),Vector2(8,-1),Vector2(10,5),Vector2(2,12),Vector2(-8,7)]))
	return tiles

func grid_cell(point: Vector2) -> Vector2i:
	return Vector2i((point/16.0).floor()).clamp(Vector2i.ZERO,navigation.region.size-Vector2i.ONE)

func mark_obstacle(rect: Rect2, solid: bool) -> void:
	var first := grid_cell(rect.position)
	var last := grid_cell(rect.end)
	for y in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			var cell := Vector2i(x,y)
			if solid: navigation.set_point_solid(cell)
			else: navigation.set_point_weight_scale(cell,8.0)

func prepare_navigation() -> void:
	original_paths.clear()
	for cell in paths.get_used_cells(): original_paths[cell] = true
	navigation = AStarGrid2D.new()
	navigation.region = Rect2i(Vector2i.ZERO,Vector2i(map.map_size/16))
	navigation.cell_size = Vector2(16,16)
	navigation.offset = Vector2(8,8)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	navigation.update()
	water_cells.clear()
	for node in map.get_children():
		if node is TileMapLayer and node.name.contains("Water"):
			for cell in node.get_used_cells():
				water_cells[cell] = true
				mark_obstacle(Rect2(Vector2(cell*16)-Vector2(48,48),Vector2(112,112)),true)
	for y in navigation.region.size.y:
		for x in navigation.region.size.x:
			var cell := Vector2i(x,y)
			navigation.set_point_weight_scale(cell,0.5 if paths.get_cell_source_id(cell) != -1 else 1.3+0.12*sin(x*0.11+y*0.19))
	for collider in map.find_children("*","CollisionShape2D",true,false):
		if not collider.get_parent() is StaticBody2D or collider.disabled: continue
		if map.get_node("Obstacles").is_ancestor_of(collider): continue
		var rect: Rect2 = collider.global_transform*collider.shape.get_rect()
		# Keep character/landmark bodies; let a new route skirt ordinary trees.
		mark_obstacle(rect.grow(56),map.get_node("Characters").is_ancestor_of(collider))
	for label in ["GFXTreesSmall","GFXTreesMedium","GFXTreesLarge"]:
		var trees: TileMapLayer = map.get_node(label)
		for cell in trees.get_used_cells():
			mark_obstacle(Rect2(trees.to_global(trees.map_to_local(cell)),Vector2.ZERO).grow(60),false)

func paint(point: Vector2, radius: float = 48.0) -> void:
	var center := grid_cell(point)
	for y in range(maxi(center.y-4,0),mini(center.y+4,navigation.region.size.y-1)+1):
		for x in range(maxi(center.x-4,0),mini(center.x+4,navigation.region.size.x-1)+1):
			var cell := Vector2i(x,y)
			if Vector2(cell*16+Vector2i(8,8)).distance_to(point) > radius or water_cells.has(cell): continue
			paths.set_cell(cell,0,Vector2i(1,30) if (x+y)%9 else Vector2i(2,32))
			newly_painted[cell] = true
			navigation.set_point_weight_scale(cell,0.5)

func connect_path(from: Vector2, to: Vector2) -> bool:
	var route := navigation.get_point_path(grid_cell(from),grid_cell(to))
	if route.is_empty():
		push_error("No dry route in "+map.name+" from "+str(from)+" to "+str(to)+"; blocked endpoints="+str(navigation.is_point_solid(grid_cell(from)))+" / "+str(navigation.is_point_solid(grid_cell(to))))
		return false
	for i in route.size():
		var point := route[i]
		# Preserve existing routes; gently bend only newly added dry connectors.
		if not original_paths.has(grid_cell(point)) and route.size() > 16:
			var tangent := (route[mini(i+6,route.size()-1)]-route[maxi(i-6,0)]).normalized()
			var envelope := sin(PI*i/float(route.size()-1))
			var bend := sin(i*16.0/190.0)*64.0*envelope
			var candidate := (point+tangent.orthogonal()*bend).clamp(Vector2(8,8),map.map_size-Vector2(8,8))
			if not navigation.is_point_solid(grid_cell(candidate)): point = candidate
		paint(point)
	return true

func touches_path(rect: Rect2) -> bool:
	var first := grid_cell(rect.position)
	var last := grid_cell(rect.end)
	for y in range(first.y,last.y+1):
		for x in range(first.x,last.x+1):
			if paths.get_cell_source_id(Vector2i(x,y)) != -1: return true
	return false

func clear_new_routes() -> void:
	# Clear trunks and opaque canopies across repaired roads; retain other trees.
	for tree in get_nodes_in_group("world_trees"):
		if not map.is_ancestor_of(tree): continue
		var collider: CollisionShape2D = tree.get_node("CollisionShape2D")
		var sprite: Sprite2D = tree.get_node("Sprite2D")
		var canopy := Rect2(tree.global_position+sprite.position,sprite.texture.get_size()*sprite.scale)
		if touches_path((collider.global_transform*collider.shape.get_rect()).grow(16)) or touches_path(canopy.grow(6)):
			tree.free()
	for label in ["GFXTreesSmall","GFXTreesMedium","GFXTreesLarge"]:
		var trees: TileMapLayer = map.get_node(label)
		for cell in trees.get_used_cells():
			var native := collision_rect(trees.get_cell_tile_data(cell))
			native.position += trees.map_to_local(cell)
			var rect: Rect2 = trees.global_transform*native
			if touches_path(rect.grow(16)): trees.erase_cell(cell)
	for cell in newly_painted:
		map.get_node("GFXForestFloor").erase_cell(cell)
		for label in ["GrassDetails","MeadowDetails"]:
			var detail := map.get_node_or_null(label) as TileMapLayer
			if detail != null: detail.erase_cell(cell)
	var plants: TileMapLayer = map.get_node("GFXUndergrowth")
	for cell in plants.get_used_cells():
		if touches_path(Rect2(plants.to_global(plants.map_to_local(cell)),Vector2.ZERO).grow(10)): plants.erase_cell(cell)

func safe_rock(center: Vector2, occupied: Array[Vector2]) -> bool:
	var rect := Rect2(center-Vector2(32,32),Vector2(64,64))
	if not Rect2(Vector2(64,64),map.map_size-Vector2(128,128)).encloses(rect) or touches_path(rect.grow(16)): return false
	for group in ["Entries","Portals","Characters","Discoveries"]:
		for node in map.get_node(group).get_children():
			if node.position.distance_to(center) < 160: return false
	for cell in water_cells:
		if rect.grow(16).has_point(Vector2(cell*16+Vector2i(8,8))): return false
	for previous in occupied:
		if previous.distance_to(center) < 48: return false
	for collider in map.find_children("*","CollisionShape2D",true,false):
		if collider.get_parent() is StaticBody2D and rect.intersects(collider.global_transform*collider.shape.get_rect()): return false
	for label in ["GFXTreesSmall","GFXTreesMedium","GFXTreesLarge"]:
		var trees: TileMapLayer = map.get_node(label)
		for cell in trees.get_used_cells():
			if trees.to_global(trees.map_to_local(cell)).distance_to(center) < 64: return false
	return true

func arrange_rocks(tiles: TileSet, old_centers: Array[Vector2]) -> void:
	var rocks: TileMapLayer = map.get_node("GFXBoulders")
	rocks.clear()
	rocks.tile_set = tiles
	var occupied: Array[Vector2] = []
	# Reuse old neighborhoods, then find additional safe positions if rerouting
	# consumed one. Offsets and feature alternatives avoid repeated straight rows.
	var attempts := old_centers.duplicate()
	for i in 180: attempts.append(Vector2(random.randf_range(96,map.map_size.x-96),random.randf_range(96,map.map_size.y-96)))
	var clusters := 0
	for anchor in attempts:
		if clusters >= maxi(old_centers.size(),5): break
		var accepted := 0
		var angle := random.randf()*TAU
		for i in 3:
			var proposed: Vector2 = anchor+Vector2.from_angle(angle+i*2.1)*random.randf_range(12,80)
			var cell := rocks.local_to_map(proposed/rocks.scale)
			var center := rocks.to_global(rocks.map_to_local(cell))
			if not safe_rock(center,occupied): continue
			rocks.set_cell(cell,0,Vector2i(8,4) if i == 0 else Vector2i(6,4),random.randi_range(0,1))
			occupied.append(center)
			accepted += 1
		if accepted: clusters += 1
	print(map.name," stone features=",rocks.get_used_cells().size()," / clusters=",clusters)

func configure_portal(route: Array) -> void:
	var portal := map.get_node_or_null("Portals/"+route[0]) as Area2D
	if portal == null:
		portal = Area2D.new()
		portal.name = route[0]
		portal.set_script(load("res://scripts/world/portal.gd"))
		portal.destination = "flooded_forest"
		portal.entry = "FromDeep"
		portal.required_flag = "flooded_forest_key_obtained"
		portal.collision_layer = 0
		portal.collision_mask = 2
		map.get_node("Portals").add_child(portal)
		portal.owner = map
		var collider := CollisionShape2D.new()
		collider.name = "CollisionShape2D"
		portal.add_child(collider)
		collider.owner = map
		var label := Label.new()
		label.name = "DestinationLabel"
		label.text = "FLOODED FOREST\n[KEY REQUIRED]"
		label.position = Vector2(-96,-110)
		label.add_theme_color_override("font_outline_color",Color.BLACK)
		label.add_theme_constant_override("outline_size",4)
		portal.add_child(label)
		label.owner = map
	portal.position = route[2]
	for collider in portal.get_children():
		if collider is CollisionShape2D:
			collider.shape = RectangleShape2D.new()
			collider.shape.size = Vector2(96,112) if route[4].x != 0 else Vector2(112,96)
	var marker: Marker2D = map.get_node("Entries/"+route[1])
	marker.position = route[3]
	marker.set_meta("facing_direction",route[4])

func run() -> void:
	# Prevent applying this authoring pass twice over manual edits.
	for area in Layout.REGIONS:
		var original: Node = load("res://scenes/world/"+Layout.REGIONS[area].scene+".tscn").instantiate()
		var already_repaired := original.has_meta("connections_repaired")
		original.free()
		if already_repaired:
			push_error("Connections already repaired; edit the scenes directly.")
			quit(1)
			return
	var tiles := rock_tiles()
	var resource_path := "res://resources/world/gfx_boulders.tres"
	if ResourceSaver.save(tiles,resource_path) != OK:
		quit(1)
		return
	tiles.take_over_path(resource_path)
	for area in Layout.REGIONS:
		var filename: String = Layout.REGIONS[area].scene
		map = load("res://scenes/world/"+filename+".tscn").instantiate()
		root.add_child(map)
		paths = map.get_node("WindingTrails" if area == "flooded_forest" else "Paths")
		newly_painted.clear()
		random.seed = 63200+Layout.REGIONS.keys().find(area)
		var old_centers: Array[Vector2] = []
		var rocks: TileMapLayer = map.get_node("GFXBoulders")
		for cell in rocks.get_used_cells(): old_centers.append(rocks.to_global(rocks.map_to_local(cell)))
		prepare_navigation()
		# Retire the two obsolete west-border tails into existing interior clearings.
		if area in ["bart_area","flooded_forest"]:
			var former_y := 450.0 if area == "bart_area" else 768.0
			for cell in paths.get_used_cells():
				if cell.x < 12 and absf(cell.y*16-former_y) < 100: paths.erase_cell(cell)
		for route in ROUTES[area]:
			configure_portal(route)
			if not connect_path(route[5],route[3]) or not connect_path(route[3],route[6]):
				map.free()
				quit(1)
				return
			paint(route[2])
			paint(route[3])
		clear_new_routes()
		arrange_rocks(tiles,old_centers)
		map.set_meta("connections_repaired",true)
		var packed := PackedScene.new()
		var error := packed.pack(map)
		if error == OK: error = ResourceSaver.save(packed,"res://scenes/world/"+filename+".tscn")
		map.free()
		if error != OK:
			quit(1)
			return
	quit()
