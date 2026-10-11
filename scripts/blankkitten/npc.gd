extends "res://scripts/world/npc.gd"

func can_interact() -> bool:
	return not Session.story_flags.get("blankkitten_defeated", false)

func handle_interaction(world: Node) -> bool:
	if not can_interact():
		return true
	world.pending_encounter = "blankkitten"
	world.pending_battle = false
	world.conversation_flag = ""
	world.dialogue.start_graph(JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/blankkitten.json")), typing_sound)
	world.player.movement_locked = true
	world.hide_interaction()
	return true
