extends Node2D

@export var dialogue_id: String = "forest_npc"
@export var interaction_radius: float = 100.0
@export var starts_battle: bool = false

func dialogue_key() -> String:
	if starts_battle and Session.evil_bart_defeated:
		return "bart_defeated"
	return dialogue_id
