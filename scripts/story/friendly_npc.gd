extends "res://scripts/world/npc.gd"
## Reuses the established dialogue renderer and its Z/arrow choice controls.
@export_enum("butterscotch", "cupid") var character := "butterscotch"
var current_world: Node

func handle_interaction(world: Node) -> bool:
	current_world = world
	world.pending_battle = false
	world.conversation_flag = ""
	world.pending_encounter = ""
	var progress = Session.story_progress
	var graph_name := "butterscotch"
	if character=="cupid":
		if progress.cupid_completed:
			world.dialogue.start_lines([{"speaker":"CUPID THE CAT","text":"Spread as much love as possible!"}], typing_sound)
		elif not progress.cupid_accepted:
			graph_name = "cupid_request"
		elif progress.wand_owned:
			graph_name = "cupid_return"
		else:
			world.dialogue.start_lines([{"speaker":"CUPID THE CAT","text":"Have you found it yet? Have you found it yet?"}], typing_sound)
	if not world.dialogue.active:
		world.dialogue.start_graph(JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/"+graph_name+".json")), typing_sound)
	world.dialogue.finished.connect(_completed, CONNECT_ONE_SHOT)
	world.player.movement_locked = true
	world.hide_interaction()
	return true

func _completed() -> void:
	match current_world.dialogue.outcome:
		"cupid_accept": Session.story_progress.accept_cupid()
		"cupid_reward_50": Session.story_progress.reward_cupid(false)
		"cupid_reward_75": Session.story_progress.reward_cupid(true)
