extends "res://scripts/world/npc.gd"

func can_interact() -> bool:
	return not Session.region_access_allowed(Session.story_flags.get("flooded_forest_key_obtained", false))

func _process(_delta: float) -> void:
	$Sign.text = "FLOODED FOREST\n[PATH OPEN]" if not can_interact() else "FLOODED FOREST\n[KEY REQUIRED]"

func handle_interaction(world: Node) -> bool:
	if can_interact():
		world.dialogue.start_lines([{"speaker": "", "text": "The entrance is locked. A special key is required."}])
		world.hide_interaction()
		world.player.movement_locked = true
	return true
