extends "res://scripts/world/area.gd"
const Blueprint = preload("res://scripts/world/cave_layout.gd")
func is_walkable_position(point: Vector2) -> bool:
	var floor: TileMapLayer = $CaveFloor
	var cell := floor.local_to_map(point/floor.scale)
	return floor.get_cell_source_id(cell) >= 0 and $CaveWater.get_cell_source_id(cell) < 0
