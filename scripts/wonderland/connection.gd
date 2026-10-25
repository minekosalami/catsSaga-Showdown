extends "res://scripts/world/portal.gd"
@export var gate_flag := ""
func can_travel() -> bool:
	# The old forest seam is retired; the ambush portal is destroyed.
	if destination == "flooded_forest": return false
	return Session.region_access_allowed(gate_flag.is_empty() or Session.story_flags.get(gate_flag,false))
