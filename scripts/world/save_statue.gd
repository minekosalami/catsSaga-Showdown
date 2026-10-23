extends "res://scripts/world/npc.gd"
## Shared visual/interaction component; no autosave triggers or boss instances.
const LOCATIONS := {"entrance":[Vector2(640,912)],"deep_forest":[Vector2(640,768),Vector2(1440,672)],"bart_area":[Vector2(1600,864)],"flooded_forest":[Vector2(3008,912)]}
static func install(map: Node2D) -> void:
	# Runtime load avoids a packed-scene ↔ script preload reference cycle.
	var scene := load("res://scenes/world/save_statue.tscn") as PackedScene
	for point in LOCATIONS.get(Session.area_id,[]):
		var statue := scene.instantiate()
		statue.position=point
		map.add_child(statue)
func _ready() -> void:
	super._ready()
	set_meta("save_statue",true)
	set_meta("interaction_label","Save")
func handle_interaction(_world: Node) -> bool:
	Session.open_save_point(self)
	return true
