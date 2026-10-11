extends "res://scripts/systems/combat_host.gd"
func record_victory() -> void:
	if Session.encounter_active and Session.encounter_id == "boss2":
		Session.story_flags["boss2_defeated"] = true
		Session.save_boss_victory()
func return_to_forest() -> void:
	Session.return_to_flooded_forest()
func retry() -> void:
	Session.transition_to("res://scenes/boss2/combat_host.tscn")
