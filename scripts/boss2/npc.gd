extends "res://scripts/world/npc.gd"
func _ready() -> void:
	super._ready()
	set_meta("boss2", true)
func can_interact() -> bool:
	return true
func handle_interaction(world: Node) -> bool:
	world.pending_encounter = "boss2"
	world.pending_battle = false
	world.conversation_flag = ""
	world.dialogue.start("boss2_defeated" if Session.story_flags.get("boss2_defeated", false) else "boss2_encounter", typing_sound)
	world.player.movement_locked = true
	world.hide_interaction()
	return true
