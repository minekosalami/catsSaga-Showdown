extends Node2D
## A localized addition: preserve the forest scene, remove only trunks on this spur.
const Plan = preload("res://scripts/wonderland/layout.gd")
const ROUTE := [Vector2(1792,560),Vector2(2050,420),Vector2(2470,350),Vector2(2790,350),Vector2(3072,270),Plan.FLOODED_DOOR,Vector2(3072,32)]
func distance_to_route(point: Vector2) -> float:
	var distance := INF
	for i in range(1,ROUTE.size()): distance = minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,ROUTE[i-1],ROUTE[i])))
	return distance
func _ready() -> void:
	var forest := get_parent()
	y_sort_enabled = true
	for layer in forest.get_children():
		if not layer is TileMapLayer: continue
		if layer.name.begins_with("GFXTrees") or layer.name == "GFXBoulders":
			for cell in layer.get_used_cells():
				var point: Vector2 = layer.map_to_local(cell)*layer.scale
				if distance_to_route(point) < 110: layer.erase_cell(cell)
	for tree in get_tree().get_nodes_in_group("world_trees"):
		if forest.is_ancestor_of(tree) and distance_to_route(tree.position) < 110:
			tree.queue_free()
	var path := TileMapLayer.new()
	path.name = "WonderlandSpur"
	path.tile_set = load("res://resources/wonderland/road.tres")
	path.z_index = -3
	add_child(path)
	for y in range(1,40):
		for x in range(105,200):
			if distance_to_route(Vector2(x*16+8,y*16+8)) < 42:
				path.set_cell(Vector2i(x,y),0,Vector2i(12,8))
	var builder := preload("res://scripts/wonderland/builder.gd").new()
	# Pink plants announce the destination; the arch joins the actual northern border.
	for offset in [Vector2(-135,30),Vector2(135,30),Vector2(-85,180),Vector2(90,180)]:
		var flowers := preload("res://scripts/wonderland/ornament.gd").new()
		flowers.kind = "flowers"
		flowers.accent = Color("#f69ac9")
		flowers.scale = Vector2.ONE*2
		flowers.position = Plan.FLOODED_DOOR+offset
		add_child(flowers)
	for side in [-1,1]:
		var root := Node2D.new()
		root.position = Plan.FLOODED_DOOR+Vector2(side*145,0)
		add_child(root)
		var sprite := preload("res://scripts/wonderland/ornament.gd").new()
		sprite.kind = "grove"
		sprite.scale = Vector2.ONE*2
		root.add_child(sprite)
		builder.solid(root,Vector2(48,34),Vector2(0,-8))
		# A continuous thicket connects the doorway to the actual northern boundary.
		# The transition lies at the edge beyond the arch, never in the open clearing.
		builder.solid(self,Vector2(56,248),Vector2(Plan.FLOODED_DOOR.x+side*98,124))
		for y in [64,128]:
			var canopy := preload("res://scripts/wonderland/ornament.gd").new()
			canopy.kind = "grove"
			canopy.scale = Vector2.ONE*2
			canopy.position = Vector2(Plan.FLOODED_DOOR.x+side*145,y)
			add_child(canopy)
	var marker := Marker2D.new()
	marker.name = "FromWonderland"
	marker.position = Plan.FLOODED_DOOR+Vector2(0,144)
	marker.set_meta("facing_direction",Vector2.DOWN)
	forest.get_node("Entries").add_child(marker)
	var gate := preload("res://scripts/wonderland/gate.gd").new()
	gate.name = "PinkWonderlandDoor"
	gate.position = Plan.FLOODED_DOOR
	add_child(gate)
	var portal := preload("res://scripts/wonderland/connection.gd").new()
	portal.name = "ToWonderland"
	portal.position = Vector2(Plan.FLOODED_DOOR.x,48)
	portal.destination = "wonderland_forest"
	portal.entry = "FromFlooded"
	portal.gate_flag = Plan.DOOR_OPEN
	portal.collision_mask = 2
	portal.collision_layer = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(112,48)
	shape.shape = rect
	portal.add_child(shape)
	forest.get_node("Portals").add_child(portal)
