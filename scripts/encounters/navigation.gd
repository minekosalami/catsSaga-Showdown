extends RefCounted
var grid =AStarGrid2D.new()
var ready =false
const CELL:=32
func build(map: Node2D) -> void:
	grid.region=Rect2i(Vector2i.ZERO,Vector2i(map.map_size/CELL))
	grid.cell_size=Vector2(CELL,CELL)
	grid.offset=Vector2(16,16)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	var query =PhysicsShapeQueryParameters2D.new()
	var shape =RectangleShape2D.new();shape.size=Vector2(28,28)
	query.shape=shape;query.collision_mask=1
	var count =0
	for y in grid.region.size.y:
		for x in grid.region.size.x:
			var cell =Vector2i(x,y)
			var point =Vector2(cell*CELL)+Vector2(16,16)
			query.transform=Transform2D(0,point)
			var blocked =not map.is_walkable_position(point) or not map.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()
			grid.set_point_solid(cell,blocked)
			count+=1
			if count%384==0:
				await map.get_tree().process_frame
				if not is_instance_valid(map) or not map.is_inside_tree():return
	ready=true
func cell(point: Vector2) -> Vector2i:return Vector2i((point/float(CELL)).floor())
func valid(point: Vector2) -> bool:
	var id =cell(point)
	return ready and grid.is_in_boundsv(id) and not grid.is_point_solid(id)
func nearest(point: Vector2) -> Vector2i:
	var origin =cell(point)
	for r in range(0,7):
		for y in range(-r,r+1):
			for x in range(-r,r+1):
				var id =origin+Vector2i(x,y)
				if grid.is_in_boundsv(id) and not grid.is_point_solid(id):return id
	return Vector2i(-1,-1)
func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if not ready:return PackedVector2Array()
	var a =nearest(from);var b =nearest(to)
	if a.x<0 or b.x<0:return PackedVector2Array()
	return grid.get_point_path(a,b)
