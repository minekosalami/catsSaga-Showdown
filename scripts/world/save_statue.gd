extends "res://scripts/world/npc.gd"
## Shared visual/interaction component; no autosave triggers or boss instances.
const LOCATIONS := {"entrance":[Vector2(640,1168)],"deep_forest":[Vector2(2600,1000)],"bart_area":[Vector2(1568,1040)],"flooded_forest":[Vector2(3008,1120)]}
var idle_time := 0.0
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
func _process(delta: float) -> void:
	idle_time = fposmod(idle_time+delta,2.0)
	$Star.position.y = -44.0+sin(idle_time*PI)*4.0
func handle_interaction(_world: Node) -> bool:
	Session.open_save_point(self)
	return true
