extends "res://scripts/world/area.gd"
@export var region_id := "wonderland_forest"
func is_walkable_position(point: Vector2) -> bool:
	var floor := get_node("Ground") as TileMapLayer
	var water := get_node_or_null("FairytaleWater") as TileMapLayer
	if water != null and water.get_cell_source_id(water.local_to_map(water.to_local(to_global(point)))) >= 0: return false
	return floor.get_cell_source_id(floor.local_to_map(point/floor.scale)) >= 0
