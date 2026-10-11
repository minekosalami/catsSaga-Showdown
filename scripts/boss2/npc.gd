extends "res://scripts/world/npc.gd"
@export_multiline var introduction := "[Introductory dialogue placeholder — replace in the Inspector.]"
func _ready() -> void:
	super._ready()
	set_meta("boss2", true)
func can_interact() -> bool:
	return not Session.story_flags.get("boss2_defeated", false)
func custom_lines() -> Array:
	return [{"speaker": "", "text": introduction}]
func handle_interaction(world: Node) -> bool:
	# Presentation placeholder uses the existing dialogue transition without story text.
	world.pending_encounter = "boss2"
	world.conversation_flag = ""
	world.dialogue.start_graph({"start":"intro", "nodes":{"intro":{"speaker":"", "lines":[introduction], "end":"battle"}}})
	world.player.movement_locked = true
	world.hide_interaction()
	return true
