extends "res://scripts/world/area.gd"
@export var region_id := "wonderland_forest"
func is_walkable_position(point: Vector2) -> bool:
	var floor := get_node("Ground") as TileMapLayer
	return floor.get_cell_source_id(floor.local_to_map(point/floor.scale)) >= 0
