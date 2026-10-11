extends "res://scripts/world/npc.gd"

# All proximity, indicators and interaction routing use the shared NPC contract.
@export var object_name: String = "TREE"
@export_multiline var descriptions: Array[String] = ["It's a tree.", "Probably."]

func custom_lines() -> Array:
	var result: Array = []
	for description in descriptions:
		result.append({"speaker": object_name, "text": description})
	return result

func can_interact() -> bool:
	return super.can_interact() and not descriptions.is_empty()
