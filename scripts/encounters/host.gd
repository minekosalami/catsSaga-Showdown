extends "res://scripts/systems/combat_host.gd"
func _init() -> void:
	battle_scene=preload("res://scenes/encounters/battle.tscn")
func record_victory() -> void:
	pass # Ordinary settlement lives in the guarded visit service, never boss flags.
func return_to_forest() -> void:
	if battle.settled:Session.forest_encounters.resolve("flee")
func retry() -> void:
	Session.forest_encounters.resolve("defeat")
