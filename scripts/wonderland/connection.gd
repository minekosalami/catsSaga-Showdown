extends "res://scripts/world/portal.gd"
@export var gate_flag := ""
func can_travel() -> bool:
	return Session.region_access_allowed(gate_flag.is_empty() or Session.story_flags.get(gate_flag,false))
