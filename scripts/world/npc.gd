extends Node2D

@export var dialogue_id: String = "forest_npc"
@export var interaction_radius: float = 100.0
@export var starts_battle: bool = false

func dialogue_key() -> String:
	if starts_battle and Session.evil_bart_defeated:
		return "bart_defeated"
	return dialogue_id

@export var typing_sound: AudioStream
@export var required_flag: String = ""
@export var completion_flag: String = ""

func _ready() -> void:
	add_to_group("interactables")

func can_interact() -> bool:
	return required_flag.is_empty() or Session.story_flags.get(required_flag, false)

func custom_lines() -> Array:
	return []
