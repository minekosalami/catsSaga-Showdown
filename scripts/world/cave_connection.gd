extends "res://scripts/world/npc.gd"
@export_enum("underground_cave","flooded_forest") var destination := "underground_cave"
@export var entry := "FromFlooded"
func handle_interaction(world: Node) -> bool:
	if Session.busy or world.checking_spawn or world.dialogue.active or Session.world_menu_open(): return false
	world.update_map_exploration()
	world.hide_interaction()
	world.player.velocity = Vector2.ZERO
	world.player.movement_locked = true
	Session.travel(destination,entry,true)
	return true
