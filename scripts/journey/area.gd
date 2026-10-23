extends "res://scripts/world/area.gd"
## Ordinary baked TileMapLayers/bodies remain editable. Only atmosphere animates.
@export var region_id := "entrance"
func _ready() -> void:
	var ambience := preload("res://scripts/journey/forest_atmosphere.gd").new()
	ambience.name = "ForestAtmosphere"
	add_child(ambience)
func _process(_delta: float) -> void:
	var world := get_parent()
	if world.get("player")!=null:
		$Understory.material.set_shader_parameter("player_world",world.player.global_position)
func is_walkable_position(point: Vector2) -> bool:
	return Rect2(Vector2(48,48),map_size-Vector2(96,96)).has_point(point) and not _in_water(point)
func _in_water(point: Vector2) -> bool:
	var bridge := get_node_or_null("Bridges") as TileMapLayer
	if bridge != null and bridge.get_cell_source_id(bridge.local_to_map(bridge.to_local(to_global(point))))>=0:return false
	var water := get_node_or_null("Water") as TileMapLayer
	return water != null and water.get_cell_source_id(water.local_to_map(water.to_local(to_global(point)))) >= 0
