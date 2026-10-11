extends "res://scripts/world/npc.gd"

func handle_interaction(world: Node) -> bool:
	if not Session.story_flags.get("flooded_forest_key_obtained", false):
		world.dialogue.start_lines([{"speaker": "", "text": "The entrance is locked. A special key is required."}])
		world.hide_interaction()
		world.player.movement_locked = true
	else:
		Session.story_flags["flooded_forest_unlocked"] = true
		world._travel("flooded_forest", "FromDeep")
	return true
